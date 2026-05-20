import Foundation

// MARK: - EmergencyDrugStep

public struct EmergencyDrugStep: Equatable {
    public let drugName: String
    public let route: String
    public let calculatedDose: String
    public let rawInstruction: String
    public let note: String?

    public init(drugName: String, route: String, calculatedDose: String, rawInstruction: String, note: String? = nil) {
        self.drugName = drugName
        self.route = route
        self.calculatedDose = calculatedDose
        self.rawInstruction = rawInstruction
        self.note = note
    }
}

// MARK: - EmergencyProtocol

public struct EmergencyProtocol: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let recognition: [String]
    public let immediateActions: [String]
    public let drugSteps: [EmergencyDrugStep]
    public let escalation: [String]

    public init(id: String, name: String, recognition: [String], immediateActions: [String], drugSteps: [EmergencyDrugStep], escalation: [String]) {
        self.id = id
        self.name = name
        self.recognition = recognition
        self.immediateActions = immediateActions
        self.drugSteps = drugSteps
        self.escalation = escalation
    }
}

// MARK: - EmergencyProtocolEngine

/// 紧急预案引擎 — 基于当前患者体征预计算体重依赖的剂量。
///
/// 零网络依赖，全部预案在首次调用时加载到内存。
public enum EmergencyProtocolEngine {

    // MARK: - Public API

    /// 为给定患者生成全部预案（预计算所有体重依赖剂量）。
    public static func generateAll(for weightKg: Double) -> [EmergencyProtocol] {
        [
            cardiacArrest(weightKg: weightKg),
            anaphylaxis(weightKg: weightKg),
            malignantHyperthermia(weightKg: weightKg),
            last(weightKg: weightKg),
            massiveHemorrhage(weightKg: weightKg),
            highSpinal(weightKg: weightKg)
        ]
    }

    /// 按预案 ID 获取单条预案。
    public static func generate(for weightKg: Double, id: String) -> EmergencyProtocol? {
        generateAll(for: weightKg).first { $0.id == id }
    }

    // MARK: - 预案 1: 心脏骤停 (ACLS)

    private static func cardiacArrest(weightKg: Double) -> EmergencyProtocol {
        EmergencyProtocol(
            id: "cardiac_arrest",
            name: "心脏骤停 (ACLS)",
            recognition: [
                "意识丧失、无脉搏、无呼吸或濒死呼吸",
                "监护仪显示 VF/VT、无脉电活动(PEA) 或心搏停止",
                "ETCO₂ 骤降 (<10 mmHg)"
            ],
            immediateActions: [
                "立即开始胸外按压 (100-120次/分，深度 5-6cm)",
                "球囊面罩纯氧通气 (30:2)，尽快建立高级气道",
                "除颤器到位——可电击心律立即除颤 (双相 200J)"
            ],
            drugSteps: [
                EmergencyDrugStep(
                    drugName: "肾上腺素", route: "IV/IO",
                    calculatedDose: "1mg",
                    rawInstruction: "1mg IV/IO 每 3-5 min 重复",
                    note: "不可因建立静脉通路中断按压"
                ),
                EmergencyDrugStep(
                    drugName: "胺碘酮", route: "IV",
                    calculatedDose: "300mg",
                    rawInstruction: "VF/VT 无脉：首剂 300mg IV bolus，可追加 150mg",
                    note: "难治性 VF/VT 时使用"
                )
            ],
            escalation: [
                "5 轮 CPR 无 ROSC → 排查可逆病因 (5H5T)",
                "考虑 TEE 评估心脏活动",
                "ECPR (ECMO-CPR) 适应症评估"
            ]
        )
    }

    // MARK: - 预案 2: 过敏性休克

    private static func anaphylaxis(weightKg: Double) -> EmergencyProtocol {
        let epiMcg = min(weightKg * 1, 100)
        let methylpredMg = weightKg * 2
        return EmergencyProtocol(
            id: "anaphylaxis",
            name: "过敏性休克",
            recognition: [
                "给药后数分钟内出现皮肤潮红/荨麻疹/血管性水肿",
                "气道压骤升（支气管痉挛）、SpO₂ 下降",
                "心率增快+血压骤降 (MAP<60)，甚至循环崩溃"
            ],
            immediateActions: [
                "立即停止可疑药物输注",
                "纯氧吸入，必要时气管插管（警惕气道水肿）",
                "抬高下肢，快速输注晶体液 500-1000mL"
            ],
            drugSteps: [
                EmergencyDrugStep(
                    drugName: "肾上腺素", route: "IV",
                    calculatedDose: "\(String(format: "%.0f", epiMcg)) μg",
                    rawInstruction: "10-100μg IV bolus，按反应每 1-2 min 重复",
                    note: "稀释至 10 mL (10 μg/mL)，慢推"
                ),
                EmergencyDrugStep(
                    drugName: "肾上腺素", route: "IM",
                    calculatedDose: "0.5mg",
                    rawInstruction: "0.3-0.5mg IM (大腿外侧)，每 5-15 min 可重复",
                    note: "循环未崩溃时 IM 首选"
                ),
                EmergencyDrugStep(
                    drugName: "甲强龙", route: "IV",
                    calculatedDose: "\(String(format: "%.0f", methylpredMg)) mg",
                    rawInstruction: "1-2 mg/kg IV",
                    note: "起效需 4-6h，用于预防双相反应"
                )
            ],
            escalation: [
                "肾上腺素无效 → 肾上腺素持续输注 2-10 μg/min",
                "严重支气管痉挛 → 沙丁胺醇雾化 + 氨茶碱",
                "仍低血压 → 启动 MTP 排除失血性休克"
            ]
        )
    }

    // MARK: - 预案 3: 恶性高热

    private static func malignantHyperthermia(weightKg: Double) -> EmergencyProtocol {
        let dantroleneMg = weightKg * 2.5
        return EmergencyProtocol(
            id: "malignant_hyperthermia",
            name: "恶性高热",
            recognition: [
                "ETCO₂ 急剧升高（最早且最敏感征象），PaCO₂ > 60",
                "咬肌痉挛（尤其是琥珀胆碱后）、全身肌肉强直",
                "体温骤升 (每 5min ↑1-2°C)，可 >40°C",
                "心动过速、酸中毒 (pH↓)、高钾血症"
            ],
            immediateActions: [
                "立即停用吸入麻醉药和琥珀胆碱",
                "纯氧高流量通气 (>10 L/min)，更换呼吸回路和钠石灰",
                "呼叫帮助——需要 4-6 人团队"
            ],
            drugSteps: [
                EmergencyDrugStep(
                    drugName: "丹曲林", route: "IV",
                    calculatedDose: "\(String(format: "%.0f", dantroleneMg)) mg",
                    rawInstruction: "2.5 mg/kg IV 快速推注，每 5-10 min 重复至症状消退或达 10 mg/kg",
                    note: "每瓶 20mg 用 60mL 灭菌注射用水溶解 (不可用 NS)；此体重需约 \(String(format: "%.0f", ceil(dantroleneMg / 20))) 瓶"
                )
            ],
            escalation: [
                "丹曲林无效 → 继续重复给药至 10mg/kg 总剂量",
                "高钾血症 → 葡萄糖酸钙 + 胰岛素+葡萄糖 + 碳酸氢钠",
                "体温 >39°C → 体表冰敷 + 冷 NS 静脉输注 + 胃/膀胱冷灌洗",
                "尿液变黑/肌红蛋白尿 → 加强利尿，维持尿量 >2 mL/kg/h"
            ]
        )
    }

    // MARK: - 预案 4: 局麻药中毒 (LAST)

    private static func last(weightKg: Double) -> EmergencyProtocol {
        let bolusMl = weightKg * 1.5
        let infusionMlPerMin = weightKg * 0.25
        return EmergencyProtocol(
            id: "last",
            name: "局麻药全身毒性 (LAST)",
            recognition: [
                "给药后 1-5 min 内出现口周麻木、金属味、耳鸣",
                "进展为惊厥、意识丧失",
                "心血管崩溃：严重心动过缓/心脏停搏，对常规复苏无反应"
            ],
            immediateActions: [
                "立即停止局麻药注射/输注",
                "纯氧通气，必要时气管插管",
                "如发生惊厥：苯二氮卓类 (咪达唑仑 0.05-0.1 mg/kg IV)"
            ],
            drugSteps: [
                EmergencyDrugStep(
                    drugName: "20% 脂肪乳", route: "IV",
                    calculatedDose: "\(String(format: "%.0f", bolusMl)) mL bolus",
                    rawInstruction: "1.5 mL/kg IV bolus over 1 min",
                    note: "可重复 bolus 1-2 次"
                ),
                EmergencyDrugStep(
                    drugName: "20% 脂肪乳", route: "IV 输注",
                    calculatedDose: "\(String(format: "%.1f", infusionMlPerMin)) mL/min",
                    rawInstruction: "0.25 mL/kg/min 持续输注",
                    note: "循环稳定后继续输注至少 10 min"
                ),
                EmergencyDrugStep(
                    drugName: "肾上腺素", route: "IV",
                    calculatedDose: "≤1 μg/kg",
                    rawInstruction: "如需血管活性药，肾上腺素剂量 ≤1 μg/kg",
                    note: "大剂量肾上腺素会阻碍脂肪乳疗效"
                )
            ],
            escalation: [
                "脂肪乳 bolus 可重复至总量 3 mL/kg",
                "输注速率可加倍至 0.5 mL/kg/min 如循环不稳定",
                "最大脂肪乳总量：12 mL/kg",
                "心肺复苏 >60 min → 考虑 CPB/ECMO"
            ]
        )
    }

    // MARK: - 预案 5: 大出血 MTP

    private static func massiveHemorrhage(weightKg: Double) -> EmergencyProtocol {
        // EBV 估计
        let ebv = weightKg * 70  // 近似成人血容量
        return EmergencyProtocol(
            id: "massive_hemorrhage",
            name: "大出血 (MTP)",
            recognition: [
                "24h 内失血 > 全身血容量 (约 \(String(format: "%.0f", ebv)) mL)",
                "或 3h 内失血 > 血容量 50%",
                "或活动性出血 > 150 mL/min",
                "伴血流动力学不稳定 (HR↑、BP↓、Lac↑)"
            ],
            immediateActions: [
                "启动大量输血预案 (MTP)，立即通知输血科",
                "开放 ≥2 条大口径静脉通路 (≥16G) + 中心静脉",
                "积极液体复苏，目标 MAP≥65、Hb 70-90 g/L"
            ],
            drugSteps: [
                EmergencyDrugStep(
                    drugName: "RBC", route: "IV",
                    calculatedDose: "按需",
                    rawInstruction: "维持 Hb 70-90 g/L (神外/脑外伤 ≥90)",
                    note: "每单位 RBC 约提升 Hb 10 g/L"
                ),
                EmergencyDrugStep(
                    drugName: "FFP", route: "IV",
                    calculatedDose: "\(String(format: "%.0f", weightKg * 15)) mL",
                    rawInstruction: "10-15 mL/kg; 目标 PT/INR <1.5×正常",
                    note: "MTP 方案：RBC:FFP:PLT = 1:1:1"
                ),
                EmergencyDrugStep(
                    drugName: "氨甲环酸", route: "IV",
                    calculatedDose: "1g",
                    rawInstruction: "负荷量 1g (>10min)，继以 1g/8h 输注",
                    note: "创伤 3h 内使用最有效"
                ),
                EmergencyDrugStep(
                    drugName: "钙剂", route: "IV",
                    calculatedDose: "10mL 10% 葡萄糖酸钙",
                    rawInstruction: "每输注 4U 血制品补钙 10mL",
                    note: "枸橼酸中毒导致低钙 → 凝血障碍加重"
                )
            ],
            escalation: [
                "常规复苏无效 → 损伤控制外科手术",
                "Fib <1.0 g/L → 冷沉淀/纤维蛋白原浓缩物",
                "PLT <50×10⁹/L → 输注血小板 1 治疗量",
                "顽固性休克 → REBOA / 血管栓塞"
            ]
        )
    }

    // MARK: - 预案 6: 高平面/全脊麻

    private static func highSpinal(weightKg: Double) -> EmergencyProtocol {
        EmergencyProtocol(
            id: "high_spinal",
            name: "高平面/全脊麻",
            recognition: [
                "椎管内麻醉后出现上肢麻木、呼吸困难、发声困难",
                "进行性低血压、心动过缓",
                "意识水平下降，甚至呼吸停止、心跳骤停"
            ],
            immediateActions: [
                "立即停止椎管内给药",
                "纯氧面罩通气，如呼吸停止立即气管插管",
                "头低脚高位 + 左倾 (减轻腔静脉压迫)"
            ],
            drugSteps: [
                EmergencyDrugStep(
                    drugName: "麻黄碱", route: "IV",
                    calculatedDose: "6-10mg",
                    rawInstruction: "6-10mg IV bolus，按血压反应可重复",
                    note: "心率<50 时优先麻黄碱而非去氧肾上腺素"
                ),
                EmergencyDrugStep(
                    drugName: "去氧肾上腺素", route: "IV",
                    calculatedDose: "50-100μg",
                    rawInstruction: "50-100μg IV bolus 每 1-2 min",
                    note: "备选：麻黄碱无效时使用"
                ),
                EmergencyDrugStep(
                    drugName: "阿托品", route: "IV",
                    calculatedDose: "0.5mg",
                    rawInstruction: "严重心动过缓 (<40bpm) 时 0.5mg IV，可重复至 3mg",
                    note: ""
                ),
                EmergencyDrugStep(
                    drugName: "肾上腺素", route: "IV",
                    calculatedDose: "10-100μg",
                    rawInstruction: "上述措施无效时肾上腺素 10-100μg IV",
                    note: "准备肾上腺素输注 0.05-0.1 μg/kg/min"
                )
            ],
            escalation: [
                "血压持续不升 → 排除其他原因 (出血、过敏、心源性)",
                "全脊麻呼吸停止 → 继续机械通气，麻药代谢后 (2-6h) 可恢复"
            ]
        )
    }
}
