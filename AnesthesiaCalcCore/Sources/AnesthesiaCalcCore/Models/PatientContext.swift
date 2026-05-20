import Foundation

// MARK: - BiologicalSex

public enum BiologicalSex: String, Codable, CaseIterable {
    case male
    case female
}

// MARK: - PatientContext

/// Immutable snapshot of patient anthropometrics used as the sole input
/// to every calculation. Keeping it a plain value type means the engine
/// can be called from any thread without synchronisation.
public struct PatientContext: Equatable {
    /// Total Body Weight in kilograms (TBW / actual weight)
    public let actualWeight: Double
    /// Height in centimetres
    public let heightCm: Double
    /// Age in completed years
    public let age: Int
    public let sex: BiologicalSex

    public init(actualWeight: Double, heightCm: Double, age: Int, sex: BiologicalSex) {
        precondition(actualWeight > 0, "actualWeight must be positive")
        precondition(heightCm > 0,     "heightCm must be positive")
        precondition(age >= 0,         "age must be non-negative")
        self.actualWeight = actualWeight
        self.heightCm     = heightCm
        self.age          = age
        self.sex          = sex
    }
}

// MARK: - Derived Body Weight Calculations

public extension PatientContext {

    // ------------------------------------------------------------------
    // Ideal Body Weight — Devine formula (1974), cm-based form
    //   Male:   IBW = 50.0  + 0.91 × (heightCm − 152.4)
    //   Female: IBW = 45.5  + 0.91 × (heightCm − 152.4)
    //
    // 0.91 kg/cm ≡ 2.3 lb/in converted to metric; 152.4 cm ≡ 60 inches.
    // Clamped to the baseline so very short patients never yield a
    // negative IBW.
    // ------------------------------------------------------------------
    var idealBodyWeight: Double {
        let base: Double = (sex == .male) ? 50.0 : 45.5
        return max(base, base + 0.91 * (heightCm - 152.4))
    }

    // ------------------------------------------------------------------
    // Lean Body Weight — Boer formula (1984)
    //   Male:   LBW = 0.407 × TBW + 0.267 × heightCm − 19.2
    //   Female: LBW = 0.252 × TBW + 0.473 × heightCm − 48.3
    //
    // Reference: Boer P. (1984) Am J Physiol 247:F632–F636.
    // Widely used in anaesthetic TCI and infusion dosing.
    // Clamped to a small positive value to guard against extreme inputs.
    // ------------------------------------------------------------------
    var leanBodyWeight: Double {
        let raw: Double
        switch sex {
        case .male:
            raw = 0.407 * actualWeight + 0.267 * heightCm - 19.2
        case .female:
            raw = 0.252 * actualWeight + 0.473 * heightCm - 48.3
        }
        return max(1.0, raw)
    }

    var bmi: Double {
        let heightM = heightCm / 100.0
        return actualWeight / (heightM * heightM)
    }

    /// Clinically, ≥ 65 years triggers conservative dosing in most guidelines.
    var isElderly: Bool { age >= 65 }

    /// Resolve the correct weight scalar for a given `WeightBase`.
    public func resolvedWeight(for base: WeightBase) -> Double {
        switch base {
        case .totalBodyWeight: return actualWeight
        case .idealBodyWeight: return idealBodyWeight
        case .leanBodyWeight:  return leanBodyWeight
        }
    }
}
