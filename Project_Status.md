# Project_Status — AnesthesiaCalc

> 最后更新: 2026-05-21

## 1. 项目概览

麻醉药物剂量计算 + 围术期辅助决策 iOS 应用（Swift 5.9，iOS 16+ / macOS 13+）。
双模块架构：纯逻辑层 `AnesthesiaCalcCore` + UI 层 `AnesthesiaCalc`。

**本轮新增**：气道评估、允许失血量 (ABL) + 输血指征、液体管理 (4-2-1)、紧急预案速查、ABG 血气分析 — 5 个 Core 引擎 + 5 个 UI 视图。

## 2. 目录结构

```
AnesthesiaCalc/
├── AnesthesiaCalc.xcodeproj                    # Xcode 项目 (PBXFileSystemSynchronizedRootGroup)
├── AnesthesiaCalcCore/                         # Swift Package — 纯计算逻辑
│   ├── Package.swift
│   ├── Sources/AnesthesiaCalcCore/
│   │   ├── Calculators/
│   │   │   ├── AirwayAssessmentEngine.swift    # [NEW] 气道评估引擎 (6维评分+OBESE)
│   │   │   ├── ABLCalculator.swift             # [NEW] 允许失血量计算器
│   │   │   ├── FluidManagementCalculator.swift # [NEW] 液体管理计算器 (4-2-1+第三间隙)
│   │   │   ├── ABGAnalyzer.swift               # [NEW] 血气分析器 (Winter/AG/A-aDO₂)
│   │   │   └── PropofolCalculator.swift        # 丙泊酚专用计算器
│   │   ├── AIEngine/
│   │   │   ├── AIAssistantService.swift        # OpenAI 兼容 API (已优化提示词+response_format)
│   │   │   └── AIRuleEngine.swift              # 线程安全规则引擎，含 46 条默认 DosageRule
│   │   ├── DrugLibrary/
│   │   │   ├── AnesthesiaDrug.swift            # 药物实体 (双规则源)
│   │   │   ├── DrugCalculator.swift            # 主计算服务 (AI 路径 + 旧版回退)
│   │   │   ├── DrugCatalog.swift               # 45 种药物分类目录 (RiskEngine 复用)
│   │   │   ├── DrugLibrary.swift               # 旧版 DrugRule 静态目录 (已弃用标注)
│   │   │   └── DrugManager.swift               # ObservableObject 单例
│   │   ├── Engine/
│   │   │   ├── CalculationEngine.swift         # 旧版计算引擎 (已弃用标注)
│   │   │   ├── EmergencyProtocolEngine.swift   # [NEW] 紧急预案引擎 (6套，体重预计算)
│   │   │   ├── PediatricLogic.swift            # 儿科模式判定
│   │   │   └── RiskEngine.swift                # 风险筛查+自动体重路由 (DrugCatalog驱动)
│   │   └── Models/
│   │       ├── DrugRule.swift                  # DrugRule, DoseRange, WeightBase, DoseUnit 等
│   │       └── PatientContext.swift            # 唯一患者值类型 (含 resolvedWeight)
│   └── Tests/AnesthesiaCalcCoreTests/
│       ├── AIRuleEngineTests.swift
│       ├── CalculationEngineTests.swift
│       ├── DrugCalculatorTests.swift
│       └── PatientContextTests.swift
├── AnesthesiaCalc/AnesthesiaCalc/              # App Target — 纯 UI
│   ├── AnesthesiaCalcApp.swift                 # @main 入口
│   ├── MainTabView.swift                       # 5 Tab (计算/决策/问答/血气/设置)
│   ├── ContentView.swift                       # 主计算器 + 气道/ABL/液体卡片 + 药物列表
│   ├── ClinicalContext.swift                   # 全局临床上下文 (SSOT)
│   ├── AirwayCardView.swift                    # [NEW] 气道评估卡片 + Sheet
│   ├── ABLCardView.swift                       # [NEW] ABL 紧凑卡片
│   ├── FluidCardView.swift                     # [NEW] 液体管理卡片
│   ├── ABGTabView.swift                        # [NEW] ABG 血气分析 Tab
│   ├── EmergencySheetView.swift                # [NEW] 紧急预案 Sheet (可搜索)
│   ├── UniversalDrugCardView.swift             # 通用药品卡片模板
│   ├── PropofolCardView.swift                  # 丙泊酚卡片
│   ├── AIDecisionView.swift                    # AI 麻醉方案生成
│   ├── MaLeMeView.swift                        # "麻了么" Q&A
│   ├── SettingsView.swift                      # 设置 + AI 配置 (已优化)
│   ├── CaseHistoryView.swift                   # 病例历史
│   ├── ConsultView.swift                       # 会诊视图
│   ├── ActiveMonitorView.swift                 # 术中监测
│   ├── DrugDeepDiveView.swift     \            # 药品知识库
│   └── (其他视图文件)
├── Architecture.md                             # 架构蓝图
├── Harness.md                                  # 自动审查与熔断
├── CLAUDE.md                                   # 全局执行规范
├── Feature_Requirements.md                     # [NEW] 新功能需求设计
├── Project_Status.md                           # 本文件
└── README.md                                   # 项目简介
```

## 3. 数据流

```
ClinicalContext.shared (SSOT, @Published)
  └─→ PatientContext (唯一患者值类型)
        ├─→ DrugCalculator.calculateDose(...)
        ├─→ AirwayAssessmentEngine.assess(...)
        ├─→ ABLCalculator.calculate(...)
        ├─→ FluidManagementCalculator.calculate(...)
        ├─→ EmergencyProtocolEngine.generateAll(...)
        └─→ ABGAnalyzer.analyze(...)
```

## 4. 架构改良（本轮完成）

| 改良 | 说明 |
|------|------|
| Patient 类型删除 | 三层简化为 ClinicalContext → PatientContext |
| RiskEngine 去硬编码 | DrugCatalog.category(for:) 替代 isMuscleRelaxant/isLipophilicOpioid |
| DosageRule.ageAdjustments | `[AgeAdjustment]?` → `[AgeAdjustment]` |
| ClinicalContext.sync(nil) | nil 时不再归零，仅同步 drugs |
| 双规则弃用标注 | CalculationEngine + DrugLibrary 标记 deprecated |
| AI 优化 | 提示词 -65%、模型→deepseek-chat、response_format、timeout 60s |

## 5. 计算路径一览

| 路径 | 入口 | 状态 |
|------|------|------|
| AI 剂量 | `DrugCalculator.calculateDose(patient:drug:)` | 主路径 |
| 旧版回退 | `DrugCalculator.calculateLegacyDose(patient:drug:)` | 已弃用 |
| 丙泊酚专用 | `PropofolCalculator.*` | 活跃 |
| 气道评估 | `AirwayAssessmentEngine.assess(exam:bmi:)` | **新增** |
| 允许失血量 | `ABLCalculator.calculate(_:)` | **新增** |
| 液体管理 | `FluidManagementCalculator.calculate(_:)` | **新增** |
| 紧急预案 | `EmergencyProtocolEngine.generateAll(for:)` | **新增** |
| 血气分析 | `ABGAnalyzer.analyze(_:)` | **新增** |

## 6. 当前状态

### 已完成
- [x] 核心计算引擎：15 个源文件，57 个测试
- [x] 45 种药物剂量计算
- [x] RiskEngine 改用 DrugCatalog 分类
- [x] Patient 中间类型删除
- [x] AI 优化 (提示词/模型/response_format)
- [x] 气道评估引擎 + UI
- [x] ABL 计算器 + UI
- [x] 液体管理计算器 + UI
- [x] 紧急预案引擎 + UI
- [x] ABG 血气分析器 + UI
- [x] MainTabView 3→5 Tab
- [x] Feature_Requirements.md

### 待完成
- [ ] 新模块单元测试 (5 个引擎 0 测试)
- [ ] 其他药物卡片未按模板统一
- [ ] CalculatorViewModel 未接入 View
- [ ] 双规则体系统一 (DrugRule → DosageRule)
- [ ] AIRuleEngine 默认规则 JSON 外置
- [ ] GDFT 动态指标 (SVV/PPV) 输入
- [ ] 麻醉记录单手动录入版

## 7. 平台要求

- iOS 16.0+ / macOS 13.0+
- Swift 5.9
- Xcode 16+ (PBXFileSystemSynchronizedRootGroup 自动同步源文件)

## 8. 免责声明

本应用仅供医疗专业人员临床参考使用，不构成任何医疗建议。
