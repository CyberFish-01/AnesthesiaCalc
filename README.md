# AnesthesiaCalc — 围术期辅助决策系统

一款面向麻醉科医师的 iOS 辅助应用。涵盖麻醉用药剂量计算、气道评估、液体管理、血气分析、紧急预案速查，并提供 AI 辅助麻醉方案生成能力。

## 功能概览

### 计算器（主屏）
- 输入患者基本信息：体重 (kg)、身高 (cm)、年龄、性别
- 自动推导 IBW（理想体重，Devine 公式）、LBW（瘦体重，Boer 公式）、BMI
- **45 种药物 × 24 个类别**分类展示，每张卡片支持切换剂量类型（诱导 / 维持 / 镇静 / 镇痛 / 插管 / 拮抗），实时刷新
- **儿科模式**：Age < 12 且 Weight < 35kg 自动触发，强制两位小数精度、字体放大 24pt
- **微量泵矩阵**：非推注类药物自动展示 0.8× / 1.0× / 1.2× 剂量率 → mL/h 流速映射
- 全局单列布局，系统分组背景卡片 + 分隔线描边，视觉整齐一致

### 围术期辅助决策（新增）

#### 🫁 气道评估
- **6 维 Mallampati 综合评分**：Mallampati 分级、张口度 (cm)、甲颏距 (cm)、颈部后仰、咬上唇试验 (ULBT)、牙列风险
- **4 项附加风险因子**：胡须、鼾症/OSA、已知困难气道史、颈部放疗史、妊娠
- **OBESE 特殊路径**：BMI ≥ 30 自动触发肥胖气道评估子路径
- 综合风险分级（低/中/高/极高）+ 临床建议

#### 🩸 允许失血量 (ABL) + 输血指征
- 输入术前 Hct / 目标 Hct，自动计算最大允许失血量
- 按体重、性别、年龄自动估算血容量
- 基于 Hct/Hb 双轨的输血阈值判断
- 紧凑卡片展示，一键展开详细计算过程

#### 💧 液体管理 (4-2-1 法则)
- 禁食缺失量 + 生理需要量 (4-2-1 法则) + 第三间隙丢失量
- 手术类型选择（浅表/中等/重大），自动调整第三间隙系数
- 分时流速规划（第 1 小时补半量 + 生理量，后续小时补余量）
- 总液体计划量一览

#### 🚨 紧急预案速查
- **6 套紧急预案**：过敏性休克、恶性高热、局麻药中毒 (LAST)、困难气道、大出血、心脏骤停
- 基于患者体重预计算药物剂量（肾上腺素、丹曲林、脂肪乳剂等）
- 预案含识别要点、即时措施、药物方案、后续处理
- 搜索过滤、展开/折叠，术中零等待

#### 🩻 血气分析 (ABG)
- 输入 pH / PaCO₂ / PaO₂ / HCO₃⁻ / BE，自动判定酸碱失衡类型
- Winter 公式验证代偿（急性/慢性呼吸性酸中毒/碱中毒）
- AG 阴离子间隙 + Δ-Δ 高阶代酸鉴别（可选 Na⁺/Cl⁻）
- A-aDO₂ 肺泡-动脉氧分压差计算（可选 FiO₂ 输入）
- 乳酸升高提示

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

### 数据流与状态治理 (Single Source of Truth)

所有患者核心体征（姓名、住院号、体重、身高、年龄、性别）统一由 `ClinicalContext.shared` 以 `@Published` 持有并广播。各视图通过 `@ObservedObject` 直接绑定，**彻底废弃**各视图私有的 `@State` 变量。这确保了计算器、AI 决策、会诊、问答四个页面间的患者数据绝对同步。

```
ClinicalContext.shared (Single Source of Truth, @Published)
  └─→ PatientContext (统一患者值类型)
        └─→ DrugCalculator.calculateDose(...)
              └─→ DrugDoseRange (标准化结果，含体积/流速/体重基准)
                    └─→ View 渲染
```

```
AnesthesiaCalc/
├── AnesthesiaCalcCore/              # Swift Package — 纯计算逻辑层
│   └── Sources/AnesthesiaCalcCore/
│       ├── AIEngine/                # AIAssistantService、AIRuleEngine（26 条规则）
│       ├── Calculators/             # [NEW] 5 个独立计算引擎
│       │   ├── ABGAnalyzer.swift              # 血气分析器 (Winter/AG/A-aDO₂)
│       │   ├── ABLCalculator.swift            # 允许失血量计算器
│       │   ├── AirwayAssessmentEngine.swift   # 气道评估引擎 (6维+OBESE)
│       │   ├── FluidManagementCalculator.swift # 液体管理 (4-2-1+第三间隙)
│       │   └── PropofolCalculator.swift       # 丙泊酚专用计算器
│       ├── DrugLibrary/             # AnesthesiaDrug、DrugCalculator、DrugCatalog
│       │                           # DrugManager (持久化)、DrugLibrary (已弃用)
│       ├── Engine/                  # CalculationEngine (已弃用)、EmergencyProtocolEngine
│       │                           # PediatricLogic、RiskEngine
│       └── Models/                  # PatientContext、DrugRule
├── AnesthesiaCalc/                  # App Target — 纯 UI 展示层
│   └── AnesthesiaCalc/
│       ├── ContentView.swift              # 主计算器 + 气道/ABL/液体卡片 + 药物列表
│       ├── UniversalDrugCardView.swift    # 通用药品卡片模板
│       ├── AirwayCardView.swift           # [NEW] 气道评估卡片 + Sheet
│       ├── ABLCardView.swift              # [NEW] ABL 紧凑卡片
│       ├── FluidCardView.swift            # [NEW] 液体管理卡片
│       ├── ABGTabView.swift               # [NEW] 血气分析独立 Tab
│       ├── EmergencySheetView.swift       # [NEW] 紧急预案 Sheet (可搜索)
│       ├── ClinicalContext.swift          # 全局临床上下文 (SSOT)
│       ├── AIDecisionView.swift           # AI 麻醉方案生成
│       ├── MaLeMeView.swift               # "麻了么"问答
│       ├── MainTabView.swift              # 5 Tab 导航 (计算/决策/问答/血气/设置)
│       ├── SettingsView.swift             # 设置、药物管理、编辑模式
│       ├── CaseHistoryView.swift          # 病例历史
│       ├── ActiveMonitorView.swift        # 术中监测
│       └── ConsultView.swift              # 会诊视图
└── Architecture.md / Harness.md / CLAUDE.md  # 项目治理文档
```

### 架构红线
- **Core 层**：仅 `import Foundation`，零 UI 依赖，零视觉属性。含除零保护 (`concentrationMgPerMl > 0` guard)。
- **UI 层**：零药物数学公式（`weight * dose / concentration` 等），所有计算均委托 Core 公开 API
- **状态归一**：患者数据仅存于 `ClinicalContext.shared`，视图间通过 `@ObservedObject` 订阅，无状态孤岛

### 关键类型
- `ClinicalContext` — 全局临床上下文单例 (`ObservableObject`)，持有 String-backed TextField 绑定与规范化 Double 值，跨页面广播
- `PatientContext` — 患者完整画像（TBW/IBW/LBW/BMI 计算，Devine/Boer 公式），Core 与 UI 层统一使用的唯一患者值类型
- `DosageRule` — 可替换的剂量规则（含 `doseType`、`doseInterval`、`weightBase`、龄调整，含 `precondition` 约束）
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

## 最近更新 (2026-05-21)

### 围术期辅助决策系统
- **5 个新 Core 引擎**：气道评估 (AirwayAssessmentEngine)、允许失血量 (ABLCalculator)、液体管理 (FluidManagementCalculator)、紧急预案 (EmergencyProtocolEngine)、血气分析 (ABGAnalyzer)
- **5 个对应 UI 视图**：AirwayCardView、ABLCardView、FluidCardView、EmergencySheetView、ABGTabView
- **42 个新单元测试**（Core 层总计 99 个测试）
- MainTabView 3→5 Tab 导航

### 架构改良
- Patient 中间类型删除，三层简化为 ClinicalContext → PatientContext 直通
- RiskEngine 去硬编码：改用 DrugCatalog.category(for:) 驱动体重路由
- AI 优化：默认模型→deepseek-chat、提示词 -65%、response_format json_object、timeout 60s
- 双规则体系弃用标注：CalculationEngine + DrugLibrary 标记 deprecated
- App 图标适配 iOS 18+ 深色/浅色模式
- 键盘工具栏"完成"按钮

## 免责声明

本应用仅供医疗专业人员临床参考使用，不构成任何医疗建议。所有剂量应在给药前根据患者个体情况、最新指南及药品说明书进行独立核实。开发者不对因使用本应用而产生的任何临床决策后果承担责任。
