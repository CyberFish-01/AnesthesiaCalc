import Foundation

// MARK: - AcidBaseDisorder

public enum AcidBaseDisorder: String {
    case metabolicAcidosis    = "代酸"
    case metabolicAlkalosis   = "代碱"
    case respiratoryAcidosis  = "呼酸"
    case respiratoryAlkalosis = "呼碱"
    case mixedDisorder        = "混合性酸碱紊乱"
}

// MARK: - CompensationStatus

public enum CompensationStatus: String {
    case uncompensated    = "未代偿"
    case partial          = "部分代偿"
    case fullyCompensated = "完全代偿"
}

// MARK: - OxygenationStatus

public enum OxygenationStatus: String {
    case normal        = "正常"
    case mildHypoxemia = "轻度低氧"
    case moderate      = "中度低氧"
    case severeARDS    = "重度ARDS"
    case criticalARDS  = "极重度ARDS"
}

// MARK: - LactateRiskTier

public enum LactateRiskTier: String {
    case normal   = "正常"
    case mild     = "轻度升高"
    case moderate = "中度升高 (组织低灌注)"
    case severe   = "重度升高 (休克状态)"
}

// MARK: - ABGInput

public struct ABGInput: Equatable {
    public let pH: Double
    public let paCO2: Double
    public let paO2: Double
    public let hco3: Double
    public let baseExcess: Double
    public let lactate: Double?
    public let na: Double?
    public let cl: Double?
    public let fio2: Double
    public let barometricPressure: Double   // 默认 760 mmHg

    public init(
        pH: Double,
        paCO2: Double,
        paO2: Double,
        hco3: Double,
        baseExcess: Double,
        lactate: Double? = nil,
        na: Double? = nil,
        cl: Double? = nil,
        fio2: Double = 0.21,
        barometricPressure: Double = 760
    ) {
        self.pH = pH
        self.paCO2 = paCO2
        self.paO2 = paO2
        self.hco3 = hco3
        self.baseExcess = baseExcess
        self.lactate = lactate
        self.na = na
        self.cl = cl
        self.fio2 = fio2
        self.barometricPressure = barometricPressure
    }
}

// MARK: - ABGInterpretation

public struct ABGInterpretation: Equatable {
    public let primaryDisorder: AcidBaseDisorder
    public let compensation: CompensationStatus
    public let anionGap: Double?                      // nil 若未输入 Na/Cl
    public let deltaGap: Double?                      // nil 若未输入 Na/Cl 或 AG 正常
    public let aADO2: Double                          // 肺泡-动脉氧分压差
    public let paO2FiO2Ratio: Double
    public let oxygenationStatus: OxygenationStatus
    public let lactateRisk: LactateRiskTier?
    public let clinicalSuggestions: [String]
    public let formulaExplanation: String
}

// MARK: - ABGAnalyzer

/// 动脉血气分析器 — 酸碱判读 + 氧合评估 + 临床建议。
///
/// 遵循 Winter 公式、AG/ΔAG 计算、Berlin ARDS 定义。
public enum ABGAnalyzer {

    /// 分析血气结果
    public static func analyze(_ input: ABGInput) -> ABGInterpretation {
        // ── Step 1: 判定酸碱状态 ──────────────────────
        let isAcidemia = input.pH < 7.35
        let isAlkalemia = input.pH > 7.45

        // ── Step 2: 找原发 ──────────────────────────
        let primary: AcidBaseDisorder
        if isAcidemia {
            if input.paCO2 > 45 {
                primary = .respiratoryAcidosis
            } else if input.hco3 < 22 {
                primary = .metabolicAcidosis
            } else {
                primary = .metabolicAcidosis  // 默认，罕见情况
            }
        } else if isAlkalemia {
            if input.paCO2 < 35 {
                primary = .respiratoryAlkalosis
            } else {
                primary = .metabolicAlkalosis
            }
        } else {
            // pH 正常 — 可能完全代偿或混合紊乱
            if input.paCO2 > 45 && input.hco3 > 26 {
                primary = .respiratoryAcidosis
            } else if input.paCO2 < 35 && input.hco3 < 22 {
                primary = .respiratoryAlkalosis
            } else if input.hco3 < 22 {
                primary = .metabolicAcidosis
            } else if input.hco3 > 26 {
                primary = .metabolicAlkalosis
            } else {
                primary = .mixedDisorder
            }
        }

        // ── Step 3: 判断代偿 ─────────────────────────
        let compensation = assessCompensation(input: input, primary: primary)

        // ── Step 4: AG ───────────────────────────────
        let ag = calculateAG(na: input.na, cl: input.cl, hco3: input.hco3)
        var deltaGap: Double? = nil
        if let agVal = ag, agVal > 12, input.hco3 < 24 {
            let deltaAG = agVal - 12
            let deltaHCO3 = 24 - input.hco3
            if deltaHCO3 > 0 {
                deltaGap = deltaAG / deltaHCO3
            }
        }

        // ── Step 5: 氧合 ─────────────────────────────
        let pfRatio = input.paO2 / input.fio2
        let oxygenation: OxygenationStatus = {
            if pfRatio > 400 { return .normal }
            if pfRatio > 300 { return .mildHypoxemia }
            if pfRatio > 200 { return .moderate }
            if pfRatio > 100 { return .severeARDS }
            return .criticalARDS
        }()

        // ── A-aDO₂ ──────────────────────────────────
        let aado2 = calculateAADO2(input: input)

        // ── 乳酸 ─────────────────────────────────────
        let lactateRisk = input.lactate.map { lac -> LactateRiskTier in
            if lac < 2.0 { return .normal }
            if lac < 4.0 { return .mild }
            if lac < 8.0 { return .moderate }
            return .severe
        }

        // ── 临床建议 ──────────────────────────────────
        let suggestions = generateSuggestions(input: input, primary: primary, ag: ag, deltaGap: deltaGap, pfRatio: pfRatio, lactate: input.lactate, aado2: aado2)

        // ── 公式溯源 ──────────────────────────────────
        var formula = "pH=\(String(format: "%.2f", input.pH)) PaCO₂=\(String(format: "%.0f", input.paCO2)) HCO₃=\(String(format: "%.0f", input.hco3))"
        if let agVal = ag {
            formula += " AG=\(String(format: "%.0f", agVal))"
        }
        formula += " P/F=\(String(format: "%.0f", pfRatio)) A-aDO₂=\(String(format: "%.0f", aado2))"
        if let lac = input.lactate {
            formula += " Lac=\(String(format: "%.1f", lac))"
        }

        return ABGInterpretation(
            primaryDisorder: primary,
            compensation: compensation,
            anionGap: ag,
            deltaGap: deltaGap,
            aADO2: aado2,
            paO2FiO2Ratio: pfRatio,
            oxygenationStatus: oxygenation,
            lactateRisk: lactateRisk,
            clinicalSuggestions: suggestions,
            formulaExplanation: formula
        )
    }

    // MARK: - Private helpers

    private static func assessCompensation(input: ABGInput, primary: AcidBaseDisorder) -> CompensationStatus {
        switch primary {
        case .metabolicAcidosis:
            // Winter 公式：预期 PaCO₂ = 1.5×HCO₃ + 8 ± 2
            let expectedPaCO2 = 1.5 * input.hco3 + 8
            if input.pH < 7.35 && abs(input.paCO2 - expectedPaCO2) <= 3 {
                return .partial
            } else if input.pH >= 7.35 && abs(input.paCO2 - expectedPaCO2) <= 3 {
                return .fullyCompensated
            } else {
                return .uncompensated
            }
        case .metabolicAlkalosis:
            let expectedPaCO2 = 40 + 0.7 * (input.hco3 - 24)
            return judgeCompensation(actual: input.paCO2, expected: expectedPaCO2, tolerance: 3, pH: input.pH, primaryIsAcidosis: false)
        case .respiratoryAcidosis:
            // 急性：HCO₃ ↑1 per 10 PaCO₂↑; 这里取折中
            let expectedHCO3 = 24 + 3.0 * (input.paCO2 - 40) / 10
            return judgeCompensation(actual: input.hco3, expected: expectedHCO3, tolerance: 2, pH: input.pH, primaryIsAcidosis: true)
        case .respiratoryAlkalosis:
            let expectedHCO3 = 24 - 2.0 * (40 - input.paCO2) / 10
            return judgeCompensation(actual: input.hco3, expected: expectedHCO3, tolerance: 2, pH: input.pH, primaryIsAcidosis: false)
        case .mixedDisorder:
            return .uncompensated
        }
    }

    private static func judgeCompensation(actual: Double, expected: Double, tolerance: Double, pH: Double, primaryIsAcidosis: Bool) -> CompensationStatus {
        let inRange = abs(actual - expected) <= tolerance
        if inRange && ((primaryIsAcidosis && pH >= 7.35) || (!primaryIsAcidosis && pH <= 7.45)) {
            return .fullyCompensated
        } else if inRange {
            return .partial
        } else {
            return .uncompensated
        }
    }

    private static func calculateAG(na: Double?, cl: Double?, hco3: Double) -> Double? {
        guard let na = na, let cl = cl else { return nil }
        return na - cl - hco3
    }

    /// A-aDO₂ = (PB - 47) × FIO₂ - PaCO₂ / 0.8 - PaO₂
    private static func calculateAADO2(input: ABGInput) -> Double {
        let pbMinusWater = input.barometricPressure - 47
        return pbMinusWater * input.fio2 - input.paCO2 / 0.8 - input.paO2
    }

    // MARK: - 临床建议生成

    private static func generateSuggestions(
        input: ABGInput,
        primary: AcidBaseDisorder,
        ag: Double?,
        deltaGap: Double?,
        pfRatio: Double,
        lactate: Double?,
        aado2: Double
    ) -> [String] {
        var suggestions: [String] = []

        // 乳酸
        if let lac = lactate, lac > 2.0 {
            if lac >= 4.0 {
                suggestions.append("乳酸 \(String(format: "%.1f", lac)) mmol/L 升高，提示组织低灌注。建议：评估血容量+心输出量，考虑液体复苏或血管活性药；查 Hb 排除失血")
            } else {
                suggestions.append("乳酸 \(String(format: "%.1f", lac)) mmol/L 轻度升高，建议动态监测趋势")
            }
        }

        // AG
        if let agVal = ag, agVal > 12 {
            suggestions.append("AG=\(String(format: "%.0f", agVal)) (↑)，高AG代酸。排查尿酮体、乳酸、肾功能")
            if let dg = deltaGap {
                if dg < 1.0 {
                    suggestions.append("ΔAG/ΔHCO₃=\(String(format: "%.2f", dg)) (<1.0)，提示合并正常AG代酸(高氯性)，常见于大量NS输注。建议改用平衡晶体液")
                } else if dg > 2.0 {
                    suggestions.append("ΔAG/ΔHCO₃=\(String(format: "%.2f", dg)) (>2.0)，提示合并代谢性碱中毒")
                }
            }
        } else if ag == nil {
            suggestions.append("未输入 Na⁺/Cl⁻，AG 无法计算——建议补充以鉴别高AG vs 正常AG代酸")
        }

        // 呼酸
        if primary == .respiratoryAcidosis && input.pH < 7.25 {
            suggestions.append("严重呼吸性酸中毒 (pH<7.25)，建议：检查气管导管位置、气道压、ETCO₂ 波形；排除气胸/支气管痉挛；必要时增加分钟通气量")
        }

        // 代碱
        if primary == .metabolicAlkalosis {
            suggestions.append("代谢性碱中毒，注意电解质（低钾、低氯）。建议：查血钾、减少胃管引流、必要时乙酰唑胺")
        }

        // P/F
        if pfRatio < 200 {
            suggestions.append("P/F=\(String(format: "%.0f", pfRatio))，符合中重度ARDS (Berlin定义)。建议：肺保护通气 Vt 4-6 mL/kg IBW，PEEP 滴定 ≥5 cmH₂O")
            if pfRatio < 100 {
                suggestions.append("P/F<100 极重度ARDS，除肺保护通气外，重新评估是否需 ECMO 会诊")
            }
        } else if pfRatio < 300 {
            suggestions.append("P/F=\(String(format: "%.0f", pfRatio))，轻度低氧血症。排查肺不张、痰堵、液体超负荷")
        }

        // A-aDO₂
        if aado2 > 20 {
            if input.fio2 < 0.4 {
                suggestions.append("A-aDO₂=\(String(format: "%.0f", aado2)) mmHg (↑)，提示肺内分流或V/Q失调。如吸纯氧后纠正→V/Q失调；不纠正→真性分流")
            } else {
                suggestions.append("A-aDO₂=\(String(format: "%.0f", aado2)) mmHg，FiO₂较高时A-aDO₂升高可能为医源性，需结合P/F综合判断")
            }
        }

        // 拔管评估
        if input.fio2 <= 0.4 {
            if input.pH > 7.25 && pfRatio > 200 && input.paCO2 < 50 {
                suggestions.append("✅ 拔管评估：pH>7.25、P/F>200、PaCO₂<50 → 可考虑拔管")
            } else {
                suggestions.append("⚠️ 拔管评估：暂不满足拔管条件，建议30min后复查血气")
            }
        }

        if suggestions.isEmpty {
            suggestions.append("血气分析未见明显异常，继续当前管理方案")
        }

        return suggestions
    }
}
