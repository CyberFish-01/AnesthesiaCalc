import Foundation

/// A curated catalogue of evidence-based drug rules.
///
/// Each static property is a single, replaceable `DrugRule` value.
/// When the AI parses an updated guideline, it can overwrite exactly
/// one entry without touching the engine or any other rule.
public enum DrugLibrary {

    // ──────────────────────────────────────────────────────────────────
    // PROPOFOL — Induction
    //
    // Reference: BNF / Miller's Anesthesia 9th Ed. / Fresenius PI
    // Dose:        1.5 – 2.5 mg/kg TBW (healthy adults, slow titration)
    // Elderly (≥65): reduce dose by 30 % (factor 0.7); titrate more slowly
    //               due to reduced cardiac output and plasma clearance.
    // Preparation: Diprivan® 1 % → 10 mg/mL
    // ──────────────────────────────────────────────────────────────────
    public static let propofol = DrugRule(
        name: "Propofol (Induction)",
        weightBase: .totalBodyWeight,
        doseRange: DoseRange(minDosePerKg: 1.5, maxDosePerKg: 2.5),
        concentrationMgPerMl: 10.0,
        ageAdjustments: [
            AgeAdjustment(ageThreshold: 65, scalingFactor: 0.7)
        ]
    )

    // ──────────────────────────────────────────────────────────────────
    // ROCURONIUM — Endotracheal Intubation (standard, non-RSI)
    //
    // Reference: Lund & Stovner / ESAIC guidelines / SmPC
    // Dose:        0.6 mg/kg IBW
    // Weight basis: IBW (Devine formula) — CRITICAL SAFETY RULE.
    //   Using TBW in obese patients causes significantly prolonged
    //   neuromuscular block (rocuronium Vd does not scale with fat mass).
    // Preparation: Esmeron® 10 mg/mL
    // ──────────────────────────────────────────────────────────────────
    public static let rocuronium = DrugRule(
        name: "Rocuronium (Intubation)",
        weightBase: .idealBodyWeight,
        doseRange: DoseRange(fixed: 0.6),
        concentrationMgPerMl: 10.0,
        ageAdjustments: []
    )

    // ──────────────────────────────────────────────────────────────────
    // FENTANYL — Induction (balanced anaesthesia)
    //
    // Reference: Miller's Anesthesia 9th Ed. / BNF / Janssen PI
    // Dose:        1 – 2 mcg/kg TBW
    //   Lower end for brief procedures; 2 mcg/kg for major surgery.
    //   Elderly / haemodynamically compromised: titrate to 1 mcg/kg.
    // doseUnit:    .mcg — stored and displayed in micrograms
    // Preparation: Sublimaze® 50 mcg/mL = 0.05 mg/mL
    // ──────────────────────────────────────────────────────────────────
    public static let fentanyl = DrugRule(
        name: "Fentanyl (Induction)",
        weightBase: .totalBodyWeight,
        doseRange: DoseRange(minDosePerKg: 1.0, maxDosePerKg: 2.0),  // mcg/kg
        concentrationMgPerMl: 0.05,                                   // 50 mcg/mL
        ageAdjustments: [
            AgeAdjustment(ageThreshold: 65, scalingFactor: 0.5)       // halve for elderly
        ],
        doseUnit: .mcg
    )

    // ──────────────────────────────────────────────────────────────────
    // REMIFENTANIL — Induction (legacy engine fallback; bolus path only)
    //
    // Reference: Ultiva® SmPC / Miller's Anesthesia 9th Ed.
    // Dose:        1 – 2 mcg/kg TBW over 60–90 s
    // doseUnit:    .mcg
    // Preparation: Ultiva® 1 mg reconstituted in 20 mL → 50 mcg/mL = 0.05 mg/mL
    //
    // Note: For maintenance and analgesia infusion rates (mcg/kg/min),
    // use the AI-powered path via AIRuleEngine / DrugCalculator.calculateDose(patient:drug:doseType:).
    // ──────────────────────────────────────────────────────────────────
    public static let remifentanil = DrugRule(
        name: "Remifentanil (Induction)",
        weightBase: .totalBodyWeight,
        doseRange: DoseRange(minDosePerKg: 1.0, maxDosePerKg: 2.0),  // mcg/kg
        concentrationMgPerMl: 0.05,                                   // 50 mcg/mL
        ageAdjustments: [],
        doseUnit: .mcg
    )
}

// MARK: — Legacy rule lookup

public extension DrugLibrary {

    /// Look up the legacy `DrugRule` for a drug by its `AnesthesiaDrug.name`.
    ///
    /// Returns `nil` for drugs not present in the static built-in library.
    /// Used by `DrugCalculator.calculateLegacyDose(patient:drug:)` to avoid
    /// hard-coding a switch over `AnesthesiaDrug` cases.
    static func rule(for drugName: String) -> DrugRule? {
        catalogue[drugName]
    }

    private static let catalogue: [String: DrugRule] = [
        AnesthesiaDrug.propofol.name:     propofol,
        AnesthesiaDrug.rocuronium.name:   rocuronium,
        AnesthesiaDrug.fentanyl.name:     fentanyl,
        AnesthesiaDrug.remifentanil.name: remifentanil,
    ]
}
