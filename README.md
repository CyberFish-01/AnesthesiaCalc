# AnesthesiaCalc — 麻醉用药剂量计算器

一款面向麻醉科医师的 iOS 辅助应用。输入患者体重、身高、年龄、性别后，自动计算临床常用麻醉药物的诱导与维持剂量区间，并提供 AI 辅助麻醉方案生成能力。

## 功能概览

### 计算器（主屏）
- 输入患者基本信息：体重 (kg)、身高 (cm)、年龄、性别
- 自动推导 IBW（理想体重，Devine 公式）、LBW（瘦体重，Boer 公式）、BMI
- **45 种药物 × 24 个类别**分类展示，每张卡片支持切换剂量类型（诱导 / 维持 / 镇静 / 镇痛 / 插管 / 拮抗），实时刷新
- **儿科模式**：Age < 12 且 Weight < 35kg 自动触发，强制两位小数精度、字体放大 24pt
- **微量泵矩阵**：非推注类药物自动展示 0.8× / 1.0× / 1.2× 剂量率 → mL/h 流速映射
- 全局单列布局，纯白卡片 + 细微弥散阴影，视觉整齐一致

### 内置药物与剂量规则

覆盖 45 种麻醉常用药物，含 **26 种带有临床剂量规则**的药物，规则来源于 CSA TIVA 2024 指南、Miller's Anesthesia 9th Ed. 及 FDA 说明书。核心药物举例：

| 药物 | 浓度 | 剂量规则 |
|------|------|----------|
| **丙泊酚** (Propofol) | 10 mg/mL | 诱导 1.5–2.5 mg/kg TBW · 维持 4.0–12.0 mg/kg/h · 镇静 0.5–4.0 mg/kg/h |
| **罗库溴铵** (Rocuronium) | 10 mg/mL | 插管 0.6–1.2 mg/kg **IBW**（肥胖患者安全关键） |
| **芬太尼** (Fentanyl) | 50 μg/mL | 诱导 1.0–2.0 μg/kg TBW（≥65 岁减半） |
| **瑞芬太尼** (Remifentanil) | 50 μg/mL | 诱导 1.0–2.0 μg/kg · 维持 0.1–0.5 μg/kg/min |
| **舒更葡萄糖钠** (Sugammadex) | 100 mg/mL | 拮抗 2.0–16.0 mg/kg **TBW**（按 TOF 深度分档） |

### 剂量计算引擎
- **双轨制**：AI 规则路径（`AIRuleEngine`）+ 传统规则回退路径（`DrugLibrary` / `CalculationEngine`）
- 支持三种体重基数：TBW（实际体重）、IBW（理想体重）、LBW（瘦体重）
- 年龄触发剂量削减（如 ≥65 岁丙泊酚 ×0.7、芬太尼 ×0.5）
- 绝对最大剂量安全上限钳制
- 丙泊酚专用计算器 & 儿科逻辑引擎（`PediatricLogic`）& 风险筛查引擎（`RiskEngine`）

### AI 辅助
- **AI 麻醉决策**：输入手术名称与患者情况，AI 生成结构化麻醉方案（术前评估、诱导方案、维持方案、拔管条件、术后镇痛、风险预案）
- **AI 药物规则获取**：输入药名，AI 自动查询临床剂量规则并返回结构化 DosageRule JSON
- **"麻了么"问答**：自由文本麻醉学知识问答
- 支持自定义 API 地址与模型（兼容 OpenAI 接口），三套独立系统提示词可自定义

### 药物管理
- **可见性开关**：每款药物可通过 Toggle 随时启用/隐藏，状态持久化到 UserDefaults
- **原生编辑模式**：点击 Edit 进入批量管理模式，红色删除圆点 + 滑动删除，Toggle 保持可操作
- **分类分组**：24 个临床分类（静脉全麻药、吸入麻醉药、肌松药、阿片类、血管活性药等）自动排序
- **双规则来源**：AI 生成规则 / 手动经验规则可随时切换，浓度可编辑

### 病例管理
- 一键归档当前患者信息（自动按住院号合并去重）
- 所有计算器内字段均可从历史病例导入
- 搜索、按日期筛选

## 技术架构

```
AnesthesiaCalc/
├── AnesthesiaCalcCore/         # Swift Package — 纯计算逻辑层
│   └── Sources/AnesthesiaCalcCore/
│       ├── AIEngine/           # AIAssistantService、AIRuleEngine
│       ├── DrugLibrary/        # AnesthesiaDrug、DosageRule、DrugCalculator
│       │                       # DrugCatalog (45 种)、DrugManager (持久化)
│       ├── Engine/             # CalculationEngine、PediatricLogic
│       │                       # PropofolCalculator、RiskEngine
│       └── Models/             # PatientContext、DoseUnit、ClinicalContext
├── AnesthesiaCalc/             # App Target — 纯 UI 展示层
│   └── AnesthesiaCalc/
│       ├── ContentView.swift          # 主计算器 + 分类分组
│       ├── UniversalDrugCardView.swift  # 通用药品卡片模板
│       ├── AIDecisionView.swift       # AI 麻醉方案生成
│       ├── MaLeMeView.swift           # "麻了么"问答
│       ├── SettingsView.swift         # 设置、药物管理、编辑模式
│       ├── CaseHistoryView.swift      # 病例历史
│       ├── QAHistoryView.swift        # 问答历史
│       ├── DrugDeepDiveView.swift     # 药品知识库详情
│       ├── DrugDeepDiveStore.swift    # 知识库数据层
│       ├── KnowledgeProvider.swift    # 知识检索
│       ├── ActiveMonitorView.swift    # 术中监测
│       ├── ConsultView.swift          # 会诊视图
│       └── ClinicalContext.swift      # 临床上下文
└── Architecture.md / Harness.md / CLAUDE.md  # 项目治理文档
```

### 架构红线
- **Core 层**：仅 `import Foundation`，零 UI 依赖，零视觉属性
- **UI 层**：零药物数学公式（`weight * dose / concentration` 等），所有计算均委托 Core 公开 API
- 数据流：`PatientContext` → `DrugCalculator.calculateDose(...)` → `DrugDoseRange` → View 渲染

### 关键类型
- `PatientContext` — 患者快照（TBW/IBW/LBW/BMI，线程安全值类型）
- `DosageRule` — 可替换的剂量规则（含 `doseType`、`doseInterval`、`weightBase`、龄调整）
- `DrugDoseRange` — 标准化计算结果（含体积、流速、体重基准、钳制标记等）
- `AnesthesiaDrug` — 药物实体（双规则集 AI+手动、可见性状态、浓度）
- `DrugManager` — 单例持久化管理器（`@Published allDrugs`，JSON → UserDefaults）
- `RuleSource` — 规则来源枚举（`.ai` / `.manual`），驱动卡片显示切换

## 平台要求

- iOS 16.0+ / macOS 13.0+
- Swift 5.9
- Xcode 16+

## 构建

```bash
# 打开 Xcode 项目
open AnesthesiaCalc/AnesthesiaCalc.xcodeproj

# 或单独构建与测试 Core 包
cd AnesthesiaCalcCore
swift build
swift test
```

## 免责声明

本应用仅供医疗专业人员临床参考使用，不构成任何医疗建议。所有剂量应在给药前根据患者个体情况、最新指南及药品说明书进行独立核实。开发者不对因使用本应用而产生的任何临床决策后果承担责任。
