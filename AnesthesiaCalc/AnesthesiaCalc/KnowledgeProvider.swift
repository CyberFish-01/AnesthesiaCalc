import Foundation

// MARK: - KnowledgeSource

enum KnowledgeSource: Equatable {
    case guideline  // 临床指南 — 操作建议、剂量、风险
    case miller     // 米勒麻醉学 — 药理机制、病理生理
}

// MARK: - KnowledgeEntry

struct KnowledgeEntry: Equatable {
    let keywords: [String]
    let title: String
    let content: String
    let source: KnowledgeSource
    let citation: String
    let year: Int
    let institution: String
}

// MARK: - KnowledgeResponse

struct KnowledgeResponse: Equatable {
    let conclusion: KnowledgeEntry?     // 指南结论（临床操作建议）
    let deepAnalysis: KnowledgeEntry?   // 米勒解析（药理机制）
    let hasConflict: Bool               // 两者结论不一致时标记
}

// MARK: - QueryClassifier

private enum QueryClassifier {

    /// Clinical intent keywords → guideline priority
    private static let clinicalKeywords: [String] = [
        "剂量", "用药", "给药", "用法", "用量", "多少", "用多少",
        "风险", "禁忌", "注意", "警告", "预警",
        "指南", "推荐", "建议", "应该", "怎么用",
        "诱导", "维持", "插管", "拔管", "镇静", "镇痛",
        "调整", "选择", "首选", "次选"
    ]

    /// Mechanism / physiology keywords → miller priority
    private static let mechanismKeywords: [String] = [
        "为什么", "机制", "原理", "原因", "解释",
        "作用", "代谢", "分布", "清除", "半衰期", "药代", "药动",
        "受体", "蛋白结合", "脂溶", "水溶", "容积",
        "生理", "病理", "分子", "细胞", "信号",
        "脂肪", "组织", "血浆", "肝脏", "肾脏"
    ]

    static func classify(_ question: String) -> (hasClinical: Bool, hasMechanism: Bool) {
        let lower = question.lowercased()
        let hasClinical  = clinicalKeywords.contains(where: lower.contains)
        let hasMechanism = mechanismKeywords.contains(where: lower.contains)

        // If neither matched, default to clinical
        if !hasClinical && !hasMechanism { return (true, false) }
        return (hasClinical, hasMechanism)
    }
}

// MARK: - KnowledgeProvider

final class KnowledgeProvider {

    static let shared = KnowledgeProvider()

    // ── Guideline entries (clinical practice) ──────────────────────────
    private let guidelineEntries: [KnowledgeEntry] = [
        KnowledgeEntry(
            keywords: ["高龄", "丙泊酚", "循环", "诱导", "剂量"],
            title: "高龄患者丙泊酚诱导剂量调整",
            content: """
            高龄患者（>80岁）使用丙泊酚诱导时：

            1. 诱导剂量减少 20%–40%，缓慢推注（>30秒）。
            2. 诱导前充分扩容（晶体液 5–10 mL/kg），备好血管活性药物。
            3. 维持期建议从 2–4 mg/kg/h 起步，根据 BIS 和血压滴定。
            4. 可联合依托咪酯以减少丙泊酚用量。
            """,
            source: .guideline,
            citation: "2024 ASA 老年患者麻醉指南",
            year: 2024,
            institution: "ASA (美国麻醉医师学会)"
        ),
        KnowledgeEntry(
            keywords: ["肥胖", "肌松", "罗库溴铵", "顺式阿曲库铵", "IBW", "体重", "剂量"],
            title: "肥胖患者肌松药剂量选择",
            content: """
            肥胖患者（BMI > 30 kg/m²）使用肌松药的建议：

            1. 罗库溴铵插管剂量：0.6 mg/kg **按 IBW 计算**。
            2. 顺式阿曲库铵：0.15–0.2 mg/kg **按 IBW 计算**。
            3. 追加剂量均按 IBW 计算，间隔 25–30 分钟。
            4. 按 TBW 给药会显著延长肌松恢复时间，增加术后残余肌松风险。
            5. 强烈推荐 TOF 监测，确保 TOF > 0.9 后拔管。
            """,
            source: .guideline,
            citation: "2023 ESAIC 肥胖患者围术期管理指南",
            year: 2023,
            institution: "ESAIC (欧洲麻醉与重症监护学会)"
        ),
        KnowledgeEntry(
            keywords: ["儿科", "小儿", "丙泊酚", "诱导"],
            title: "小儿丙泊酚诱导与维持剂量",
            content: """
            小儿（<12岁，<35kg）丙泊酚使用建议：

            1. 诱导：2.5–3.5 mg/kg（高于成人）。
            2. 维持：9–15 mg/kg/h（小儿肝清除率高）。
            3. 3岁以下慎用大剂量长时间输注，警惕 PRIS。
            """,
            source: .guideline,
            citation: "2024 APA 小儿麻醉指南",
            year: 2024,
            institution: "APA (美国小儿麻醉学会)"
        ),
        KnowledgeEntry(
            keywords: ["芬太尼", "瑞芬太尼", "阿片", "镇痛"],
            title: "围术期阿片类药物选择策略",
            content: """
            芬太尼与瑞芬太尼的临床选择：

            芬太尼：诱导 1–2 μg/kg TBW（≥65岁减半），适用于术后需镇痛的场景。
            瑞芬太尼：诱导 1–2 μg/kg TBW，维持 0.1–0.5 μg/kg/min，适用于需要术中深度镇痛但术后快速苏醒的场景。
            """,
            source: .guideline,
            citation: "2024 ASA 阿片类药物围术期使用指南",
            year: 2024,
            institution: "ASA (美国麻醉医师学会)"
        ),
        KnowledgeEntry(
            keywords: ["恶性高热", "MH", "丹曲林", "应急"],
            title: "恶性高热紧急处理流程",
            content: """
            1. 立即停用吸入麻醉药和琥珀胆碱。
            2. 100% 氧气 >10 L/min。
            3. 丹曲林首剂 2.5 mg/kg，每 5–10 min 重复（最大 10 mg/kg）。
            4. 积极降温、监测血气/血钾/CK/肌红蛋白尿。
            5. ICU 监护至少 24 小时。
            """,
            source: .guideline,
            citation: "2023 MHAUS 恶性高热紧急处理指南",
            year: 2023,
            institution: "MHAUS (北美恶性高热协会)"
        ),
        KnowledgeEntry(
            keywords: ["困难气道", "插管", "预案"],
            title: "困难气道处理流程",
            content: """
            1. 术前评估：Mallampati ≥III、甲颏距离 <6cm、张口度 <3cm 为危险因素。
            2. 备好视频喉镜、喉罩、紧急环甲膜切开包。
            3. 保留自主呼吸的慢诱导或清醒纤支镜插管。
            4. 确认面罩通气可行后再给肌松药。
            """,
            source: .guideline,
            citation: "2022 DAS 困难气道管理指南",
            year: 2022,
            institution: "DAS (英国困难气道学会)"
        )
    ]

    // ── Miller entries (pharmacology / physiology) ──────────────────────
    private let millerEntries: [KnowledgeEntry] = [
        KnowledgeEntry(
            keywords: ["肥胖", "肌松", "IBW", "分布", "脂肪", "水溶", "容积", "为什么"],
            title: "肌松药在肥胖患者中的分布容积与药代动力学",
            content: """
            肌松药（如罗库溴铵、顺式阿曲库铵）为水溶性季铵化合物，其分布主要局限于中央室（血浆）和细胞外液，不易穿透脂肪组织。

            肥胖患者脂肪组织增加，但细胞外液和血浆容量并不同比例增加。按实际体重 (TBW) 给药会导致：
            - 中央室药物浓度过高，神经肌肉阻滞程度过深
            - 药物再分布至外周后，因脂肪组织中分布极少，清除半衰期延长
            - 术后残余肌松风险显著增加

            按理想体重 (IBW) 计算剂量，可使中央室药物浓度与血浆/细胞外液容积匹配，达到预期的阻滞深度和恢复时间。
            """,
            source: .miller,
            citation: "Miller's Anesthesia, 9th Ed., Ch. 34",
            year: 2020,
            institution: "Miller 米勒麻醉学（第九版）"
        ),
        KnowledgeEntry(
            keywords: ["高龄", "丙泊酚", "循环", "心血管", "机制", "为什么", "低血压"],
            title: "丙泊酚对老年人心血管系统的药理影响",
            content: """
            丙泊酚通过增强 GABA_A 受体功能产生麻醉作用，同时抑制交感神经张力并直接扩张血管平滑肌，导致剂量依赖性血压下降。

            高龄患者对丙泊酚心血管抑制效应更为敏感的原因：
            1. 中央室分布容积减小（血容量减少、心输出量降低），初始血药浓度更高
            2. 压力感受器反射迟钝，代偿性心率增快能力减弱
            3. 肝脏清除率下降，药物代谢减慢
            4. 心肌 β 受体密度降低，对儿茶酚胺反应减弱

            因此，减量慢推 + 扩容是降低高龄患者诱导期低血压风险的核心策略。
            """,
            source: .miller,
            citation: "Miller's Anesthesia, 9th Ed., Ch. 22",
            year: 2020,
            institution: "Miller 米勒麻醉学（第九版）"
        ),
        KnowledgeEntry(
            keywords: ["儿科", "小儿", "丙泊酚", "代谢", "为什么", "清除"],
            title: "小儿丙泊酚药代动力学特点",
            content: """
            小儿丙泊酚清除率显著高于成人（约 30–50%），主要因为：
            1. 肝血流量/体重比高于成人，首过效应增强
            2. 葡萄糖醛酸化途径成熟早，II 相代谢活跃
            3. 中央室分布容积/体重比高于成人

            因此小儿维持剂量需高于成人（9–15 vs 4–12 mg/kg/h），但 3 岁以下需警惕 PRIS 风险。
            """,
            source: .miller,
            citation: "Miller's Anesthesia, 9th Ed., Ch. 37",
            year: 2020,
            institution: "Miller 米勒麻醉学（第九版）"
        ),
        KnowledgeEntry(
            keywords: ["阿片", "芬太尼", "瑞芬太尼", "药代", "代谢", "为什么"],
            title: "芬太尼与瑞芬太尼的药代动力学差异",
            content: """
            芬太尼与瑞芬太尼虽然同为 μ 受体激动剂，但药代动力学差异显著：

            芬太尼：高脂溶性，广泛分布于脂肪和骨骼肌（Vdss 4 L/kg），经 CYP3A4 肝代谢，消除半衰期 3–7 小时。大剂量或长时间输注后，蓄积效应显著。

            瑞芬太尼：结构中含酯键，被血液和组织中非特异性酯酶快速水解，不依赖肝肾清除。消除半衰期仅 3–10 分钟，时量相关半衰期恒定（约 3.5 min），不随输注时间延长而变化。

            因此瑞芬太尼适合需要术中深度镇痛且术后快速苏醒的手术，而芬太尼适合需要术后镇痛过渡的手术。
            """,
            source: .miller,
            citation: "Miller's Anesthesia, 9th Ed., Ch. 23",
            year: 2020,
            institution: "Miller 米勒麻醉学（第九版）"
        ),
        KnowledgeEntry(
            keywords: ["恶性高热", "MH", "机制", "钙", "受体", "为什么"],
            title: "恶性高热分子机制与丹曲林药理",
            content: """
            恶性高热的分子基础是骨骼肌肌浆网 Ryanodine 受体 (RYR1) 基因突变，导致吸入麻醉药/琥珀胆碱触发不受控的 Ca²⁺ 释放。

            丹曲林通过与 RYR1 结合，直接抑制肌浆网 Ca²⁺ 释放通道，将胞浆 Ca²⁺ 浓度恢复正常。丹曲林不阻断神经肌肉接头，不引起呼吸肌麻痹，水溶性差需用专用溶剂配制。
            """,
            source: .miller,
            citation: "Miller's Anesthesia, 9th Ed., Ch. 44",
            year: 2020,
            institution: "Miller 米勒麻醉学（第九版）"
        )
    ]

    private init() {}

    // MARK: - Query

    /// Main entry point — classify question, search both sources, build structured response.
    func query(_ question: String) -> KnowledgeResponse {
        let (hasClinical, hasMechanism) = QueryClassifier.classify(question)

        let guidelineMatch: KnowledgeEntry?
        let millerMatch: KnowledgeEntry?

        if hasClinical {
            guidelineMatch = bestMatch(in: guidelineEntries, for: question)
        } else {
            guidelineMatch = nil
        }

        if hasMechanism {
            millerMatch = bestMatch(in: millerEntries, for: question)
        } else {
            // For purely clinical questions, still try to find a Miller entry
            // to provide context — but only if it's a strong match.
            millerMatch = bestMatch(in: millerEntries, for: question, threshold: 2)
        }

        // If clinical intent returned no match, try Miller as fallback for guidance
        let fallbackGuideline: KnowledgeEntry? = (guidelineMatch == nil && !hasMechanism)
            ? bestMatch(in: millerEntries, for: question, threshold: 1) : nil

        return KnowledgeResponse(
            conclusion: guidelineMatch ?? fallbackGuideline,
            deepAnalysis: millerMatch,
            hasConflict: false // Set true for future contradictory scenarios
        )
    }

    // MARK: - Search helper

    private func bestMatch(in entries: [KnowledgeEntry], for question: String, threshold: Int = 1) -> KnowledgeEntry? {
        let lower = question.lowercased()
        var best: (entry: KnowledgeEntry, score: Int)?

        for entry in entries {
            let score = entry.keywords.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
            if score > 0 {
                if let b = best {
                    if score > b.score { best = (entry, score) }
                } else {
                    best = (entry, score)
                }
            }
        }
        guard let b = best, b.score >= threshold else { return nil }
        return b.entry
    }

    // MARK: - Fallback

    var fallbackResponse: String {
        """
        您的问题暂未匹配到特定指南或教材条目。建议：

        1. 查阅最新版《米勒麻醉学》或相关临床指南。
        2. 登录 PubMed 检索最新临床研究。
        3. 咨询上级医师或科室讨论。
        """
    }

    var fallbackSource: String {
        "通用临床参考（未匹配特定来源）"
    }
}
