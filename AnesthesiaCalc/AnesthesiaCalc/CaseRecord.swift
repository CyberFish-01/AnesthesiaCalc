//
//  CaseRecord.swift
//  AnesthesiaCalc
//

import Foundation
import Combine
import SwiftUI

// ══════════════════════════════════════════════════════════════════════
// MARK: — CaseRecord
// ══════════════════════════════════════════════════════════════════════

/// One saved AI-decision case containing extracted patient info and the
/// generated anaesthesia plan.
struct CaseRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()

    /// Patient name extracted by the AI (falls back to "佚名" when absent)
    var patientName: String
    /// Hospital record / admission number, e.g. "12345678"
    var hospitalNumber: String
    /// Age string, e.g. "45岁"
    var age: String
    /// Surgery name
    var surgery: String
    /// Clinically relevant pre-existing conditions / risk flags
    var conditions: [String]
    /// AI-generated concise anaesthesia plan
    var anesthesiaPlan: String
    /// Total body weight in kg — nil for legacy records created before this field was added
    var weightKg: Double?
    /// Standing height in cm — nil for legacy records created before this field was added
    var heightCm: Double?
    /// Original free-text description entered by the clinician (病历描述).
    /// Empty for legacy records or records created solely from structured form.
    var rawInputText: String = ""
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — UpsertResult
// ══════════════════════════════════════════════════════════════════════

/// Indicates whether an `upsert` call created a brand-new record or merged
/// data into an existing one.
enum UpsertResult {
    case created
    case updated

    var message: String {
        switch self {
        case .created: return "已创建新患者档案"
        case .updated: return "已更新该患者信息"
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — HistoryManager
// ══════════════════════════════════════════════════════════════════════

/// Persists and vends the ordered list of saved case records.
///
/// Records are stored in `UserDefaults` as JSON.
/// Observe `records` in SwiftUI views via `@StateObject` / `@ObservedObject`.
final class HistoryManager: ObservableObject {

    static let shared = HistoryManager()

    private let storageKey = "case_history_records"

    /// Newest-first ordered list of saved records.
    @Published private(set) var records: [CaseRecord] = []

    private init() { load() }

    // ── Public API ─────────────────────────────────────────────────────

    /// **Upsert** a record using `hospitalNumber` as the unique key.
    ///
    /// - If `record.hospitalNumber` is non-empty **and** a record with the
    ///   same number already exists, the stored record is updated in-place:
    ///   non-empty fields from `record` overwrite the stored values, the
    ///   `date` is bumped to now, and the record is moved to the front.
    /// - If no match is found (or the hospital number is blank), `record` is
    ///   inserted at the front as a fresh entry.
    ///
    /// - Returns: `.updated` if an existing record was merged,
    ///            `.created` if a new record was inserted.
    @discardableResult
    func upsert(_ record: CaseRecord) -> UpsertResult {
        let trimmed = record.hospitalNumber.trimmingCharacters(in: .whitespaces)

        if !trimmed.isEmpty,
           let idx = records.firstIndex(where: {
               !$0.hospitalNumber.trimmingCharacters(in: .whitespaces).isEmpty
                   && $0.hospitalNumber == trimmed
           }) {
            var merged = records[idx]

            // Overwrite stored fields only when the incoming value is non-empty/non-nil.
            // This prevents a "lightweight" archive (no plan, no surgery) from wiping
            // data that was previously set by a full AI generation.
            if !record.patientName.isEmpty, record.patientName != "佚名" {
                merged.patientName = record.patientName
            }
            if !record.age.isEmpty            { merged.age            = record.age }
            if !record.surgery.isEmpty        { merged.surgery        = record.surgery }
            if !record.conditions.isEmpty     { merged.conditions     = record.conditions }
            if !record.anesthesiaPlan.isEmpty { merged.anesthesiaPlan = record.anesthesiaPlan }
            if let w = record.weightKg        { merged.weightKg       = w }
            if let h = record.heightCm        { merged.heightCm       = h }
            if !record.rawInputText.isEmpty   { merged.rawInputText   = record.rawInputText }
            merged.date = Date()

            records.remove(at: idx)
            records.insert(merged, at: 0)
            persist()
            return .updated
        } else {
            records.insert(record, at: 0)
            persist()
            return .created
        }
    }

    /// Unconditional insert — use `upsert` in most cases.
    /// Kept for legacy call-sites that intentionally bypass deduplication.
    func save(_ record: CaseRecord) {
        records.insert(record, at: 0)
        persist()
    }

    /// Remove records at the given offsets and persist.
    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        persist()
    }

    // ── Persistence ────────────────────────────────────────────────────

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([CaseRecord].self, from: data)
        else { return }
        records = decoded
    }
}
