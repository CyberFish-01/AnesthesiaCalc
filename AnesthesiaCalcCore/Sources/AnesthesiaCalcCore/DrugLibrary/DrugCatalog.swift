import Foundation

// MARK: - DrugCatalogEntry

/// A single drug definition in the built-in catalog.
public struct DrugCatalogEntry {
    public let name: String
    public let category: String
    public let defaultConcentration: Double   // mg/mL, 0 for non-numeric forms
    public let concentrationUnit: String

    public init(name: String, category: String, defaultConcentration: Double, concentrationUnit: String) {
        self.name = name
        self.category = category
        self.defaultConcentration = defaultConcentration
        self.concentrationUnit = concentrationUnit
    }
}

// MARK: - DrugCatalog

/// Built-in drug catalog — the single source of truth for all pre-loaded drugs.
///
/// Each entry includes the Chinese drug name, pharmacological category, default
/// commercial concentration, and unit. The catalog drives both the main-screen
/// drug cards and the settings drug list.
public enum DrugCatalog {

    public static let all: [DrugCatalogEntry] = [
        // ── 镇静催眠药 ────────────────────────────────────────────────
        DrugCatalogEntry(name: "丙泊酚",          category: "镇静催眠药", defaultConcentration: 10.0, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "环泊酚",          category: "镇静催眠药", defaultConcentration: 2.5,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "依托咪酯",        category: "镇静催眠药", defaultConcentration: 2.0,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "右美托咪定",      category: "镇静催眠药", defaultConcentration: 0.1,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "瑞马唑仑",        category: "镇静催眠药", defaultConcentration: 0,    concentrationUnit: "冻干粉 25mg/36mg"),
        DrugCatalogEntry(name: "咪达唑仑",        category: "镇静催眠药", defaultConcentration: 1.0,  concentrationUnit: "mg/mL"),

        // ── 吸入麻醉药 ────────────────────────────────────────────────
        DrugCatalogEntry(name: "七氟烷",          category: "吸入麻醉药", defaultConcentration: 0,    concentrationUnit: "挥发性液体"),
        DrugCatalogEntry(name: "地氟烷",          category: "吸入麻醉药", defaultConcentration: 0,    concentrationUnit: "挥发性液体 (需加热挥发罐)"),

        // ── 阿片类镇痛药 ──────────────────────────────────────────────
        DrugCatalogEntry(name: "芬太尼",          category: "阿片类镇痛药", defaultConcentration: 0.05, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "舒芬太尼",        category: "阿片类镇痛药", defaultConcentration: 0.05, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "瑞芬太尼",        category: "阿片类镇痛药", defaultConcentration: 0.05, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "阿芬太尼",        category: "阿片类镇痛药", defaultConcentration: 0.5,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "羟考酮",          category: "阿片类镇痛药", defaultConcentration: 10.0, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "吗啡",            category: "阿片类镇痛药", defaultConcentration: 10.0, concentrationUnit: "mg/mL"),

        // ── 新型阿片类镇痛药 ──────────────────────────────────────────
        DrugCatalogEntry(name: "奥赛利定",        category: "新型阿片类镇痛药", defaultConcentration: 1.0, concentrationUnit: "mg/mL"),

        // ── 混合型阿片受体激动-拮抗剂 ─────────────────────────────────
        DrugCatalogEntry(name: "地佐辛",          category: "混合型阿片受体激动-拮抗剂", defaultConcentration: 5.0,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "纳布啡",          category: "混合型阿片受体激动-拮抗剂", defaultConcentration: 10.0, concentrationUnit: "mg/mL"),

        // ── 中枢镇痛药 ────────────────────────────────────────────────
        DrugCatalogEntry(name: "曲马多",          category: "中枢镇痛药", defaultConcentration: 50.0, concentrationUnit: "mg/mL"),

        // ── 特异性拮抗剂 ──────────────────────────────────────────────
        DrugCatalogEntry(name: "氟马西尼",        category: "特异性拮抗剂", defaultConcentration: 0.1, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "纳美芬",          category: "特异性拮抗剂", defaultConcentration: 0.1, concentrationUnit: "mg/mL"),

        // ── 神经肌肉阻滞药 ────────────────────────────────────────────
        DrugCatalogEntry(name: "顺式阿曲库铵",    category: "神经肌肉阻滞药", defaultConcentration: 2.0,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "罗库溴铵",        category: "神经肌肉阻滞药", defaultConcentration: 10.0, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "米库氯铵",        category: "神经肌肉阻滞药", defaultConcentration: 2.0,  concentrationUnit: "mg/mL"),

        // ── 特异性肌松拮抗剂 ──────────────────────────────────────────
        DrugCatalogEntry(name: "舒更葡萄糖钠",    category: "特异性肌松拮抗剂", defaultConcentration: 100.0, concentrationUnit: "mg/mL"),

        // ── 呼吸中枢兴奋药 ────────────────────────────────────────────
        DrugCatalogEntry(name: "多沙普仑",        category: "呼吸中枢兴奋药", defaultConcentration: 20.0, concentrationUnit: "mg/mL"),

        // ── 局部麻醉药 ────────────────────────────────────────────────
        DrugCatalogEntry(name: "罗哌卡因",        category: "局部麻醉药", defaultConcentration: 7.5,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "布比卡因脂质体",  category: "长效局部麻醉药", defaultConcentration: 13.3, concentrationUnit: "mg/mL"),

        // ── 表面麻醉药 ────────────────────────────────────────────────
        DrugCatalogEntry(name: "复方利多卡因乳膏", category: "表面麻醉药", defaultConcentration: 0, concentrationUnit: "外用乳膏 (25mg+25mg/g)"),

        // ── 血管活性药 ────────────────────────────────────────────────
        DrugCatalogEntry(name: "麻黄碱",          category: "血管活性药", defaultConcentration: 3.0,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "间羟胺",          category: "血管活性药", defaultConcentration: 1.0,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "去甲肾上腺素",    category: "血管活性药", defaultConcentration: 2.0,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "肾上腺素",        category: "血管活性药", defaultConcentration: 1.0,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "多巴胺",          category: "血管活性药", defaultConcentration: 10.0, concentrationUnit: "mg/mL"),

        // ── 心血管药物 ────────────────────────────────────────────────
        DrugCatalogEntry(name: "艾司洛尔",        category: "心血管药物", defaultConcentration: 10.0, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "乌拉地尔",        category: "心血管药物", defaultConcentration: 5.0,  concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "硝酸甘油",        category: "心血管药物", defaultConcentration: 5.0,  concentrationUnit: "mg/mL"),

        // ── 抢救用药 ──────────────────────────────────────────────────
        DrugCatalogEntry(name: "艾司氯胺酮",      category: "抢救用药", defaultConcentration: 25.0, concentrationUnit: "mg/mL"),

        // ── 术前用药 / 抗胆碱药 ───────────────────────────────────────
        DrugCatalogEntry(name: "戊乙奎醚",        category: "术前用药", defaultConcentration: 1.0, concentrationUnit: "mg/mL"),

        // ── 止吐药 ────────────────────────────────────────────────────
        DrugCatalogEntry(name: "昂丹司琼",        category: "止吐药", defaultConcentration: 2.0, concentrationUnit: "mg/mL"),

        // ── 抑酸药 / 蛋白酶抑制剂 ─────────────────────────────────────
        DrugCatalogEntry(name: "艾司奥美拉唑",    category: "抑酸药", defaultConcentration: 0,   concentrationUnit: "冻干粉 40mg"),
        DrugCatalogEntry(name: "乌司他丁",        category: "广谱蛋白酶抑制剂", defaultConcentration: 0, concentrationUnit: "冻干粉 10万U"),

        // ── 止血 / 凝血药 ─────────────────────────────────────────────
        DrugCatalogEntry(name: "氨甲环酸",        category: "抗纤溶止血药", defaultConcentration: 100.0, concentrationUnit: "mg/mL"),
        DrugCatalogEntry(name: "尖吻蝮蛇血凝酶",  category: "凝血促进药", defaultConcentration: 0, concentrationUnit: "冻干粉 1KU"),

        // ── 液体管理 ──────────────────────────────────────────────────
        DrugCatalogEntry(name: "羟乙基淀粉",      category: "血浆代用品", defaultConcentration: 0, concentrationUnit: "6% HES 预充液"),
        DrugCatalogEntry(name: "碳酸氢钠林格液",  category: "晶体液", defaultConcentration: 0, concentrationUnit: "平衡盐溶液")
    ]

    /// Look up the Chinese pharmacological category for a given drug name.
    public static func category(for name: String) -> String {
        all.first { $0.name == name }?.category ?? "其他"
    }

    /// Ordered list of categories for UI grouping.
    public static let categoryOrder: [String] = [
        "镇静催眠药",
        "吸入麻醉药",
        "阿片类镇痛药",
        "新型阿片类镇痛药",
        "混合型阿片受体激动-拮抗剂",
        "中枢镇痛药",
        "特异性拮抗剂",
        "神经肌肉阻滞药",
        "特异性肌松拮抗剂",
        "呼吸中枢兴奋药",
        "局部麻醉药",
        "长效局部麻醉药",
        "表面麻醉药",
        "血管活性药",
        "心血管药物",
        "抢救用药",
        "术前用药",
        "止吐药",
        "抑酸药",
        "广谱蛋白酶抑制剂",
        "抗纤溶止血药",
        "凝血促进药",
        "血浆代用品",
        "晶体液"
    ]
}
