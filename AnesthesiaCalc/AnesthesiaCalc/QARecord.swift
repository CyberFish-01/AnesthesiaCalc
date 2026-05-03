//
//  QARecord.swift
//  AnesthesiaCalc
//

import Foundation
import Combine
import SwiftUI

// ══════════════════════════════════════════════════════════════════════
// MARK: — QARecord
// ══════════════════════════════════════════════════════════════════════

/// A single AI medical Q&A exchange saved to local history.
struct QARecord: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    /// The user's question
    var question: String
    /// The AI's full answer
    var answer: String
    /// A short category tag summarised by the AI, e.g. "药理机制" / "突发应急"
    var category: String?
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — QAHistoryManager
// ══════════════════════════════════════════════════════════════════════

/// Persists and vends the ordered list of saved Q&A records.
///
/// Records are stored in `UserDefaults` as JSON, newest-first.
/// Observe `records` in SwiftUI views via `@StateObject` / `@ObservedObject`.
final class QAHistoryManager: ObservableObject {

    static let shared = QAHistoryManager()

    private let storageKey = "qa_history_records"

    @Published private(set) var records: [QARecord] = []

    private init() { load() }

    // ── Public API ─────────────────────────────────────────────────────

    func save(_ record: QARecord) {
        records.insert(record, at: 0)
        persist()
    }

    func delete(atOffsets offsets: IndexSet) {
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
            let decoded = try? JSONDecoder().decode([QARecord].self, from: data)
        else { return }
        records = decoded
    }
}
