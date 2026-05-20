# AnesthesiaCalc 新功能需求设计文档

> 以大三甲麻醉科主任视角审定的新模块需求
> 最后更新: 2026-05-19

---

## 优先级总览

| 优先级 | 模块 | 状态 | 理由 |
|--------|------|------|------|
| **P0** | 气道评估系统 | 待实现 | 困难气道是可预防的严重不良事件 |
| **P0** | ABL + 输血指征 | 待实现 | 科里天天算，计算量不大但易错 |
| **P0** | 液体管理 (4-2-1 + 第三间隙) | 待实现 | 规培生最需要引导的项目 |
| **P0** | 紧急预案速查 | 待实现 | 低概率高致死，需零等待设计 |
| **P1** | ABG 血气解读 + 临床建议 | 待实现 | 纯数学无依赖，对决策支撑极强 |
| **P2** | 麻醉记录单手动录入版 | 设计中 | 需纸→电录入工具，暂缓 |
| **—** | 药物相互作用互查 | 推后 | — |
| **—** | PCA 配置 | 推后 | 有固定配方，不需软件 |
| **—** | WHO 安全核对表 | 不需要 | — |
| **—** | 科室管理面板 | 不需要 | — |

---

## 一、气道评估系统

### 1.1 Core 层设计

**文件位置**: `AnesthesiaCalcCore/Sources/AnesthesiaCalcCore/Calculators/AirwayAssessmentEngine.swift`

**输入数据结构**:

```swift
public struct AirwayExam: Equatable {
    public let mallampati: MallampatiClass      // I-IV
    public let mouthOpeningCm: Double           // 切牙间距 (cm)，≥4.0 为正常
    public let thyromentalDistanceCm: Double    // 甲颏距 (cm)，≥6.5 为正常
    public let neckExtension: NeckExtensionGrade // 正常 / 轻度受限 / 重度受限
    public let upperLipBite: ULBTClass          // I-III 级
    public let dentition: DentitionRisk         // 无牙 / 正常 / 龅牙/松动
    public let hasBeard: Bool                   // 络腮胡影响面罩通气
    public let snoresHeavily: Bool              // 鼾症 → 预测面罩通气困难
    public let knownDifficultAirway: Bool       // 既往困难气道史（权重最高）
}
```

**输出数据结构**:

```swift
public struct AirwayRiskAssessment: Equatable {
    public let score: Int
    public let riskTier: AirwayRiskTier              // .low / .moderate / .high
    public let predictedDifficultLaryngoscopy: Double // 0-1 概率
    public let predictedDifficultBMV: Double          // 面罩通气困难概率
    public let recommendation: AirwayPlan             // 推荐插管方案
    public let rationale: [String]                    // 危险因素逐条列出
}

public enum AirwayRiskTier: String { case low, moderate, high }

public enum AirwayPlan: String {
    case standardMac         // 常规喉镜 (Macintosh)
    case videolaryngoscope   // 可视喉镜 (GlideScope / UE)
    case awakeFiberoptic     // 清醒纤支镜插管
    case surgicalAirway      // 建议备外科气道
}
```

### 1.2 评分算法

简化改良版多维评分，每个维度 0 或 1 分：

| 维度 | 0 分 | 1 分 |
|------|------|------|
| Mallampati | I-II | III-IV |
| 张口度 | ≥4.0 cm | <4.0 cm |
| 甲颏距 | ≥6.5 cm | <6.5 cm |
| 颈活动度 | 正常 | 受限 |
| 上唇咬合 | I 级 | II-III 级 |
| 困难气道史 | 无 | 有 |

**风险分层**:
- 总分 0-1 → `low`，常规喉镜
- 总分 2 → `moderate`，备可视喉镜
- 总分 ≥3 → `high`，准备纤支镜清醒插管

**独立加权**:
- 困难气道史 → 直接升一档风险
- BMI >35 (从 PatientContext 获取) → 直接升一档风险
- 合并面罩通气困难预测 → `surgicalAirway` 备选

**面罩通气困难独立预测 (OBESE 法则)**:
- 从体检中取 `hasBeard`、`snoresHeavily`、`dentition`、BMI
- 每个阳性因素 +1，≥3 → 面罩通气困难高风险

### 1.3 UI 层设计

- 半屏 Sheet (`presentationDetents([.medium, .large])`)
- 上半区：7 个输入项（Picker / Stepper / Toggle），2 列网格布局
- 下半区：结果卡片
  - 风险分层用大字体 + 色标（绿/橙/红）
  - 推荐方案用 Icon + 文字
  - 展开可看每项危险因素
- 已有点击触发时 `UIImpactFeedbackGenerator(style: .medium)` 震动反馈

### 1.4 规培视角补充

- **教学卡片**：每个危险因素均可点击弹出教学卡片，显示典型图片参考和判别标准
  - Mallampati 分级：I-IV 级典型咽部视图
  - 颈活动度量化：正常=可后仰>35° / 轻度受限=下颌不能贴胸壁 / 重度受限=后仰<15°
- **安全底线提示**：高风险评估结果底部显示"建议与上级确认"提示条
- **推荐方案理由**：不仅显示"推荐清醒纤支镜插管"，同时解释"因 Mallampati IV+甲颏距<6cm，预计喉镜暴露困难，不建议尝试常规喉镜"

### 1.5 主治视角补充

- **特殊人群标记**：
  - `isPregnant: Bool` — 妊娠晚期气道水肿，Mallampati 可能假阴性，自动升一档风险
  - `hasNeckRadiation: Bool` — 颈部放疗后组织纤维化，自动升一档风险
- **CICO 预案联动**：高风险（≥3 分+面罩通气困难预测）时，底部附加"CICO 紧急预案"链接
- **产科困难气道专项**：isPregnant=true 时增加胃排空延迟风险提醒

### 1.6 数据模型补充

```swift
public let isPregnant: Bool          // 妊娠晚期 → 自动升一档风险
public let hasNeckRadiation: Bool    // 颈部放疗后 → 自动升一档风险
public let hasOSA: Bool              // 睡眠呼吸暂停 → 面罩通气困难风险+1
```

---

## 二、ABL + 输血指征

### 2.1 Core 层设计

**文件位置**: `AnesthesiaCalcCore/Sources/AnesthesiaCalcCore/Calculators/ABLCalculator.swift`

**输入数据结构**:

```swift
public struct ABLInput: Equatable {
    public let weightKg: Double
    public let sex: BiologicalSex
    public let isPregnant: Bool               // 妊娠→EBV 上调 20%
    public let preoperativeHct: Double        // 0.30–0.55
    public let preoperativeHb: Double         // g/L
    public let targetHct: Double              // 默认 0.25，心血管病 0.30
    public let targetHb: Double               // 默认 70 g/L
}
```

**输出数据结构**:

```swift
public struct ABLResult: Equatable {
    public let estimatedBloodVolume: Double       // mL
    public let allowableBloodLoss: Double          // mL (基于 Hct)
    public let allowableBloodLossHb: Double        // mL (基于 Hb)
    public let rbcTransfusionTrigger: Double       // 达到此失血量建议开始输血
    public let ffpTransfusionTrigger: Double       // 达到此失血量建议开始 FFP
    public let plateletTrigger: String             // 血小板输注指征
    public let bloodLossAsPercentage: Double       // ABL/EBV × 100%
}
```

### 2.2 核心公式

```
1. 估算血容量 (EBV)
   EBV = weight × coefficient
   系数: male=70, female=65, neonate=85, child(2-12y)=80

2. 允许失血量 (ABL)
   ABL = EBV × (Hct₀ - Hct_target) / Hct₀
   ABL(Hb版) = EBV × (Hb₀ - Hb_target) / Hb₀
```

### 2.3 输血指征

引用 2025 中国围术期输血指南：

| 条件 | 建议 |
|------|------|
| Hb < 70 g/L | 输注红细胞 |
| Hb 70-100 g/L + 冠心病/COPD/脑血管病 | 输注红细胞 |
| 失血量 > ABL × 1.5 | 启动大量输血预案 (MTP) |
| PLT < 50×10⁹/L | 输注血小板 |
| PT/INR > 1.5× 正常 | FFP 10-15 mL/kg |
| Fib < 1.0 g/L | 冷沉淀/纤维蛋白原 |

### 2.4 UI 层设计

- 紧凑卡片，200pt 固定高度
- 输入：术前 Hct（Picker）、手术类型（Picker）、目标 Hct（可选 Stepper）
- 输出：
  - 主行：`ABL = 2,100 mL`（34pt 圆体）
  - 次级：`EBV 4,900 mL · 可失 43%`
  - 黄色警告线：累计出血超 ABL 80%
  - 红色警告线：超 100%

### 2.5 规培视角补充

- **边界提醒**：`Hb 70-100 g/L 无合并症`时明确提示"不推荐预防性输血，优先晶体复苏"
- **出血速度警告**：出血速度 > 500mL/10min 触发"快速失血警告——即使未达 ABL 上限也应立即评估"
- **"什么时候叫上级"**：累计出血 > ABL×50% 时提示"建议通知上级医师"
- **MTP 启动阈值可视化**：当累计出血 > ABL×1.5 时红色横幅"启动大量输血预案 (MTP)"

### 2.6 主治视角补充

- **手术类型对输血阈值影响**：神经外科（Hb<90 即触发）vs 普外科（Hb<70 触发），增加手术类型选择器
- **MTP 比例展示**：1:1:1 (RBC:FFP:PLT) 或 6:4:1 方案可视化
- **凝血功能联动**：如输入 PT/INR/Fib/PLT，自动匹配对应血液制品输注指征

---

## 三、液体管理 (4-2-1 + 第三间隙)

### 3.1 Core 层设计

**文件位置**: `AnesthesiaCalcCore/Sources/AnesthesiaCalcCore/Calculators/FluidManagementCalculator.swift`

**输入数据结构**:

```swift
public struct FluidInput: Equatable {
    public let weightKg: Double
    public let fastingHours: Double              // 禁食时间 (h)，默认 8
    public let surgeryType: SurgeryInvasiveness
    public let estimatedSurgeryMinutes: Int
    public let crystalloidType: CrystalloidType  // LR / 复方电解质 / NS
}

public enum SurgeryInvasiveness: String, CaseIterable {
    case superficial   // 体表手术 → 1-2 mL/kg/h
    case moderate      // 腔镜/小切口 → 3-4 mL/kg/h
    case major         // 开腹/开胸 → 6-8 mL/kg/h
    case severe        // 大面积烧伤/创伤 → 8-10 mL/kg/h
}
```

**输出数据结构**:

```swift
public struct FluidPlan: Equatable {
    // 术前
    public let maintenanceRateMLPerH: Double       // 4-2-1 法则结果
    public let fastingDeficitML: Double             // 禁食缺失总量
    public let firstHourReplacementML: Double       // 第一小时补液量（缺失量 1/2）

    // 术中
    public let hourlyMaintenanceML: Double           // 每小时生理需要量
    public let thirdSpaceRateMLPerH: Double          // 第三间隙丢失速率
    public let hourlyTotalML: Double                 // 每小时总需量

    // 全量
    public let totalCrystalloidForCaseML: Double     // 整台手术预估晶体量
    public let recommendedBolusML: Double            // 推荐初始负荷量

    // 溯源
    public let formulaTrace: String                  // 公式明细
}
```

### 3.2 核心公式

**4-2-1 法则**:

```
maintenanceRate = 
    4 × min(weight, 10) 
  + 2 × max(0, min(weight-10, 10)) 
  + 1 × max(0, weight-20)

fastingDeficit = maintenanceRate × fastingHours
firstHourBolus = fastingDeficit / 2（补一半，剩下一半分 2h）
```

**第三间隙液体替换速率**:

| 手术类型 | 范围 (mL/kg/h) | 默认值 |
|---------|---------------|--------|
| 体表 | 1-2 | 1.5 |
| 腔镜 | 3-4 | 3.5 |
| 开腹 | 6-8 | 7.0 |
| 重大创伤 | 8-10 | 9.0 |

### 3.3 UI 层设计

- 紧凑卡片，放在 ABL 卡片旁边或下方
- 输入：禁食时间 Stepper（默认 8h）、手术类型 Picker
- 输出：
  - 主行：`术中 350 mL/h`（34pt 圆体）
  - 次级：`维持 110 + 第三间隙 240 (7×70/60)`
  - 第三行：`术前缺失 880 mL → 首时补 440 mL`
  - 按 Harness Check 6：卡片底部 9pt monospaced 公式溯源行
    - 格式：`4×10+2×10+1×50=110 mL/h | 3rd: 7×70=490 mL/h`

### 3.4 规培视角补充

- **手术类型细化**：Picker 选项中增加示例手术名
  - 体表：乳腺肿物切除、脂肪瘤切除
  - 腔镜：LC (胆囊)、LA (阑尾)、TURP (前列腺)
  - 开腹：胃癌根治、结肠切除、肝叶切除
  - 重大创伤：多发伤、烧伤>50% BSA、主动脉破裂
- **术中调整指导**：显示"如尿量<0.5 mL/kg/h 或 CVP<5，加快补液；如出现肺水肿体征，减慢或加利尿剂"
- **首选液体类型提示**：根据手术类型自动建议晶体类型（LR/醋酸林格 vs NS 慎用）

### 3.5 主治视角补充

- **GDFT 动态指标**：可选输入 SVV/PPV
  - SVV>13% → "提示容量反应性良好，建议 bolus 250mL 晶体"
  - SVV<10% → "容量反应性差，慎补液，考虑血管活性药"
- **累计出入量追踪**：术中实时累加晶体/胶体/血制品输入量，与 ABL 模块联动的失血量合并显示
- **复苏终点参考**：MAP≥65、尿量≥0.5 mL/kg/h、Lac 下降、SVV<12%

---

## 四、紧急预案速查

### 4.1 Core 层设计

**文件位置**: `AnesthesiaCalcCore/Sources/AnesthesiaCalcCore/Engine/EmergencyProtocolEngine.swift`

**数据结构**:

```swift
public struct EmergencyProtocol: Identifiable {
    public let id: String
    public let name: String                    // "过敏性休克"
    public let recognition: String             // 识别要点（2-3 行要点式）
    public let immediateActions: [String]      // 立即措施
    public let drugSteps: [EmergencyDrugStep]  // 已预计算的用药步骤
    public let escalation: [String]            // 升级措施
}

public struct EmergencyDrugStep {
    public let drugName: String
    public let route: String
    public let calculatedDose: String       // 已算好剂量 "肾上腺素 70 μg IV"
    public let rawInstruction: String       // 通用指导
    public let note: String?                // 稀释说明等
}
```

### 4.2 六套核心预案

| 预案 | 关键用药 | 体重依赖 |
|------|---------|---------|
| 心脏骤停 (ACLS) | 肾上腺素 1mg q3-5min | 否 |
| 过敏性休克 | 肾上腺素 IV 10-100μg / IM 0.3-0.5mg + 甲强龙 1-2mg/kg | **是** |
| 恶性高热 | 丹曲林 2.5mg/kg 重复至 10mg/kg | **是** |
| LAST (局麻药中毒) | 20% 脂肪乳 1.5mL/kg bolus → 0.25mL/kg/min | **是** |
| 大出血 MTP | 1:1:1 RBC:FFP:PLT | **是**（基于 EBV） |
| 高平面/全脊麻 | 麻黄碱 / 去氧肾上腺素 / 肾上腺素 | **是** |

### 4.3 设计要点

- `EmergencyProtocolEngine` 是纯枚举，接收 `PatientContext`
- 体重依赖的药品剂量自动代入临床上下文的 TBW/IBW
- 全部预案在首次启动时加载到内存，无需网络

### 4.4 UI 层设计

- 独立 Tab 页或主页专用入口
- 列表式 + 搜索栏（支持拼音缩写：如"gmxk"→ 过敏性休克）
- 点击任一预案 → 全屏展开：
  - 🔴 识别（红色横幅）
  - 🟡 立即措施（黄色背景）
  - 🟢 用药步骤（绿色标注预计算剂量）
  - 📋 升级流程
- 零网络依赖，零等待

### 4.5 规培视角补充

- **识别要点强化**：每个预案增加"早期识别信号"行（如恶性高热：ETCO₂ 急剧升高 + 咬肌痉挛 + 体温骤升）
- **局麻药最大剂量速查**：LAST 预案底部显示常用局麻药最大安全剂量（罗哌卡因≤3mg/kg、利多卡因≤4.5mg/kg、布比卡因≤2mg/kg）
- **分步操作指引**：每步操作标注"本步骤预期效果"和"如果不奏效→下一步"

### 4.6 主治视角补充

- **增加 3 套预案**：
  | CICO (无法插管无法通气) | 环甲膜切开/穿刺流程 | 是 |
  | 术中知晓 | BIS 监测+镇静补救方案 | 否 |
  | 骨水泥植入综合征 | 骨科手术专用 | 是 |
- **预案联动**：过敏性休克→心脏骤停的过渡步骤自动串联
- **药物交互检查**：预案用药与患者当前药物列表的交互风险提示

---

## 五、ABG 血气分析 + 临床建议

### 5.1 Core 层设计

**文件位置**: `AnesthesiaCalcCore/Sources/AnesthesiaCalcCore/Calculators/ABGAnalyzer.swift`

**输入数据结构**:

```swift
public struct ABGInput: Equatable {
    public let pH: Double
    public let paCO2: Double        // mmHg
    public let paO2: Double         // mmHg
    public let hco3: Double         // mmol/L
    public let baseExcess: Double   // mmol/L
    public let lactate: Double?     // mmol/L，可选
    public let na: Double?          // mmol/L，可选（AG 计算）
    public let cl: Double?          // mmol/L，可选
    public let fio2: Double         // 0.21–1.0，默认 0.21
}
```

**输出数据结构**:

```swift
public struct ABGInterpretation: Equatable {
    public let primaryDisorder: AcidBaseDisorder
    public let compensation: CompensationStatus
    public let anionGap: Double?                    // AG = Na - (Cl + HCO₃)，正常 8-12
    public let deltaGap: Double?                    // ΔAG/ΔHCO₃
    public let paO2FiO2Ratio: Double               // P/F 比值
    public let oxygenationStatus: OxygenationStatus
    public let lactateRisk: LactateRiskTier?
    public let clinicalSuggestions: [String]       // 按优先级排序
    public let formulaExplanation: String          // Winter 公式过程
}

public enum AcidBaseDisorder: String {
    case metabolicAcidosis
    case metabolicAlkalosis
    case respiratoryAcidosis
    case respiratoryAlkalosis
    case mixedDisorder
}

public enum CompensationStatus: String {
    case uncompensated       // pH 异常，代偿侧未变
    case partial             // pH 异常，代偿侧正在改变
    case fullyCompensated    // pH 正常但 PaCO₂ 和 HCO₃ 均异常
}

public enum OxygenationStatus: String {
    case normal          // P/F > 400
    case mildHypoxemia   // 300-400
    case moderate        // 200-300
    case severeARDS      // 100-200
    case criticalARDS    // < 100
}

public enum LactateRiskTier: String {
    case normal      // < 2.0 mmol/L
    case mild        // 2.0-4.0
    case moderate    // 4.0-8.0 → 组织低灌注
    case severe      // > 8.0   → 休克状态
}
```

### 5.2 判读逻辑链

```
Step 1: 看 pH
  pH < 7.35 → 酸血症
  pH > 7.45 → 碱血症

Step 2: 找原发
  酸 + PaCO₂↑ + HCO₃ 未代偿 → 原发呼酸
  酸 + HCO₃↓ + PaCO₂ 未降   → 原发代酸
  碱 + PaCO₂↓               → 原发呼碱
  碱 + HCO₃↑               → 原发代碱

Step 3: 判断代偿
  代酸的呼吸代偿 (Winter公式):
    预期 PaCO₂ = 1.5×HCO₃ + 8 ± 2
  代碱的呼吸代偿:
    PaCO₂ 每 ↑1mEq HCO₃ → PaCO₂ ↑0.7 mmHg
  呼酸的肾代偿:
    急性 HCO₃↑1 per 10 PaCO₂↑
    慢性 HCO₃↑3.5 per 10 PaCO₂↑
  呼碱的肾代偿:
    急性 HCO₃↓2 per 10 PaCO₂↓
    慢性 HCO₃↓5 per 10 PaCO₂↓

Step 4: 算 AG (需 Na/Cl)
  AG = Na - Cl - HCO₃
  AG > 12 → 高AG代酸 → 查乳酸/酮体/肾衰

Step 5: ΔAG/ΔHCO₃ (AG升高时)
  < 1.0 → 合并正常AG代酸 (高氯性)
  1.0-2.0 → 单纯高AG代酸
  > 2.0 → 合并代碱
```

### 5.3 临床建议生成规则

| 血气模式 | 建议 |
|---------|------|
| 代酸 + Lac > 4.0 | "乳酸升高提示组织低灌注，建议：评估血容量状态，考虑液体复苏；查 Hb 排除失血；必要时加用去甲肾上腺素维持 MAP≥65 mmHg" |
| 代酸 + AG 正常 | "高氯性代酸趋势，常见于大量 NS 输注。建议：改用平衡晶体液（乳酸林格/醋酸林格），监测 Cl⁻ 水平" |
| 呼酸 + pH < 7.25 | "严重呼吸性酸中毒，建议：检查气管导管位置、气道压、ETCO₂ 波形；排除气胸/支气管痉挛；必要时增加分钟通气量" |
| 代碱 + 低钾 | "代谢性碱中毒，注意伴发低钾血症。建议：查血钾，纠正电解质紊乱；减少胃管引流；必要时乙酰唑胺" |
| P/F < 200 | "符合中重度 ARDS 标准 (Berlin定义)，建议：肺保护通气 Vt 4-6 mL/kg IBW，PEEP 滴定，考虑俯卧位通气" |
| P/F < 100 | "重度 ARDS，除肺保护通气外，重新评估是否需要 ECMO 会诊" |

### 5.4 UI 层设计

- 紧凑卡片，放在药物列表下方
- 输入区：一行 8 个 TextField（pH / PaCO₂ / PaO₂ / HCO₃ / BE / Lac / Na / Cl），FIO₂ 用 Stepper
- 输出区：
  - 结论：`代酸 (高AG型) + 部分呼吸代偿`（颜色按严重程度）
  - AG 行：`AG=18 (↑)  ΔAG/ΔHCO₃=1.2`
  - P/F 行：`P/F=280 (轻度低氧)`
  - Lactate 行（如输入）：`Lac=5.2 mmol/L ⚠️ 中度升高`
  - 临床建议展开区（橙色背景条）：3-5 条优先级排序的建议
  - 公式溯源码（可折叠）

### 5.5 规培视角补充

- **Na/Cl 缺失提示**：未输入 Na⁺/Cl⁻ 时 AG 栏显示"输入 Na⁺/Cl⁻ 以计算 AG"而非空白
- **混合紊乱鉴别提示**：ΔAG/ΔHCO₃ 异常时输出"可能合并其他酸碱紊乱，建议复查"或"ΔAG/ΔHCO₃>2.0 提示合并代谢性碱中毒"
- **逐步推理展示**：折叠式 Step 1-5 展示，每步标注判断逻辑，也可展开查看 Winter 公式计算过程

### 5.6 主治视角补充

- **拔管条件评估**：底部增加拔管评估行
  - pH>7.25 + P/F>200 + PaCO₂<50 → "可考虑拔管"
  - 否则 → "建议延迟拔管，30min 后复查血气"
- **A-aDO₂ 计算**：增加 `barometricPressure` 输入（默认 760mmHg），自动计算肺泡-动脉氧分压差
  - A-aDO₂ = (PB-47)×FIO₂ - PaCO₂/0.8 - PaO₂
- **Pa-ETCO₂ gap**：输入 ETCO₂ 值（可选），计算死腔通气指标
  - Pa-ETCO₂ gap > 5 → "死腔通气增加，排查肺栓塞/低心排/PEEP 过高"
- **趋势比对**：支持保存多次 ABG 结果，同屏展示趋势（pH↓ + Lac↑ = 恶化趋势）

---

## 六、麻醉记录单手动录入版

### 6.1 定位

前提：先在纸上写麻醉单，事后往软件里录入。

> 结构化麻醉事件时间轴记录器 + 一键导出/分享

### 6.2 核心功能

1. **新建病例**：自动从 `ClinicalContext.shared` 填充患者基本信息
2. **事件录入**：时间轴形式，预设按钮阵：
   - `入室` `诱导` `插管` `切皮` `关键事件` `拔管` `离室`
   - 点击自动加盖时间戳
3. **药物记录**：从 DrugCatalog 点选 → 剂量基于体重 auto-fill → 手动确认 → 挂载到时间轴
4. **体征快照**：手动输入 BP/HR/SpO₂/ETCO₂，每 5-10 分钟一条
5. **导出**：生成结构化文本/PDF（表格式麻醉记录单），支持打印或 AirDrop

### 6.3 状态

暂缓实现，待前五个计算模块完成后再单独设计。

---

## 七、实现计划

### 第一轮 — Core 层（可并行，互不依赖）

| 文件 | 模块 | 位置 |
|------|------|------|
| `AirwayAssessmentEngine.swift` | 气道评估 | `Calculators/` |
| `ABLCalculator.swift` | ABL + 输血指征 | `Calculators/` |
| `FluidManagementCalculator.swift` | 液体管理 | `Calculators/` |
| `EmergencyProtocolEngine.swift` | 紧急预案 | `Engine/` |
| `ABGAnalyzer.swift` | ABG 血气解读 | `Calculators/` |

### 第二轮 — UI 层

五个对应的 UI 卡片/Sheet（`AnesthesiaCalc/AnesthesiaCalc/`）

### 第三轮 — 麻醉记录单

时间轴录入工具 + PDF 导出

### 架构约束

- Core 层：`import Foundation` only，零 UI 依赖
- UI 层：零药物数学公式，全部委托 Core 公开 API
- 每模块输入来自 `PatientContext`（从 `ClinicalContext.shared` 派生）
- 所有公式溯源必须在 Core 层生成 `formulaTrace` 字符串
- 浓度参数强制 `guard > 0`，杜绝 `inf` / `nan`
- Harness Check 2：计算收敛于基础体重因子，不自行推演额外变量
- Harness Check 12：全部面向临床医师的标签 100% 医学中文

---

## 八、不需要的功能

以下功能经评估后**不做**：

- ❌ WHO 安全核对表 — 纸质流程已满足需求
- ❌ 科室管理面板 — 用不上
- ❌ PCA 配置 — 有固定配方，不需软件
- ❌ 监护仪数据接口 — 无硬件条件

---

## 九、已推后的功能

- 🔜 药物相互作用互查 — 待核心模块完成后评估
