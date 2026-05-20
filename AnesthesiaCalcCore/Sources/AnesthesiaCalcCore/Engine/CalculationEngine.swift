import Foundation

// MARK: - DoseResult

/// The immutable output of one engine calculation.
/// Carries everything the UI needs to render a result and explain it.
public struct DoseResult: Equatable {
    /// Drug / indication label from the rule
    public let drugName: String

    /// The weight (kg) that was multiplied by the dose-per-kg
    public let weightUsed: Double
    /// Which weight type produced `weightUsed`
    public let weightBase: WeightBase

    /// Cumulative product of all applied age-adjustment factors.
    /// 1.0 means no adjustment; 0.7 means dose was reduced to 70 %.
    public let appliedScalingFactor: Double
    /// The specific AgeAdjustment entries that were triggered
    public let appliedAgeAdjustments: [AgeAdjustment]

    // ── Raw SI outputs (always mg / mL) ─────────────────────────────
    public let minDoseMg: Double
    public let maxDoseMg: Double
    public let minDoseMl: Double
    public let maxDoseMl: Double

    // ── Human-readable display outputs ───────────────────────────────
    /// Unit used for `minDisplayDose` / `maxDisplayDose` (mg or mcg)
    public let doseUnit: DoseUnit
    /// Dose expressed in the drug's native unit (e.g. mcg for fentanyl)
    public let minDisplayDose: Double
    public let maxDisplayDose: Double

    // ── Convenience formatting ────────────────────────────────────────

    /// True when the rule specifies a fixed (non-range) dose.
    public var isFixedDose: Bool { abs(minDisplayDose - maxDisplayDose) < 1e-9 }

    /// e.g. "105.0 – 175.0 mg"  or  "70.0 μg"  (fixed dose)
    public var formattedDose: String {
        let u = doseUnit.displayValue
        if isFixedDose {
            return String(format: "%.1f \(u)", minDisplayDose)
        }
        return String(format: "%.1f – %.1f \(u)", minDisplayDose, maxDisplayDose)
    }

    /// e.g. "10.5 – 17.5 mL"  or  "1.4 mL"  (fixed dose)
    public var formattedVolume: String {
        if isFixedDose {
            return String(format: "%.2f mL", minDoseMl)
        }
        return String(format: "%.2f – %.2f mL", minDoseMl, maxDoseMl)
    }
}

// MARK: - CalculationEngine

/// Pure, stateless calculation service.
/// All inputs are value types; the function has no side-effects and is
/// trivially testable and thread-safe.
///
/// - Warning: **Deprecated path.** Prefer `DrugCalculator.calculateDose(patient:drug:doseType:)`
///   which routes through `AIRuleEngine`. This engine and `DrugLibrary` serve as the
///   conservative clinical baseline fallback only.
///   FIXME: Once all DrugLibrary rules are verified against AIRuleEngine defaults,
///   migrate consumers to the primary path and remove CalculationEngine + DrugLibrary.
public enum CalculationEngine {

    /// Calculate the dose for a given drug rule and patient.
    ///
    /// - Parameters:
    ///   - rule:    The drug rule (source of truth for dose / concentration / adjustments)
    ///   - patient: The patient's anthropometric snapshot
    /// - Returns:   A `DoseResult` containing the final mg, mL, and display values
    public static func calculate(rule: DrugRule, patient: PatientContext) -> DoseResult {

        // ── Step 1: Resolve weight basis ─────────────────────────────────
        let weightUsed: Double
        switch rule.weightBase {
        case .totalBodyWeight: weightUsed = patient.actualWeight
        case .idealBodyWeight: weightUsed = patient.idealBodyWeight
        case .leanBodyWeight:  weightUsed = patient.leanBodyWeight
        }

        // ── Step 2: Accumulate age-triggered scaling factors ─────────────
        // Each qualifying AgeAdjustment multiplies the running factor,
        // so rules can stack (e.g. ≥65 → ×0.8, ≥80 → ×0.75 compounds to ×0.60).
        var cumulativeScale       = 1.0
        var triggeredAdjustments: [AgeAdjustment] = []
        for adjustment in rule.ageAdjustments {
            if patient.age >= adjustment.ageThreshold {
                cumulativeScale *= adjustment.scalingFactor
                triggeredAdjustments.append(adjustment)
            }
        }

        // ── Step 3: Apply scaling, then convert native unit → mg ─────────
        // doseRange is stored in doseUnit/kg; toMgFactor converts to mg/kg.
        let toMg             = rule.doseUnit.toMgFactor
        let adjustedMinMgPerKg = rule.doseRange.minDosePerKg * cumulativeScale * toMg
        let adjustedMaxMgPerKg = rule.doseRange.maxDosePerKg * cumulativeScale * toMg

        // ── Step 4: Compute mg ───────────────────────────────────────────
        let minMg = adjustedMinMgPerKg * weightUsed
        let maxMg = adjustedMaxMgPerKg * weightUsed

        // ── Step 5: Convert mg → mL using preparation concentration ─────
        let minMl = minMg / rule.concentrationMgPerMl
        let maxMl = maxMg / rule.concentrationMgPerMl

        // ── Step 6: Scale back to display unit ───────────────────────────
        let fromMg          = rule.doseUnit.fromMgFactor
        let minDisplay      = minMg * fromMg
        let maxDisplay      = maxMg * fromMg

        return DoseResult(
            drugName:                rule.name,
            weightUsed:              weightUsed,
            weightBase:              rule.weightBase,
            appliedScalingFactor:    cumulativeScale,
            appliedAgeAdjustments:   triggeredAdjustments,
            minDoseMg:               minMg,
            maxDoseMg:               maxMg,
            minDoseMl:               minMl,
            maxDoseMl:               maxMl,
            doseUnit:                rule.doseUnit,
            minDisplayDose:          minDisplay,
            maxDisplayDose:          maxDisplay
        )
    }
}
