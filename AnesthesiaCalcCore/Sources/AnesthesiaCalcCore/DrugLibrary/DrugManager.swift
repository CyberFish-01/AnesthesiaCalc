import Combine
import Foundation

/// Manages the ordered list of drugs shown in the dose calculator.
///
/// Observe this singleton in SwiftUI views with `@StateObject` or inject it
/// via the environment. Views reactively update whenever `activeDrugs` changes.
public final class DrugManager: ObservableObject {

    /// Shared singleton — use this in production code and SwiftUI previews.
    public static let shared = DrugManager()

    /// The ordered list of drugs currently active in the calculator.
    @Published public var activeDrugs: [AnesthesiaDrug]

    private init() {
        // Start with the four built-in drugs, then backfill their aiRules
        // from AIRuleEngine's pre-loaded defaults so the dual-track fields
        // are populated from the very first launch.
        var defaults: [AnesthesiaDrug] = [.propofol, .rocuronium, .fentanyl, .remifentanil]
        let allDefaultRules = AIRuleEngine.shared.allRules
        for i in defaults.indices {
            defaults[i].aiRules = allDefaultRules
                .filter { $0.drug == defaults[i].name }
                .sorted { $0.doseType < $1.doseType }
        }
        activeDrugs = defaults
    }
}
