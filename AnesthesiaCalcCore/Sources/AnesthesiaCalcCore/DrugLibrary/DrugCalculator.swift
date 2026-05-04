import Foundation

// MARK: - DrugDoseRange

/// The lean, AI-powered calculation result returned by the primary
/// `calculateDose(patient:drug:doseType:)` path.
///
/// Unlike the richer `DoseResult` produced by `CalculationEngine`, this type
/// is deliberately minimal so the UI can display it without depending on
/// internal engine types.
public struct DrugDoseRange: Equatable {

    /// Minimum dose in the drug's native unit (mg or mcg; per-kg for bolus, per-kg/h or per-kg/min for infusions)
    public let minDose: Double
    /// Maximum dose in the drug's native unit
    public let maxDose: Double
    /// Native unit string — "mg" or "mcg"
    public let unit: String
    /// Preparation concentration in mg/mL (always SI base unit)
    public let concentrationMgPerMl: Double
    /// The body-weight value (kg) that was multiplied by the dose-per-kg
    public let weightUsed: Double
    /// Which weight basis produced `weightUsed`
    public let weightBase: WeightBase
    /// True when `maxDose` was clamped by `absoluteMaxDose` for safety
    public let wasClampedByAbsoluteMax: Bool
    /// Time basis — bolus, per-hour, or per-minute infusion rate
    public let doseInterval: DoseInterval

    // ── Volume (mL) ───────────────────────────────────────────────────

    /// Factor to convert from native unit to mg  (1.0 for mg; 0.001 for mcg)
    private var toMgFactor: Double {
        DoseUnit(rawValue: unit)?.toMgFactor ?? 1.0
    }

    /// Volume in mL (or mL/h, mL/min — matches `doseInterval`)
    public var minVolumeMl: Double { (minDose * toMgFactor) / concentrationMgPerMl }
    public var maxVolumeMl: Double { (maxDose * toMgFactor) / concentrationMgPerMl }

    // ── Formatting ────────────────────────────────────────────────────

    /// e.g. "105.0 – 175.0 mg"  /  "4.0 – 12.0 mg/h"  /  "0.1 – 0.5 μg/min"
    public var displayString: String {
        let displayUnit = unit == "mcg" ? "μg" : unit
        let suffix = displayUnit + doseInterval.displaySuffix
        if abs(minDose - maxDose) < 1e-9 {
            return String(format: "%.1f \(suffix)", minDose)
        }
        return String(format: "%.1f – %.1f \(suffix)", minDose, maxDose)
    }

    /// e.g. "10.50 – 17.50 mL"  /  "0.40 – 1.20 mL/h"
    public var volumeString: String {
        let suffix = "mL" + doseInterval.displaySuffix
        if abs(minVolumeMl - maxVolumeMl) < 1e-9 {
            return String(format: "%.2f \(suffix)", minVolumeMl)
        }
        return String(format: "%.2f – %.2f \(suffix)", minVolumeMl, maxVolumeMl)
    }
}

// MARK: - Patient

/// The primary user-facing patient model.
///
/// Property names are intentionally concise (`weight`, `height`, `age`) to
/// make call sites in the UI and tests easy to read.  Internally the struct
/// bridges to `PatientContext` for all formula logic, so IBW/LBW are never
/// duplicated.
public struct Patient: Equatable {

    /// Total Body Weight — the patient's actual scale weight (kg)
    public let weight: Double
    /// Height in centimetres
    public let height: Double
    /// Age in completed years
    public let age: Int
    public let sex: BiologicalSex

    public init(weight: Double, height: Double, age: Int, sex: BiologicalSex) {
        self.weight = weight
        self.height = height
        self.age    = age
        self.sex    = sex
    }

    // ── Derived body-weight scalars ───────────────────────────────────
    // Delegate to PatientContext so formulas live in exactly one place.

    /// Ideal Body Weight — Devine formula (1974)
    public var idealBodyWeight: Double { context.idealBodyWeight }
    /// Lean Body Weight — Janmahasatian formula (2005)
    public var leanBodyWeight:  Double { context.leanBodyWeight }
    public var bmi:             Double { context.bmi }
    public var isElderly:       Bool   { context.isElderly }

    /// Resolve the correct weight scalar for a given `WeightBase`.
    public func resolvedWeight(for base: WeightBase) -> Double {
        switch base {
        case .totalBodyWeight: return weight
        case .idealBodyWeight: return idealBodyWeight
        case .leanBodyWeight:  return leanBodyWeight
        }
    }

    // ── Internal bridge ───────────────────────────────────────────────
    var context: PatientContext {
        PatientContext(actualWeight: weight, heightCm: height, age: age, sex: sex)
    }
}

// MARK: - DrugCalculator

/// Core calculation service.
///
/// ## Two independent calculation paths
///
/// ### Primary — AI-powered  →  `DrugDoseRange?`
/// ```
/// AIRuleEngine.dosageRule(for:doseType:)
///     → weightBase  →  patient.resolvedWeight
///     → age scaling →  dose arithmetic
///     → absoluteMaxDose clamp
///     → DrugDoseRange
/// ```
/// Returns **`nil`** when `AIRuleEngine` has no cached rule for the given
/// drug × indication pair. The caller decides how to handle the nil — the
/// calculator itself never silently falls back to another data source.
///
/// ### Secondary — engine-powered  →  `DoseResult`
/// ```
/// drug.rule (DrugLibrary)  →  CalculationEngine  →  DoseResult
/// ```
/// Always succeeds (every `AnesthesiaDrug` has a static `DrugLibrary` entry).
/// Returns the richer `DoseResult` type with pre-formatted strings.
/// Use this path when you need `DoseResult` metadata or as an explicit fallback
/// after the primary path returns `nil`.
public final class DrugCalculator {

    // ── Dependencies ──────────────────────────────────────────────────
    private let ruleEngine: AIRuleEngine

    /// - Parameter ruleEngine: Injectable for unit tests; defaults to the shared singleton.
    public init(ruleEngine: AIRuleEngine = .shared) {
        self.ruleEngine = ruleEngine
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Primary API: AIRuleEngine-powered
    // ══════════════════════════════════════════════════════════════════

    /// Calculate a dose for a patient using the live rule from `AIRuleEngine`.
    ///
    /// - Parameters:
    ///   - patient:   The patient's demographics (weight, height, age, sex).
    ///   - drug:      The `AnesthesiaDrug` to calculate.
    ///   - doseType:  The clinical indication (`DoseType`). Defaults to `.induction`.
    /// - Returns: A `DrugDoseRange` on success, or **`nil`** if `AIRuleEngine` has
    ///   no rule cached for this drug × indication pair.
    public func calculateDose(
        patient: Patient,
        drug: AnesthesiaDrug,
        doseType: DoseType = .induction
    ) -> DrugDoseRange? {

        // ── Step 1: Resolve rule — activeRules first, AIRuleEngine as fallback ──
        // When the drug carries embedded rules (dual-track), those take priority.
        // Legacy drugs without embedded rules fall back to the shared AIRuleEngine.
        let rule: DosageRule?
        if !drug.activeRules.isEmpty {
            rule = drug.activeRules.first { $0.doseType == doseType.rawValue }
        } else {
            rule = ruleEngine.dosageRule(for: drug, doseType: doseType)
        }
        guard let rule else { return nil }

        // ── Step 2: Resolve weight basis (TBW / IBW / LBW) ──────────
        let weight = patient.resolvedWeight(for: rule.weightBase)

        // ── Step 3: Accumulate age-triggered scaling factors ─────────
        // Multiple adjustments compound multiplicatively (e.g. ×0.7 × ×0.8 = ×0.56).
        var ageScale = 1.0
        for adjustment in rule.ageAdjustments ?? [] where patient.age >= adjustment.ageThreshold {
            ageScale *= adjustment.scalingFactor
        }

        // ── Step 4: Compute dose  =  multiplier × weight × ageScale ──
        var minDose = rule.minMultiplier * weight * ageScale
        var maxDose = rule.maxMultiplier * weight * ageScale

        // ── Step 5: Clamp to absoluteMaxDose (patient-safety ceiling) ─
        var clamped = false
        if let cap = rule.absoluteMaxDose, maxDose > cap {
            maxDose = cap
            clamped = true
            if minDose > maxDose { minDose = maxDose }
        }

        return DrugDoseRange(
            minDose:                 minDose,
            maxDose:                 maxDose,
            unit:                    rule.unit,
            concentrationMgPerMl:    rule.concentrationMgPerMl,
            weightUsed:              weight,
            weightBase:              rule.weightBase,
            wasClampedByAbsoluteMax: clamped,
            doseInterval:            rule.doseInterval
        )
    }

    /// Calculate a dose using a raw doseType string instead of the `DoseType` enum.
    ///
    /// This overload is the preferred path for AI-added drugs whose `doseType`
    /// values may be arbitrary Chinese strings (e.g. "诱导", "维持") that do not
    /// correspond to any `DoseType` enum case rawValue.
    ///
    /// - Parameters:
    ///   - patient:         The patient's demographics.
    ///   - drug:            The `AnesthesiaDrug` to calculate.
    ///   - doseTypeString:  The raw doseType string from `DosageRule.doseType`.
    /// - Returns: A `DrugDoseRange` on success, or `nil` when no matching rule is found.
    public func calculateDose(
        patient: Patient,
        drug: AnesthesiaDrug,
        doseTypeString: String
    ) -> DrugDoseRange? {

        let rule: DosageRule?
        if !drug.activeRules.isEmpty {
            rule = drug.activeRules.first { $0.doseType == doseTypeString }
        } else {
            rule = ruleEngine.allRules.first {
                ($0.drug ?? "") == drug.name && $0.doseType == doseTypeString
            }
        }
        guard let rule else { return nil }

        let weight = patient.resolvedWeight(for: rule.weightBase)

        var ageScale = 1.0
        for adjustment in rule.ageAdjustments ?? [] where patient.age >= adjustment.ageThreshold {
            ageScale *= adjustment.scalingFactor
        }

        var minDose = rule.minMultiplier * weight * ageScale
        var maxDose = rule.maxMultiplier * weight * ageScale

        var clamped = false
        if let cap = rule.absoluteMaxDose, maxDose > cap {
            maxDose = cap
            clamped = true
            if minDose > maxDose { minDose = maxDose }
        }

        return DrugDoseRange(
            minDose:                 minDose,
            maxDose:                 maxDose,
            unit:                    rule.unit,
            concentrationMgPerMl:    rule.concentrationMgPerMl,
            weightUsed:              weight,
            weightBase:              rule.weightBase,
            wasClampedByAbsoluteMax: clamped,
            doseInterval:            rule.doseInterval
        )
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Secondary API: static DrugLibrary + CalculationEngine
    // ══════════════════════════════════════════════════════════════════

    /// Calculate a dose using the static `DrugLibrary` rule and `CalculationEngine`.
    ///
    /// Returns `nil` for drugs that have no entry in `DrugLibrary` (e.g. custom
    /// drugs added to `DrugManager` at runtime). Use as an explicit fallback when
    /// `calculateDose(patient:drug:doseType:)` returns `nil`.
    public func calculateLegacyDose(
        patient: Patient,
        drug: AnesthesiaDrug
    ) -> DoseResult? {
        guard let rule = DrugLibrary.rule(for: drug.name) else { return nil }
        return CalculationEngine.calculate(rule: rule, patient: patient.context)
    }

    /// Calculate a `DoseResult` for every active drug in `DrugManager` simultaneously.
    ///
    /// Drugs without a static `DrugLibrary` entry are silently omitted.
    public func calculateAll(patient: Patient) -> [AnesthesiaDrug: DoseResult] {
        let ctx   = patient.context
        var out   = [AnesthesiaDrug: DoseResult]()
        for drug in DrugManager.shared.activeDrugs {
            if let rule = DrugLibrary.rule(for: drug.name) {
                out[drug] = CalculationEngine.calculate(rule: rule, patient: ctx)
            }
        }
        return out
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Pure utility: formatted volume string
    // ══════════════════════════════════════════════════════════════════

    /// Calculate a formatted volume (or pump-rate) string directly from a
    /// `DosageRule` and a pre-resolved weight.
    ///
    /// The caller is responsible for selecting the correct weight basis
    /// (TBW / IBW / LBW) before calling this method.
    ///
    /// - Parameters:
    ///   - drug:   Drug whose `defaultConcentration` (mg/mL) is used for
    ///             volume conversion.
    ///   - rule:   Dosing rule supplying multipliers, native unit, and dose
    ///             interval.
    ///   - weight: Pre-resolved weight in kg.
    /// - Returns: Formatted string such as `"3.5 – 12.2 mL/h"` or `"7.0 mL"`.
    public static func calculateVolumeString(
        drug: AnesthesiaDrug,
        rule: DosageRule,
        weight: Double
    ) -> String {
        let toMg  = DoseUnit(rawValue: rule.unit)?.toMgFactor ?? 1.0
        let conc  = drug.defaultConcentration              // mg/mL (user-editable)
        let minMl = (rule.minMultiplier * weight * toMg) / conc
        let maxMl = (rule.maxMultiplier * weight * toMg) / conc

        let suffix: String
        switch rule.doseInterval {
        case .perHour:   suffix = " mL/h"
        case .perMinute: suffix = " mL/min"
        case .bolus:     suffix = " mL"
        }

        if abs(minMl - maxMl) < 1e-9 {
            return String(format: "%.1f\(suffix)", minMl)
        }
        return String(format: "%.1f – %.1f\(suffix)", minMl, maxMl)
    }
}
