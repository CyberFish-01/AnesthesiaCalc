import Foundation

// MARK: - RiskWarning

public struct RiskWarning: Equatable, Identifiable {
    public let message: String
    public var id: String { message }
}

// MARK: - RiskAssessment

public struct RiskAssessment: Equatable {
    public let warnings: [RiskWarning]

    public var hasWarnings: Bool { !warnings.isEmpty }

    public init(warnings: [RiskWarning] = []) {
        self.warnings = warnings
    }
}

// MARK: - AutoWeightResult

public struct AutoWeightResult: Equatable {
    /// The weight basis to actually use for calculation
    public let effectiveWeightBase: WeightBase
    /// True when auto-routing overrode the default TBW
    public let wasAutoRouted: Bool

    public init(effectiveWeightBase: WeightBase, wasAutoRouted: Bool) {
        self.effectiveWeightBase = effectiveWeightBase
        self.wasAutoRouted = wasAutoRouted
    }
}

// MARK: - RiskEngine

/// Pure-logic risk assessor + auto-weight router — evaluates a patient
/// snapshot against a drug and returns clinical warnings and weight routing
/// decisions the UI can surface.
///
/// Zero UI dependencies. Called from any thread-safe context.
public enum RiskEngine {

    // MARK: - Risk assessment

    /// Assess risk for one patient × drug pair.
    public static func assess(patient: PatientContext, drugName: String) -> RiskAssessment {
        var warnings: [RiskWarning] = []

        // Rule 1: geriatric — all drugs
        if patient.isElderly {
            warnings.append(RiskWarning(
                message: "高龄患者，建议减量诱导，加强循环监测"
            ))
        }

        // Rule 2: obesity — muscle relaxants should use IBW
        if patient.bmi > 30 && DrugCatalog.category(for: drugName) == "神经肌肉阻滞药" {
            warnings.append(RiskWarning(
                message: "肥胖患者，肌松药建议参考理想体重 (IBW)"
            ))
        }

        return RiskAssessment(warnings: warnings)
    }

    // MARK: - Auto weight routing

    /// Determine the effective weight basis for a drug × patient combination.
    ///
    /// Clinical rules (applied in order):
    /// - Muscle relaxants (DrugCatalog category "神经肌肉阻滞药") + BMI > 30 → IBW
    /// - Lipophilic opioids (DrugCatalog category "阿片类镇痛药") + BMI > 32 → LBW
    /// - Default → TBW
    ///
    /// This completely replaces the rule's static `weightBase` — the auto-router
    /// is the single source of truth for weight basis selection.
    public static func resolveWeightBase(drugName: String, bmi: Double) -> AutoWeightResult {
        // Rule 1: muscle relaxant + obesity → IBW
        if DrugCatalog.category(for: drugName) == "神经肌肉阻滞药" && bmi > 30 {
            return AutoWeightResult(effectiveWeightBase: .idealBodyWeight, wasAutoRouted: true)
        }

        // Rule 2: lipophilic opioid + severe obesity → LBW
        if DrugCatalog.category(for: drugName) == "阿片类镇痛药" && bmi > 32 {
            return AutoWeightResult(effectiveWeightBase: .leanBodyWeight, wasAutoRouted: true)
        }

        // Default: TBW
        return AutoWeightResult(effectiveWeightBase: .totalBodyWeight, wasAutoRouted: false)
    }

    // MARK: - Drug classification helpers
    // Removed: isMuscleRelaxant / isLipophilicOpioid — replaced by
    // DrugCatalog.category(for:) queries above.
}
