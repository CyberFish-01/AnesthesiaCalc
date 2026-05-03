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

    /// Insert a new record at the front (newest-first) and persist.
    func save(_ record: CaseRecord) {
        records.insert(record, at: 0)
        persist()
    }

    /// Remove records at the given offsets and persist.
    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        persist()
    }

    /// Update an existing record's anthropometrics and optionally its name.
    /// Bumps `date` to now so the record floats to the top on next sort.
    func update(at index: Int, weight: Double, height: Double, age: String, name: String?) {
        guard records.indices.contains(index) else { return }
        records[index].weightKg = weight
        records[index].heightCm = height
        records[index].age      = age
        if let name { records[index].patientName = name }
        records[index].date = Date()
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
