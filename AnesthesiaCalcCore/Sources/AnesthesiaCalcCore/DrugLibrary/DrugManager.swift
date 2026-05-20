import Combine
import Foundation

/// Manages the ordered list of drugs shown in the dose calculator.
///
/// Observe this singleton in SwiftUI views with `@StateObject` or inject it
/// via the environment. Views reactively update whenever `activeDrugs` changes.
///
/// ## Persistence
/// The full drug list (including `isActive` state) is persisted to `UserDefaults`
/// as JSON. On first launch, the list is initialised from `DrugCatalog`.
/// Subsequent launches restore the saved state, preserving user toggles and
/// customisations.
public final class DrugManager: ObservableObject {

    /// Shared singleton — use this in production code and SwiftUI previews.
    public static let shared = DrugManager()

    /// The ordered list of **all** drugs (active + hidden).
    /// Settings screens should bind to this array directly.
    @Published public var allDrugs: [AnesthesiaDrug]

    /// Convenience computed property — only drugs with `isActive == true`.
    /// The main calculator screen should use this.
    public var activeDrugs: [AnesthesiaDrug] {
        allDrugs.filter { $0.isActive }
    }

    private static let storageKey = "com.anesthesiacalc.drugManager_v1"
    private var cancellables = Set<AnyCancellable>()

    private init() {
        var loaded = Self.loadFromDisk() ?? Self.buildDefaultCatalog()
        // Merge any drugs newly added to the catalog since the last save.
        Self.mergeMissingCatalogDrugs(into: &loaded)
        allDrugs = loaded

        // Auto-save whenever the list changes.
        $allDrugs
            .dropFirst()
            .sink { drugs in
                Self.saveToDisk(drugs)
            }
            .store(in: &cancellables)
    }

    /// Append catalog drugs that are not yet present in the persisted list.
    private static func mergeMissingCatalogDrugs(into drugs: inout [AnesthesiaDrug]) {
        let existingNames = Set(drugs.map(\.name))
        let catalogDrugs = buildDefaultCatalog()
        for drug in catalogDrugs {
            guard !existingNames.contains(drug.name) else { continue }
            drugs.append(drug)
        }
    }

    // MARK: - Catalog bootstrap

    private static func buildDefaultCatalog() -> [AnesthesiaDrug] {
        let allDefaultRules = AIRuleEngine.shared.allRules

        return DrugCatalog.all.map { entry in
            // Preserve fixed UUIDs for the four original built-in drugs
            // to maintain backward compatibility with persisted data.
            let id: UUID
            switch entry.name {
            case "丙泊酚":   id = AnesthesiaDrug.propofol.id
            case "罗库溴铵": id = AnesthesiaDrug.rocuronium.id
            case "芬太尼":   id = AnesthesiaDrug.fentanyl.id
            case "瑞芬太尼": id = AnesthesiaDrug.remifentanil.id
            default:         id = UUID()
            }

            var drug = AnesthesiaDrug(
                id: id,
                name: entry.name,
                defaultConcentration: entry.defaultConcentration,
                concentrationUnit: entry.concentrationUnit
            )
            drug.aiRules = allDefaultRules
                .filter { $0.drug == drug.name }
                .sorted { $0.doseType < $1.doseType }
            return drug
        }
    }

    // MARK: - Persistence

    private static func saveToDisk(_ drugs: [AnesthesiaDrug]) {
        guard let data = try? JSONEncoder().encode(drugs) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func loadFromDisk() -> [AnesthesiaDrug]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let drugs = try? JSONDecoder().decode([AnesthesiaDrug].self, from: data)
        else { return nil }
        return drugs
    }

    // MARK: - Mutations (call from main thread)

    public func toggleActive(_ drugID: UUID) {
        guard let idx = allDrugs.firstIndex(where: { $0.id == drugID }) else { return }
        allDrugs[idx].isActive.toggle()
    }

    public func append(_ drug: AnesthesiaDrug) {
        allDrugs.append(drug)
    }

    public func remove(atOffsets offsets: IndexSet) {
        allDrugs = allDrugs.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    }

    /// Permanently delete drugs by their UUIDs — used by the SettingsView
    /// edit-mode deletion (red delete circles / swipe-to-delete).
    public func deleteDrugs(_ drugIDs: Set<UUID>) {
        allDrugs.removeAll { drugIDs.contains($0.id) }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var items = allDrugs
        let moved = source.map { items[$0] }
        let sorted = source.sorted(by: >)
        for idx in sorted { items.remove(at: idx) }
        let insertIndex = destination - source.filter { $0 < destination }.count
        items.insert(contentsOf: moved, at: min(insertIndex, items.count))
        allDrugs = items
    }
}
