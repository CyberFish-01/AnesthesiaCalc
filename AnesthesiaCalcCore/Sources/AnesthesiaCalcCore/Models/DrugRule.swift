import Foundation

// MARK: - DoseInterval

/// Describes the time basis of a dose-per-kg multiplier.
///
/// Bolus rules express an absolute dose (mg/kg or mcg/kg).
/// Infusion rules express a rate (mg/kg/h, mcg/kg/min, etc.) — the multiplier
/// represents how much drug is delivered per kg per time unit.
public enum DoseInterval: String, Codable, CaseIterable {
    /// Single injection — the default for induction / intubation boluses.
    case bolus     = "bolus"
    /// Continuous infusion rate per hour (e.g. propofol maintenance: mg/kg/h).
    case perHour   = "perHour"
    /// Continuous infusion rate per minute (e.g. remifentanil: mcg/kg/min).
    case perMinute = "perMinute"

    /// Unit suffix appended to the dose and volume display strings.
    public var displaySuffix: String {
        switch self {
        case .bolus:     return ""
        case .perHour:   return "/h"
        case .perMinute: return "/min"
        }
    }
}

// MARK: - DoseUnit

/// The unit in which a drug's dose-per-kg is naturally expressed.
///
/// Internally the engine always converts to milligrams for arithmetic.
/// `DoseUnit` is only used at the boundary: reading the rule and
/// writing the display output.
public enum DoseUnit: String, Codable, CaseIterable {
    case mg   // milligrams — default for most anaesthetic drugs
    case mcg  // micrograms — opioids (fentanyl, remifentanil …)

    /// Converts a value expressed in this unit into milligrams.
    /// e.g.  1 mcg × 0.001 = 0.001 mg
    public var toMgFactor: Double {
        switch self {
        case .mg:  return 1.0
        case .mcg: return 0.001
        }
    }

    /// Converts a milligram value back to this display unit.
    /// e.g.  0.07 mg × 1000 = 70 mcg
    public var fromMgFactor: Double { 1.0 / toMgFactor }
}

// MARK: - WeightBase

/// Specifies which body-weight scalar the dose-per-kg calculation uses.
/// Choosing the wrong basis is a patient-safety issue (e.g. dosing an
/// obese patient's rocuronium on TBW risks prolonged block).
///
/// Raw values are the canonical 3-letter abbreviations that AI/JSON layers use.
public enum WeightBase: String, Codable, CaseIterable {
    /// Total Body Weight — the patient's actual scale weight
    case totalBodyWeight = "TBW"
    /// Ideal Body Weight — Devine formula; used when lipophilicity is low
    case idealBodyWeight = "IBW"
    /// Lean Body Weight — Janmahasatian formula; used for highly lipophilic drugs
    case leanBodyWeight  = "LBW"
}

// MARK: - DoseRange

/// A half-open interval [min, max] in **[doseUnit]/kg** representing the therapeutic window.
/// min == max is valid for drugs with a single fixed dose (e.g. Rocuronium 0.6 mg/kg).
///
/// The unit is determined by the enclosing `DrugRule.doseUnit`.
/// For example, a Fentanyl rule with `doseUnit = .mcg` stores 1.0–2.0 here (mcg/kg).
public struct DoseRange: Equatable {
    public let minDosePerKg: Double   // [doseUnit]/kg
    public let maxDosePerKg: Double   // [doseUnit]/kg

    public init(minDosePerKg: Double, maxDosePerKg: Double) {
        precondition(minDosePerKg > 0,                   "minDosePerKg must be positive")
        precondition(maxDosePerKg >= minDosePerKg,       "max must be ≥ min")
        self.minDosePerKg = minDosePerKg
        self.maxDosePerKg = maxDosePerKg
    }

    /// Convenience for single-value doses (min == max)
    public init(fixed dosePerKg: Double) {
        self.init(minDosePerKg: dosePerKg, maxDosePerKg: dosePerKg)
    }

    var isFixedDose: Bool { minDosePerKg == maxDosePerKg }
}

// MARK: - AgeAdjustment

/// A threshold-triggered multiplicative scaling factor.
/// Multiple adjustments stack: a 0.8 × 0.7 = 0.56 combined factor.
public struct AgeAdjustment: Equatable, Codable {
    /// Apply this rule when patient.age >= ageThreshold
    public let ageThreshold: Int
    /// Multiply the dose range by this factor (must be in (0, 1] — never increases dose)
    public let scalingFactor: Double

    public init(ageThreshold: Int, scalingFactor: Double) {
        precondition(ageThreshold > 0,                   "ageThreshold must be positive")
        precondition(scalingFactor > 0 && scalingFactor <= 1.0,
                     "scalingFactor must be in (0, 1] — age adjustments only reduce dose")
        self.ageThreshold  = ageThreshold
        self.scalingFactor = scalingFactor
    }
}

// MARK: - DrugRule

/// A self-contained, serialisable rule that fully describes how to calculate
/// a dose for one drug/indication combination.
///
/// Designed for AI-driven updates: the entire rule can be replaced atomically
/// when a new guideline is parsed, without touching the engine or UI.
public struct DrugRule: Equatable {
    /// Human-readable name, e.g. "Propofol (Induction)"
    public let name: String
    /// Which weight scalar to use
    public let weightBase: WeightBase
    /// Therapeutic dose window in [doseUnit]/kg (before age adjustments)
    public let doseRange: DoseRange
    /// Drug concentration of the commercial preparation in **mg/mL** (always SI base unit)
    public let concentrationMgPerMl: Double
    /// Ordered list of age-triggered dose reductions.
    /// Multiple entries are evaluated independently and their factors multiplied.
    public let ageAdjustments: [AgeAdjustment]
    /// Unit used to express and display the dose (e.g. `.mg` for propofol, `.mcg` for fentanyl)
    public let doseUnit: DoseUnit

    public init(
        name: String,
        weightBase: WeightBase,
        doseRange: DoseRange,
        concentrationMgPerMl: Double,
        ageAdjustments: [AgeAdjustment] = [],
        doseUnit: DoseUnit = .mg
    ) {
        precondition(concentrationMgPerMl > 0, "concentration must be positive")
        self.name                 = name
        self.weightBase           = weightBase
        self.doseRange            = doseRange
        self.concentrationMgPerMl = concentrationMgPerMl
        self.ageAdjustments       = ageAdjustments
        self.doseUnit             = doseUnit
    }
}
