import Foundation

// MARK: - RuleSource

/// Indicates which set of dosing rules is currently active for a drug.
public enum RuleSource: String, Codable, CaseIterable {
    case ai     = "AI 智能生成"
    case manual = "手动经验添加"
}

// MARK: - AnesthesiaDrug

/// A drug that can be registered with `DrugManager` and used in dose calculations.
///
/// Each drug now carries two independent rule sets — `aiRules` (AI-generated)
/// and `manualRules` (clinician-entered) — plus an `activeRuleSource` switch that
/// controls which set drives the calculator on the main screen.
public struct AnesthesiaDrug: Identifiable, Codable {

    /// Stable identifier — never changes, even when other properties are edited.
    public let id: UUID

    /// Short Chinese name. Also serves as the lookup key in `AIRuleEngine`.
    public var name: String

    /// Default commercial preparation concentration in `concentrationUnit`.
    public var defaultConcentration: Double

    /// Unit of `defaultConcentration`, e.g. "mg/mL".
    public var concentrationUnit: String

    /// Rules populated by the AI assistant (via `AIAssistantService`).
    public var aiRules: [DosageRule]

    /// Rules entered manually by the clinician.
    public var manualRules: [DosageRule]

    /// Controls which rule set drives the main-screen calculator.
    public var activeRuleSource: RuleSource

    /// The currently active rule set — used by `DrugCalculator`.
    public var activeRules: [DosageRule] {
        switch activeRuleSource {
        case .ai:     return aiRules
        case .manual: return manualRules
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        defaultConcentration: Double,
        concentrationUnit: String,
        aiRules: [DosageRule] = [],
        manualRules: [DosageRule] = [],
        activeRuleSource: RuleSource = .ai
    ) {
        self.id                   = id
        self.name                 = name
        self.defaultConcentration = defaultConcentration
        self.concentrationUnit    = concentrationUnit
        self.aiRules              = aiRules
        self.manualRules          = manualRules
        self.activeRuleSource     = activeRuleSource
    }

    /// Full display name — currently identical to `name`.
    public var displayName: String { name }

    /// Compact name for table cells and pickers — currently identical to `name`.
    public var shortName: String { name }

    // MARK: Codable

    // `id` is excluded from AI-JSON decoding (AI does not supply it).
    // New fields default gracefully so legacy JSON without them still decodes.
    private enum CodingKeys: String, CodingKey {
        case name
        case defaultConcentration
        case concentrationUnit
        case aiRules
        case manualRules
        case activeRuleSource
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = UUID()
        name                 = try c.decode(String.self,  forKey: .name)
        defaultConcentration = try c.decode(Double.self,  forKey: .defaultConcentration)
        concentrationUnit    = try c.decode(String.self,  forKey: .concentrationUnit)
        aiRules              = try c.decodeIfPresent([DosageRule].self, forKey: .aiRules) ?? []
        manualRules          = try c.decodeIfPresent([DosageRule].self, forKey: .manualRules) ?? []
        activeRuleSource     = try c.decodeIfPresent(RuleSource.self,   forKey: .activeRuleSource) ?? .ai
    }
}

// MARK: — Hashable / Equatable — identity is id only

extension AnesthesiaDrug: Hashable {
    public static func == (lhs: AnesthesiaDrug, rhs: AnesthesiaDrug) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: — Built-in drugs

public extension AnesthesiaDrug {

    /// 丙泊酚 (Propofol) — 1 % emulsion, 10 mg/mL
    static let propofol = AnesthesiaDrug(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "丙泊酚",
        defaultConcentration: 10.0,
        concentrationUnit: "mg/mL"
    )

    /// 罗库溴铵 (Rocuronium) — 10 mg/mL
    static let rocuronium = AnesthesiaDrug(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "罗库溴铵",
        defaultConcentration: 10.0,
        concentrationUnit: "mg/mL"
    )

    /// 芬太尼 (Fentanyl) — 50 mcg/mL = 0.05 mg/mL
    static let fentanyl = AnesthesiaDrug(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "芬太尼",
        defaultConcentration: 0.05,
        concentrationUnit: "mg/mL"
    )

    /// 瑞芬太尼 (Remifentanil) — 50 mcg/mL = 0.05 mg/mL
    static let remifentanil = AnesthesiaDrug(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "瑞芬太尼",
        defaultConcentration: 0.05,
        concentrationUnit: "mg/mL"
    )
}
