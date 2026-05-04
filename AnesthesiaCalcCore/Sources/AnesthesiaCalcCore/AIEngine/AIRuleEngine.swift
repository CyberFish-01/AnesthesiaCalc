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
    case antagonism  = "antagonism"   // 拮抗（特异性逆转）

    /// Short Chinese label for use in segmented pickers and compact UI.
    public var displayName: String {
        switch self {
        case .induction:   return "诱导"
        case .intubation:  return "插管"
        case .maintenance: return "维持"
        case .sedation:    return "镇静"
        case .analgesia:   return "镇痛"
        case .antagonism:  return "拮抗"
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
    /// (e.g. Propofol 1 % = 10 mg/mL; Fentanyl 50 μg/mL = 0.05 mg/mL)
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

    /// True when this rule describes a continuous infusion (per-hour or per-minute)
    /// rather than a single bolus injection.
    /// Note: `unit` stores only the mass unit ("mg"/"mcg"); the time basis lives in
    /// `doseInterval`, so that is the authoritative infusion check.
    public var isInfusion: Bool {
        doseInterval == .perHour || doseInterval == .perMinute
    }

    public init(
        drug: String?,
        doseType: String,
        minMultiplier: Double,
        maxMultiplier: Double,
        weightBase: WeightBase,
        unit: String,
        concentrationMgPerMl: Double,
        absoluteMaxDose: Double? = nil,
        ageAdjustments: [AgeAdjustment]? = nil,
        doseInterval: DoseInterval = .bolus,
        note: String? = nil
    ) {
        precondition(concentrationMgPerMl > 0, "concentrationMgPerMl must be > 0 (got \(concentrationMgPerMl))")
        precondition(minMultiplier > 0, "minMultiplier must be > 0 (got \(minMultiplier))")
        precondition(maxMultiplier >= minMultiplier, "maxMultiplier must be >= minMultiplier")
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

    /// Primary keys — camelCase, matching what the system prompt instructs the AI to return.
    private enum CodingKeys: String, CodingKey {
        case drug
        case doseType
        case minMultiplier
        case maxMultiplier
        case weightBase
        case unit
        case concentrationMgPerMl   // camelCase form
        case absoluteMaxDose
        case ageAdjustments
        case doseInterval
        case note
    }

    /// Fallback keys — snake_case variants for models that ignore the camelCase
    /// instruction in the system prompt (e.g. some open-source LLMs).
    private enum SnakeCodingKeys: String, CodingKey {
        case concentrationMgPerMl = "concentration_mg_per_ml"
        case doseType             = "dose_type"
        case minMultiplier        = "min_multiplier"
        case maxMultiplier        = "max_multiplier"
        case weightBase           = "weight_base"
        case absoluteMaxDose      = "absolute_max_dose"
        case ageAdjustments       = "age_adjustments"
        case doseInterval         = "dose_interval"
    }

    public init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        let cs = try decoder.container(keyedBy: SnakeCodingKeys.self)

        drug = try c.decodeIfPresent(String.self, forKey: .drug)

        // Required fields: try camelCase first, fall back to snake_case.
        doseType = try c.decodeIfPresent(String.self, forKey: .doseType)
            ?? (try cs.decodeIfPresent(String.self, forKey: .doseType))
            ?? { throw DecodingError.keyNotFound(CodingKeys.doseType,
                   .init(codingPath: decoder.codingPath,
                         debugDescription: "Missing 'doseType' or 'dose_type'")) }()

        minMultiplier = try c.decodeIfPresent(Double.self, forKey: .minMultiplier)
            ?? (try cs.decodeIfPresent(Double.self, forKey: .minMultiplier))
            ?? { throw DecodingError.keyNotFound(CodingKeys.minMultiplier,
                   .init(codingPath: decoder.codingPath,
                         debugDescription: "Missing 'minMultiplier' or 'min_multiplier'")) }()

        maxMultiplier = try c.decodeIfPresent(Double.self, forKey: .maxMultiplier)
            ?? (try cs.decodeIfPresent(Double.self, forKey: .maxMultiplier))
            ?? minMultiplier

        weightBase = try c.decodeIfPresent(WeightBase.self, forKey: .weightBase)
            ?? (try cs.decodeIfPresent(WeightBase.self, forKey: .weightBase))
            ?? { throw DecodingError.keyNotFound(CodingKeys.weightBase,
                   .init(codingPath: decoder.codingPath,
                         debugDescription: "Missing 'weightBase' or 'weight_base'")) }()

        unit = try c.decode(String.self, forKey: .unit)

        // concentrationMgPerMl: try camelCase, then explicit snake_case fallback.
        // Falls back to 0 (sentinel) so AIAssistantService can back-fill from
        // drug.defaultConcentration when the AI omits this field.
        concentrationMgPerMl = try c.decodeIfPresent(Double.self, forKey: .concentrationMgPerMl)
            ?? (try cs.decodeIfPresent(Double.self, forKey: .concentrationMgPerMl))
            ?? 0

        absoluteMaxDose = try c.decodeIfPresent(Double.self, forKey: .absoluteMaxDose)
            ?? (try cs.decodeIfPresent(Double.self, forKey: .absoluteMaxDose))

        ageAdjustments = try c.decodeIfPresent([AgeAdjustment].self, forKey: .ageAdjustments)
            ?? (try cs.decodeIfPresent([AgeAdjustment].self, forKey: .ageAdjustments))

        doseInterval = try c.decodeIfPresent(DoseInterval.self, forKey: .doseInterval)
            ?? (try cs.decodeIfPresent(DoseInterval.self, forKey: .doseInterval))
            ?? .bolus

        note = try c.decodeIfPresent(String.self, forKey: .note)
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
            // 丙泊酚 (Propofol) — 镇静催眠药
            // Ref: Miller's Anesthesia 9th Ed., Ch.30 / CSA TIVA 指南 2024
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "丙泊酚", doseType: DoseType.induction.rawValue,
                minMultiplier: 1.5, maxMultiplier: 2.5, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 10.0,
                absoluteMaxDose: 300.0,
                ageAdjustments: [AgeAdjustment(ageThreshold: 65, scalingFactor: 0.7)],
                doseInterval: .bolus
            ),
            DosageRule(
                drug: "丙泊酚", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 4.0, maxMultiplier: 12.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 10.0,
                doseInterval: .perHour,
                note: "TCI 血浆靶浓度 3~6 μg/mL (复合阿片类 2~4 μg/mL)"
            ),
            DosageRule(
                drug: "丙泊酚", doseType: DoseType.sedation.rawValue,
                minMultiplier: 0.5, maxMultiplier: 4.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 10.0,
                doseInterval: .perHour,
                note: "ICU 镇静 0.5~4 mg/kg/h; 术中唤醒 0.8~1.0 mg/kg/h"
            ),

            // ══════════════════════════════════════════════════════════════
            // 依托咪酯 (Etomidate) — 镇静催眠药
            // Ref: CSA TIVA 指南 2024 / Miller 9th Ed., Ch.30
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "依托咪酯", doseType: DoseType.induction.rawValue,
                minMultiplier: 0.2, maxMultiplier: 0.6, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 2.0,
                absoluteMaxDose: 60.0,
                ageAdjustments: [AgeAdjustment(ageThreshold: 65, scalingFactor: 0.7)],
                doseInterval: .bolus,
                note: "血流动力学稳定，适合老年/心血管高危患者；单次抑制肾上腺皮质"
            ),
            DosageRule(
                drug: "依托咪酯", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 5, maxMultiplier: 20, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 2.0,
                doseInterval: .perMinute,
                note: "不推荐长时间输注（肾上腺皮质抑制）"
            ),

            // ══════════════════════════════════════════════════════════════
            // 环泊酚 (Ciprofol) — 镇静催眠药
            // Ref: CSA TIVA 指南 2024; 上市时间短，临床数据积累中
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "环泊酚", doseType: DoseType.induction.rawValue,
                minMultiplier: 0.3, maxMultiplier: 0.5, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 2.5,
                absoluteMaxDose: 50.0,
                doseInterval: .bolus,
                note: "参考丙泊酚等效剂量 1/4~1/5; 注射痛少，低血压发生率较低"
            ),
            DosageRule(
                drug: "环泊酚", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 0.4, maxMultiplier: 2.4, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 2.5,
                doseInterval: .perHour,
                note: "起始 0.8 mg/kg/h，范围 0.4~2.4 mg/kg/h"
            ),

            // ══════════════════════════════════════════════════════════════
            // 右美托咪定 (Dexmedetomidine) — 镇静催眠药
            // Ref: Precedex PI / ESAIC 指南 / CSA TIVA 指南 2024
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "右美托咪定", doseType: DoseType.sedation.rawValue,
                minMultiplier: 0.5, maxMultiplier: 1.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.1,
                doseInterval: .bolus,
                note: "负荷量 iv >10 min; 可减少镇静药 1/3~1/2，减少阿片药 20~30%"
            ),
            DosageRule(
                drug: "右美托咪定", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 0.2, maxMultiplier: 0.7, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.1,
                doseInterval: .perHour,
                note: "⚠️ 单位 mcg/kg/h 非 mcg/kg/min; α₂激动剂，不保证意识消失"
            ),

            // ══════════════════════════════════════════════════════════════
            // 咪达唑仑 (Midazolam) — 镇静催眠药
            // Ref: Miller 9th Ed., Ch.30 / CSA TIVA 指南 2024
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "咪达唑仑", doseType: DoseType.sedation.rawValue,
                minMultiplier: 0.02, maxMultiplier: 0.05, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 1.0,
                absoluteMaxDose: 5.0,
                ageAdjustments: [AgeAdjustment(ageThreshold: 65, scalingFactor: 0.5)],
                doseInterval: .bolus,
                note: "可能增加老年患者术后谵妄风险; 不推荐持续输注"
            ),

            // ══════════════════════════════════════════════════════════════
            // 舒芬太尼 (Sufentanil) — 阿片类镇痛药
            // Ref: CSA TIVA 指南 2024 / Miller 9th Ed., Ch.31
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "舒芬太尼", doseType: DoseType.induction.rawValue,
                minMultiplier: 0.3, maxMultiplier: 0.5, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.05,
                absoluteMaxDose: 50.0,
                doseInterval: .bolus,
                note: "TCI 血浆靶浓度 0.6 ng/ml 有效抑制插管反应"
            ),
            DosageRule(
                drug: "舒芬太尼", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 0.25, maxMultiplier: 1.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.05,
                doseInterval: .perHour,
                note: "TCI 0.3 ng/ml; 时-量相关半衰期 33.9 min (输注4h后)"
            ),
            DosageRule(
                drug: "舒芬太尼", doseType: DoseType.analgesia.rawValue,
                minMultiplier: 0.1, maxMultiplier: 0.3, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.05,
                doseInterval: .bolus,
                note: "术后镇痛间断推注"
            ),

            // ══════════════════════════════════════════════════════════════
            // 阿芬太尼 (Alfentanil) — 阿片类镇痛药
            // Ref: CSA TIVA 指南 2024 / Miller 9th Ed., Ch.31
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "阿芬太尼", doseType: DoseType.induction.rawValue,
                minMultiplier: 25, maxMultiplier: 50, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.5,
                doseInterval: .bolus,
                note: "TCI 血浆靶浓度 100~150 ng/ml; 起效快于芬太尼"
            ),
            DosageRule(
                drug: "阿芬太尼", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 30, maxMultiplier: 75, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.5,
                doseInterval: .perHour,
                note: "前30min 50~75 μg/kg/h，后 30~42.5 μg/kg/h; 时-量半衰期 58.2 min"
            ),

            // ══════════════════════════════════════════════════════════════
            // 吗啡 (Morphine) — 阿片类镇痛药
            // Ref: Miller 9th Ed., Ch.31 / WHO 镇痛阶梯
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "吗啡", doseType: DoseType.analgesia.rawValue,
                minMultiplier: 0.05, maxMultiplier: 0.2, weightBase: .idealBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 10.0,
                absoluteMaxDose: 15.0,
                ageAdjustments: [AgeAdjustment(ageThreshold: 65, scalingFactor: 0.5)],
                doseInterval: .bolus,
                note: "使用 IBW (肥胖患者避免过量); 呼吸抑制风险显著"
            ),

            // ══════════════════════════════════════════════════════════════
            // 羟考酮 (Oxycodone) — 阿片类镇痛药
            // Ref: ESAIC 指南 / Miller 9th Ed.
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "羟考酮", doseType: DoseType.analgesia.rawValue,
                minMultiplier: 0.05, maxMultiplier: 0.15, weightBase: .idealBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 10.0,
                absoluteMaxDose: 10.0,
                ageAdjustments: [AgeAdjustment(ageThreshold: 65, scalingFactor: 0.5)],
                doseInterval: .bolus,
                note: "使用 IBW; 口服等效比: 羟考酮≈1.5×吗啡"
            ),

            // ══════════════════════════════════════════════════════════════
            // 芬太尼 (Fentanyl) — 阿片类镇痛药
            // Ref: Miller 9th Ed. / CSA TIVA 指南 2024
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "芬太尼", doseType: DoseType.induction.rawValue,
                minMultiplier: 1.0, maxMultiplier: 3.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.05,
                absoluteMaxDose: 200.0,
                ageAdjustments: [AgeAdjustment(ageThreshold: 65, scalingFactor: 0.5)],
                doseInterval: .bolus,
                note: "不推荐持续输注(时-量半衰期 262.5 min); 推荐间断给药"
            ),
            DosageRule(
                drug: "芬太尼", doseType: DoseType.analgesia.rawValue,
                minMultiplier: 0.5, maxMultiplier: 1.5, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.05,
                doseInterval: .bolus
            ),

            // ══════════════════════════════════════════════════════════════
            // 瑞芬太尼 (Remifentanil) — 阿片类镇痛药
            // Ref: Ultiva PI / CSA TIVA 指南 2024
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "瑞芬太尼", doseType: DoseType.induction.rawValue,
                minMultiplier: 0.5, maxMultiplier: 1.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.05,
                absoluteMaxDose: 100.0,
                doseInterval: .bolus,
                note: "iv 30~60s; 复合丙泊酚时可减量"
            ),
            DosageRule(
                drug: "瑞芬太尼", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 0.1, maxMultiplier: 0.5, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.05,
                doseInterval: .perMinute,
                note: "TCI 2~4 ng/ml; CSHT 3~5 min 无蓄积; 停药前需衔接术后镇痛"
            ),
            DosageRule(
                drug: "瑞芬太尼", doseType: DoseType.analgesia.rawValue,
                minMultiplier: 0.05, maxMultiplier: 0.2, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.05,
                doseInterval: .perMinute,
                note: "术后/ICU 0.05~0.2 μg/kg/min; 唤醒麻醉降至 0.01~0.025"
            ),

            // ══════════════════════════════════════════════════════════════
            // 罗库溴铵 (Rocuronium) — 神经肌肉阻滞药
            // Ref: ESAIC 指南 / Esmeron SmPC
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "罗库溴铵", doseType: DoseType.intubation.rawValue,
                minMultiplier: 0.6, maxMultiplier: 1.2, weightBase: .idealBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 10.0,
                absoluteMaxDose: 120.0,
                doseInterval: .bolus,
                note: "标准插管 0.6 mg/kg IBW; RSI 1.2 mg/kg~60s 起效; 肥胖用 IBW"
            ),
            DosageRule(
                drug: "罗库溴铵", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 4, maxMultiplier: 16, weightBase: .idealBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 10.0,
                doseInterval: .perMinute,
                note: "9~12 μg/kg/min IBW; 吸入麻醉药增强肌松效应→减量30~50%"
            ),

            // ══════════════════════════════════════════════════════════════
            // 顺式阿曲库铵 (Cisatracurium) — 神经肌肉阻滞药
            // Ref: ESAIC 指南 / Miller 9th Ed. / CSA TIVA 指南 2024
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "顺式阿曲库铵", doseType: DoseType.intubation.rawValue,
                minMultiplier: 0.15, maxMultiplier: 0.2, weightBase: .idealBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 2.0,
                absoluteMaxDose: 20.0,
                doseInterval: .bolus,
                note: "使用 IBW (肥胖患者); Hofmann 消除不依赖肝肾"
            ),
            DosageRule(
                drug: "顺式阿曲库铵", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 1, maxMultiplier: 2, weightBase: .idealBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 2.0,
                doseInterval: .perMinute,
                note: "1~2 μg/kg/min IBW; TOF 监测引导"
            ),

            // ══════════════════════════════════════════════════════════════
            // 米库氯铵 (Mivacurium) — 神经肌肉阻滞药
            // Ref: Miller 9th Ed. / FDA PI
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "米库氯铵", doseType: DoseType.intubation.rawValue,
                minMultiplier: 0.15, maxMultiplier: 0.25, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 2.0,
                doseInterval: .bolus,
                note: "血浆假性胆碱酯酶水解; 临床时效 15~20 min (短效)"
            ),
            DosageRule(
                drug: "米库氯铵", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 5, maxMultiplier: 15, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 2.0,
                doseInterval: .perMinute,
                note: "持续输注 5~15 μg/kg/min; 无蓄积"
            ),

            // ══════════════════════════════════════════════════════════════
            // 舒更葡萄糖钠 (Sugammadex) — 特异性肌松拮抗剂
            // Ref: ESAIC 指南 / Bridion SmPC
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "舒更葡萄糖钠", doseType: DoseType.antagonism.rawValue,
                minMultiplier: 2.0, maxMultiplier: 2.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 100.0,
                doseInterval: .bolus,
                note: "中度肌松逆转 (T2重现): 2 mg/kg 实际体重"
            ),
            DosageRule(
                drug: "舒更葡萄糖钠", doseType: DoseType.sedation.rawValue,
                minMultiplier: 4.0, maxMultiplier: 4.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 100.0,
                doseInterval: .bolus,
                note: "深度肌松逆转 (PTC 1~2, 无 TOF): 4 mg/kg (doseType 复用 sedation 存储)"
            ),
            DosageRule(
                drug: "舒更葡萄糖钠", doseType: DoseType.induction.rawValue,
                minMultiplier: 16.0, maxMultiplier: 16.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 100.0,
                doseInterval: .bolus,
                note: "紧急逆转 (罗库溴铵 1.2 mg/kg 后3min): 16 mg/kg (doseType 复用 induction 存储)"
            ),

            // ══════════════════════════════════════════════════════════════
            // 氟马西尼 (Flumazenil) — 特异性拮抗剂
            // Ref: Romazicon PI (FDA) / StatPearls 2024
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "氟马西尼", doseType: DoseType.antagonism.rawValue,
                minMultiplier: 0.003, maxMultiplier: 0.003, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 0.1,
                absoluteMaxDose: 1.0,
                doseInterval: .bolus,
                note: "~0.2 mg/70kg; q1min 重复至 max 1 mg; 癫痫风险(长期BZD使用者)"
            ),

            // ══════════════════════════════════════════════════════════════
            // 纳美芬 (Nalmefene) — 特异性拮抗剂
            // Ref: Opvee/Zurnai PI (FDA 2023/2024)
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "纳美芬", doseType: DoseType.antagonism.rawValue,
                minMultiplier: 0.1, maxMultiplier: 0.25, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 0.1,
                absoluteMaxDose: 1.0,
                doseInterval: .bolus,
                note: "术后阿片逆转 0.25 μg/kg q2~5min; max 1 μg/kg; t₁/₂ 11h 长效"
            ),

            // ══════════════════════════════════════════════════════════════
            // 去甲肾上腺素 (Norepinephrine) — 血管活性药
            // Ref: α₁激动剂围术期应用专家共识 2017 / SCCM 指南
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "去甲肾上腺素", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 0.02, maxMultiplier: 0.1, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 2.0,
                doseInterval: .perMinute,
                note: "强效 α₁ + 中等 β₁; 心率偏慢时优选; 配制: kg×0.03mg→50mL → 1mL/h=0.01μg/kg/min"
            ),

            // ══════════════════════════════════════════════════════════════
            // 肾上腺素 (Epinephrine) — 血管活性药
            // Ref: ACLS 指南 2023 / Miller 9th Ed.
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "肾上腺素", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 0.01, maxMultiplier: 0.15, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 1.0,
                doseInterval: .perMinute,
                note: "低剂量 β 为主; 中高剂量 α 为主; >0.1 μg/kg/min α 占优"
            ),
            DosageRule(
                drug: "肾上腺素", doseType: DoseType.induction.rawValue,
                minMultiplier: 0.05, maxMultiplier: 1.5, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 1.0,
                doseInterval: .bolus,
                note: "低血压推注 5~100 μg; 心脏骤停 0.5~1 mg (doseType 复用 induction)"
            ),

            // ══════════════════════════════════════════════════════════════
            // 多巴胺 (Dopamine) — 血管活性药
            // Ref: Miller 9th Ed. / SCCM 指南
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "多巴胺", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 2, maxMultiplier: 20, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 10.0,
                doseInterval: .perMinute,
                note: "2~10 β为主 (正性肌力); 10~20 α为主 (升压); <2 D₁ 受体 (肾剂量)"
            ),

            // ══════════════════════════════════════════════════════════════
            // 麻黄碱 (Ephedrine) — 血管活性药
            // Ref: α₁激动剂专家共识 2017 / Miller 9th Ed.
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "麻黄碱", doseType: DoseType.induction.rawValue,
                minMultiplier: 0.07, maxMultiplier: 0.15, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 3.0,
                absoluteMaxDose: 25.0,
                doseInterval: .bolus,
                note: "≈5~10 mg/70kg; α+β 间接激动; 反复使用快速耐受; 不推荐持续输注 (doseType 复用 induction)"
            ),

            // ══════════════════════════════════════════════════════════════
            // 艾司洛尔 (Esmolol) — 心血管药物
            // Ref: Brevibloc PI (FDA) / Miller 9th Ed.
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "艾司洛尔", doseType: DoseType.induction.rawValue,
                minMultiplier: 0.5, maxMultiplier: 1.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 10.0,
                doseInterval: .bolus,
                note: "iv >60s; 可减少丙泊酚诱导剂量约18.5% (doseType 复用 induction)"
            ),
            DosageRule(
                drug: "艾司洛尔", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 50, maxMultiplier: 300, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 10.0,
                doseInterval: .perMinute,
                note: "超短效 β₁ 阻滞剂; t₁/₂ 9 min; 术中降压 150~300 μg/kg/min"
            ),

            // ══════════════════════════════════════════════════════════════
            // 硝酸甘油 (Nitroglycerin) — 心血管药物
            // Ref: FDA PI / Miller 9th Ed.
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "硝酸甘油", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 0.3, maxMultiplier: 5.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mcg.rawValue, concentrationMgPerMl: 5.0,
                doseInterval: .perMinute,
                note: "静脉扩张为主; 起始 0.25~0.5 μg/kg/min; >24h 连续输注可产生耐受"
            ),

            // ══════════════════════════════════════════════════════════════
            // 艾司氯胺酮 (Esketamine) — 抢救用药
            // Ref: CSA TIVA 指南 2024 / Miller 9th Ed.
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "艾司氯胺酮", doseType: DoseType.analgesia.rawValue,
                minMultiplier: 0.1, maxMultiplier: 0.5, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 25.0,
                doseInterval: .bolus,
                note: "亚麻醉剂量 0.1~0.5 mg/kg; 兼具镇痛+交感兴奋; 对呼吸影响轻"
            ),
            DosageRule(
                drug: "艾司氯胺酮", doseType: DoseType.induction.rawValue,
                minMultiplier: 1.0, maxMultiplier: 2.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 25.0,
                absoluteMaxDose: 150.0,
                doseInterval: .bolus,
                note: "全麻诱导可至 1~2 mg/kg; 支气管扩张; 注意精神症状"
            ),

            // ══════════════════════════════════════════════════════════════
            // 罗哌卡因 (Ropivacaine) — 局部麻醉药
            // Ref: ASRA 指南 / Miller 9th Ed. / FDA PI
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "罗哌卡因", doseType: DoseType.analgesia.rawValue,
                minMultiplier: 2.0, maxMultiplier: 3.0, weightBase: .idealBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 7.5,
                absoluteMaxDose: 200.0,
                doseInterval: .bolus,
                note: "单次极量 200 mg (或 3 mg/kg IBW); 肥胖用 IBW; 心脏毒性低于布比卡因"
            ),

            // ══════════════════════════════════════════════════════════════
            // 氨甲环酸 (Tranexamic Acid) — 抗纤溶止血药
            // Ref: ESAIC 指南 / WHO 创伤指南 / CRASH-2
            // ══════════════════════════════════════════════════════════════

            DosageRule(
                drug: "氨甲环酸", doseType: DoseType.induction.rawValue,
                minMultiplier: 10.0, maxMultiplier: 15.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 100.0,
                absoluteMaxDose: 2000.0,
                doseInterval: .bolus,
                note: "负荷量 10~15 mg/kg iv >10min (手术预防/创伤); max 2g (doseType 复用 induction)"
            ),
            DosageRule(
                drug: "氨甲环酸", doseType: DoseType.maintenance.rawValue,
                minMultiplier: 1.0, maxMultiplier: 5.0, weightBase: .totalBodyWeight,
                unit: DoseUnit.mg.rawValue, concentrationMgPerMl: 100.0,
                doseInterval: .perHour,
                note: "维持输注 1~5 mg/kg/h (如心脏手术/骨科大手术)"
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
