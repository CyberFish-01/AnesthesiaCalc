import Foundation

// MARK: - DoseType

/// The clinical indication for which a dose is being calculated.
/// Used as the second axis of the rule-cache key alongside the drug name.
public enum DoseType: String, Codable, CaseIterable {
    case induction   = "induction"    // 全麻诱导
    case intubation  = "intubation"   // 气管插管
    case maintenance = "maintenance"  // 麻醉维持
    case sedation    = "sedation"     // 镇静
    case analgesia   = "analgesia"    // 镇痛

    /// Short Chinese label for use in segmented pickers and compact UI.
    public var displayName: String {
        switch self {
        case .induction:   return "诱导"
        case .intubation:  return "插管"
        case .maintenance: return "维持"
        case .sedation:    return "镇静"
        case .analgesia:   return "镇痛"
        }
    }
}

// MARK: - DosageRule

/// A fully Codable, AI-injectable dosing rule for one drug × indication pair.
///
/// This is the **AI boundary type**: the JSON that an LLM returns to update
/// clinical guidelines is decoded directly into `[DosageRule]` and merged
/// into `AIRuleEngine`'s cache — no other code needs to change.
///
/// ## JSON format (example — Propofol induction)
/// ```json
/// {
///   "drug": "丙泊酚 (Propofol)",
///   "doseType": "induction",
///   "minMultiplier": 1.5,
///   "maxMultiplier": 2.5,
///   "weightBase": "TBW",
///   "unit": "mg",
///   "concentrationMgPerMl": 10.0,
///   "absoluteMaxDose": 300.0,
///   "ageAdjustments": [
///     { "ageThreshold": 65, "scalingFactor": 0.7 }
///   ]
/// }
/// ```
/// > Note: keys follow camelCase. If your AI layer returns snake_case, set
/// > `JSONDecoder().keyDecodingStrategy = .convertFromSnakeCase`.
public struct DosageRule: Equatable {

    /// Matches `AnesthesiaDrug.name` — the short Chinese drug name (e.g. "丙泊酚")
    /// Optional so the AI can omit it at the rule level; back-filled by `AIAssistantService`
    /// from the outer `drug.name` field after decoding.
    public var drug: String?

    /// Matches `DoseType.rawValue` — clinical indication
    public let doseType: String

    /// Minimum dose per kg (or per kg/h, per kg/min) in the drug's native unit
    public let minMultiplier: Double

    /// Maximum dose per kg (or per kg/h, per kg/min) in the drug's native unit
    public let maxMultiplier: Double

    /// Which body-weight scalar to use for the per-kg multiplication
    public let weightBase: WeightBase

    /// Native unit of the dose ("mg" or "mcg") — must match a `DoseUnit` rawValue
    public let unit: String

    /// Commercial preparation concentration, always in **mg/mL**
    /// (e.g. Propofol 1 % = 10 mg/mL; Fentanyl 50 mcg/mL = 0.05 mg/mL)
    /// `var` so post-processing in `AIAssistantService` can back-fill from
    /// `drug.defaultConcentration` when the AI omits this redundant field.
    public var concentrationMgPerMl: Double

    /// Optional safety ceiling in the drug's native unit.
    /// When non-nil, the engine must clamp the calculated dose to this value.
    public let absoluteMaxDose: Double?

    /// Optional age-triggered dose reductions injected by the AI.
    /// Falls back to an empty array when omitted from JSON.
    public let ageAdjustments: [AgeAdjustment]?

    /// Time basis of the multiplier — bolus, per-hour infusion, or per-minute infusion.
    /// Defaults to `.bolus` when the field is absent from JSON (backward compatible).
    public let doseInterval: DoseInterval

    /// Optional free-text clinical note returned by the AI (e.g. dosing caveats,
    /// monitoring requirements). Ignored by the calculation engine; shown in UI only.
    public let note: String?

    public init(
        drug: String?,
        doseType: String,
        minMultiplier: Double,
        maxMultiplier: Double,
        weightBase: WeightBase,
        unit: String,
        concentrationMgPerMl: Double,
        absoluteMaxDose: Double?,
        ageAdjustments: [AgeAdjustment]?,
        doseInterval: DoseInterval = .bolus,
        note: String? = nil
    ) {
        self.drug                 = drug
        self.doseType             = doseType
        self.minMultiplier        = minMultiplier
        self.maxMultiplier        = maxMultiplier
        self.weightBase           = weightBase
        self.unit                 = unit
        self.concentrationMgPerMl = concentrationMgPerMl
        self.absoluteMaxDose      = absoluteMaxDose
        self.ageAdjustments       = ageAdjustments
        self.doseInterval         = doseInterval
        self.note                 = note
    }

    // ── Convenience bridge ────────────────────────────────────────────

    /// Converts this AI rule to the low-level `DrugRule` consumed by `CalculationEngine`.
    /// Returns `nil` if `unit` is not a recognised `DoseUnit` raw value.
    /// Note: `CalculationEngine` is bolus-only; this bridge is used only for the
    /// secondary fallback path.
    public func asDrugRule() -> DrugRule? {
        guard let doseUnit = DoseUnit(rawValue: unit) else { return nil }
        return DrugRule(
            name: "\(drug ?? "") (\(doseType))",
            weightBase: weightBase,
            doseRange: DoseRange(minDosePerKg: minMultiplier, maxDosePerKg: maxMultiplier),
            concentrationMgPerMl: concentrationMgPerMl,
            ageAdjustments: ageAdjustments ?? [],
            doseUnit: doseUnit
        )
    }
}

// MARK: DosageRule — Codable (manual, for backward-compatible JSON)

extension DosageRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case drug, doseType, minMultiplier, maxMultiplier
        case weightBase, unit, concentrationMgPerMl
        case absoluteMaxDose, ageAdjustments, doseInterval
        case note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        drug                 = try c.decodeIfPresent(String.self,  forKey: .drug)
        doseType             = try c.decode(String.self,          forKey: .doseType)
        minMultiplier        = try c.decode(Double.self,          forKey: .minMultiplier)
        maxMultiplier        = try c.decodeIfPresent(Double.self, forKey: .maxMultiplier) ?? minMultiplier
        weightBase           = try c.decode(WeightBase.self,      forKey: .weightBase)
        unit                 = try c.decode(String.self,          forKey: .unit)
        concentrationMgPerMl = try c.decodeIfPresent(Double.self, forKey: .concentrationMgPerMl) ?? 0
        absoluteMaxDose      = try c.decodeIfPresent(Double.self, forKey: .absoluteMaxDose)
        ageAdjustments       = try c.decodeIfPresent([AgeAdjustment].self, forKey: .ageAdjustments)
        doseInterval         = try c.decodeIfPresent(DoseInterval.self,   forKey: .doseInterval) ?? .bolus
        note                 = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

// MARK: - AIRuleEngine

/// Thread-safe singleton that owns the live catalogue of dosing rules.
///
/// ## Lifecycle
/// 1. App starts → `AIRuleEngine.shared` is created → `loadDefaultRules()` runs
///    and pre-populates the cache with evidence-based baseline rules.
/// 2. When an AI response arrives, call `updateRules(from:)` with the raw JSON
///    bytes → rules are decoded and merged atomically (existing keys overwritten,
///    unknown keys added, absent keys untouched).
/// 3. `DrugCalculator` calls `drugRule(for:doseType:)` to retrieve the current
///    best rule for a drug, transparently falling back to `DrugLibrary` if the
///    AI has not yet provided an override.
///
/// ## Thread safety
/// All reads and writes to the internal dictionary go through a concurrent queue
/// with barrier-protected writes (readers-writer lock pattern).
public final class AIRuleEngine {

    // ── Singleton ─────────────────────────────────────────────────────
    public static let shared = AIRuleEngine()

    // ── Storage ───────────────────────────────────────────────────────
    private var rules: [String: DosageRule] = [:]
    private let queue = DispatchQueue(
        label: "com.anesthesiacalc.airuleengine",
        attributes: .concurrent
    )

    // ── Initialisation ────────────────────────────────────────────────
    /// Internal so `@testable import` can create isolated instances in tests,
    /// while external callers must use `AIRuleEngine.shared`.
    init() {
        loadDefaultRules()
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Public API
    // ══════════════════════════════════════════════════════════════════

    /// Decode a JSON array of `DosageRule` objects and merge them into the cache.
    ///
    /// Rules with matching keys (drug + doseType) are **replaced**; rules for
    /// other drug/indication pairs are left unchanged.
    ///
    /// - Parameter json: Raw JSON bytes, e.g. from a network response.
    /// - Throws: `DecodingError` if the JSON is malformed.
    public func updateRules(from json: Data) throws {
        let decoder = JSONDecoder()
        let incoming = try decoder.decode([DosageRule].self, from: json)
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            for rule in incoming {
                self.rules[Self.key(drug: rule.drug ?? "", doseType: rule.doseType)] = rule
            }
        }
    }

    /// Retrieve the current `DosageRule` for a drug × indication pair, if any.
    public func dosageRule(
        for drug: AnesthesiaDrug,
        doseType: DoseType = .induction
    ) -> DosageRule? {
        queue.sync {
            rules[Self.key(drug: drug.name, doseType: doseType.rawValue)]
        }
    }

    /// Retrieve the current `DrugRule` (engine type) for a drug × indication pair.
    /// Returns `nil` if no rule is cached or the cached rule has an unknown unit.
    public func drugRule(
        for drug: AnesthesiaDrug,
        doseType: DoseType = .induction
    ) -> DrugRule? {
        dosageRule(for: drug, doseType: doseType)?.asDrugRule()
    }

    /// Replace the entire rule cache — useful in tests or for a full AI refresh.
    public func replaceAllRules(with newRules: [DosageRule]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.rules.removeAll()
            for rule in newRules {
                self.rules[Self.key(drug: rule.drug ?? "", doseType: rule.doseType)] = rule
            }
        }
    }

    /// All currently cached rules (snapshot, safe to call from any thread).
    public var allRules: [DosageRule] {
        queue.sync { Array(rules.values) }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Default rules (evidence-based baseline)
    // ══════════════════════════════════════════════════════════════════

    private func loadDefaultRules() {
        let defaults: [DosageRule] = [

            // ══════════════════════════════════════════════════════════════
            // 丙泊酚 (Propofol)
            // ══════════════════════════════════════════════════════════════

            // ── Propofol — Induction ───────────────────────────────────────
            // Ref: Miller's Anesthesia 9th Ed. / BNF / Fresenius PI
            // Dose: 1.5–2.5 mg/kg TBW; elderly (≥65 y) reduce by 30 %
            DosageRule(
                drug:                 AnesthesiaDrug.propofol.name,
                doseType:             DoseType.induction.rawValue,
                minMultiplier:        1.5,
                maxMultiplier:        2.5,
                weightBase:           .totalBodyWeight,
                unit:                 DoseUnit.mg.rawValue,
                concentrationMgPerMl: 10.0,
                absoluteMaxDose:      300.0,
                ageAdjustments:       [AgeAdjustment(ageThreshold: 65, scalingFactor: 0.7)],
                doseInterval:         .bolus
            ),

            // ── Propofol — Maintenance (TIVA) ─────────────────────────────
            // Ref: Miller's / Schnider TCI model / Fresenius PI
            // Rate: 4–12 mg/kg/h TBW; titrate to effect (BIS/entropy target)
            DosageRule(
                drug:                 AnesthesiaDrug.propofol.name,
                doseType:             DoseType.maintenance.rawValue,
                minMultiplier:        4.0,
                maxMultiplier:        12.0,
                weightBase:           .totalBodyWeight,
                unit:                 DoseUnit.mg.rawValue,
                concentrationMgPerMl: 10.0,
                absoluteMaxDose:      nil,
                ageAdjustments:       [],
                doseInterval:         .perHour
            ),

            // ── Propofol — Sedation (procedural / ICU) ────────────────────
            // Ref: BNF / Fresenius PI
            // Rate: 0.5–4 mg/kg/h TBW; start low, titrate to Ramsay 2–3
            DosageRule(
                drug:                 AnesthesiaDrug.propofol.name,
                doseType:             DoseType.sedation.rawValue,
                minMultiplier:        0.5,
                maxMultiplier:        4.0,
                weightBase:           .totalBodyWeight,
                unit:                 DoseUnit.mg.rawValue,
                concentrationMgPerMl: 10.0,
                absoluteMaxDose:      nil,
                ageAdjustments:       [],
                doseInterval:         .perHour
            ),

            // ══════════════════════════════════════════════════════════════
            // 罗库溴铵 (Rocuronium)
            // ══════════════════════════════════════════════════════════════

            // ── Rocuronium — Intubation ────────────────────────────────────
            // Ref: ESAIC guidelines / Esmeron SmPC
            // Dose: 0.6–0.9 mg/kg IBW — CRITICAL: IBW prevents overdose in obese
            DosageRule(
                drug:                 AnesthesiaDrug.rocuronium.name,
                doseType:             DoseType.intubation.rawValue,
                minMultiplier:        0.6,
                maxMultiplier:        0.9,
                weightBase:           .idealBodyWeight,
                unit:                 DoseUnit.mg.rawValue,
                concentrationMgPerMl: 10.0,
                absoluteMaxDose:      nil,
                ageAdjustments:       [],
                doseInterval:         .bolus
            ),

            // ── Rocuronium — Maintenance infusion ─────────────────────────
            // Ref: Esmeron SmPC / Miller's
            // Rate: 0.3–0.6 mg/kg/h IBW; guided by TOF monitoring
            DosageRule(
                drug:                 AnesthesiaDrug.rocuronium.name,
                doseType:             DoseType.maintenance.rawValue,
                minMultiplier:        0.3,
                maxMultiplier:        0.6,
                weightBase:           .idealBodyWeight,
                unit:                 DoseUnit.mg.rawValue,
                concentrationMgPerMl: 10.0,
                absoluteMaxDose:      nil,
                ageAdjustments:       [],
                doseInterval:         .perHour
            ),

            // ══════════════════════════════════════════════════════════════
            // 芬太尼 (Fentanyl)
            // ══════════════════════════════════════════════════════════════

            // ── Fentanyl — Induction ───────────────────────────────────────
            // Ref: Miller's / Janssen PI
            // Dose: 1–2 mcg/kg TBW; elderly (≥65 y) halve the dose
            DosageRule(
                drug:                 AnesthesiaDrug.fentanyl.name,
                doseType:             DoseType.induction.rawValue,
                minMultiplier:        1.0,
                maxMultiplier:        2.0,
                weightBase:           .totalBodyWeight,
                unit:                 DoseUnit.mcg.rawValue,
                concentrationMgPerMl: 0.05,               // 50 mcg/mL
                absoluteMaxDose:      200.0,               // mcg safety cap
                ageAdjustments:       [AgeAdjustment(ageThreshold: 65, scalingFactor: 0.5)],
                doseInterval:         .bolus
            ),

            // ══════════════════════════════════════════════════════════════
            // 瑞芬太尼 (Remifentanil)
            // ══════════════════════════════════════════════════════════════

            // ── Remifentanil — Induction ───────────────────────────────────
            // Ref: Miller's / GlaxoSmithKline PI (Ultiva®)
            // Dose: 1–2 mcg/kg TBW over 60–90 s; titrate to ablate
            // laryngoscopy response
            DosageRule(
                drug:                 AnesthesiaDrug.remifentanil.name,
                doseType:             DoseType.induction.rawValue,
                minMultiplier:        1.0,
                maxMultiplier:        2.0,
                weightBase:           .totalBodyWeight,
                unit:                 DoseUnit.mcg.rawValue,
                concentrationMgPerMl: 0.05,               // 50 mcg/mL standard
                absoluteMaxDose:      200.0,
                ageAdjustments:       [],
                doseInterval:         .bolus
            ),

            // ── Remifentanil — Maintenance infusion ───────────────────────
            // Ref: Ultiva® SmPC / Miller's TCI
            // Rate: 0.1–0.5 mcg/kg/min TBW; titrate to surgical stimulus
            DosageRule(
                drug:                 AnesthesiaDrug.remifentanil.name,
                doseType:             DoseType.maintenance.rawValue,
                minMultiplier:        0.1,
                maxMultiplier:        0.5,
                weightBase:           .totalBodyWeight,
                unit:                 DoseUnit.mcg.rawValue,
                concentrationMgPerMl: 0.05,
                absoluteMaxDose:      nil,
                ageAdjustments:       [],
                doseInterval:         .perMinute
            ),

            // ── Remifentanil — Analgesia infusion ─────────────────────────
            // Ref: Ultiva® SmPC / ICU analgesia protocols
            // Rate: 0.05–0.2 mcg/kg/min TBW; lower range for post-op / ICU
            DosageRule(
                drug:                 AnesthesiaDrug.remifentanil.name,
                doseType:             DoseType.analgesia.rawValue,
                minMultiplier:        0.05,
                maxMultiplier:        0.2,
                weightBase:           .totalBodyWeight,
                unit:                 DoseUnit.mcg.rawValue,
                concentrationMgPerMl: 0.05,
                absoluteMaxDose:      nil,
                ageAdjustments:       [],
                doseInterval:         .perMinute
            ),
        ]

        for rule in defaults {
            rules[Self.key(drug: rule.drug ?? "", doseType: rule.doseType)] = rule
        }
    }

    // ── Helper ────────────────────────────────────────────────────────

    /// Deterministic cache key: "<drug>_<doseType>"
    private static func key(drug: String, doseType: String) -> String {
        "\(drug)_\(doseType)"
    }
}
