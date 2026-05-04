# Project_Status — AnesthesiaCalc

> 最后更新: 2026-05-04

## 1. 项目概览

麻醉药物剂量计算 iOS 应用（Swift 5.9，iOS 16+ / macOS 13+）。双模块架构：纯逻辑层 `AnesthesiaCalcCore` + UI 层 `AnesthesiaCalc`。

## 2. 目录结构

```
AnesthesiaCalc/
├── AnesthesiaCalc.xcodeproj              # Xcode 项目 (PBXFileSystemSynchronizedRootGroup)
├── AnesthesiaCalcCore/                   # Swift Package — 纯计算逻辑
│   ├── Package.swift
│   ├── Sources/AnesthesiaCalcCore/
│   │   ├── Calculators/
│   │   │   └── PropofolCalculator.swift  # [NEW] 丙泊酚专用计算器
│   │   ├── AIEngine/
│   │   │   ├── AIAssistantService.swift  # OpenAI 兼容 API，获取 AI 药物规则
│   │   │   └── AIRuleEngine.swift        # 线程安全规则引擎，含默认 DosageRule 库
│   │   ├── DrugLibrary/
│   │   │   ├── AnesthesiaDrug.swift      # 药物实体 (Identifiable, Codable)
│   │   │   ├── DrugCalculator.swift      # 主计算服务 (AI 路径 + 旧版回退)
│   │   │   ├── DrugLibrary.swift         # 旧版 DrugRule 静态目录
│   │   │   └── DrugManager.swift         # ObservableObject 单例，管理药物列表
│   │   ├── Engine/
│   │   │   └── CalculationEngine.swift   # 旧版纯计算引擎 (DrugRule → DoseResult)
│   │   └── Models/
│   │       ├── DrugRule.swift            # DrugRule, DoseRange, WeightBase, DoseUnit 等核心类型
│   │       └── PatientContext.swift      # 患者快照 (TBW/IBW/LBW/BMI, Devine/Boer 公式)
│   └── Tests/AnesthesiaCalcCoreTests/
│       ├── AIRuleEngineTests.swift
│       ├── CalculationEngineTests.swift
│       ├── DrugCalculatorTests.swift
│       └── PatientContextTests.swift
├── AnesthesiaCalc/AnesthesiaCalc/        # App Target — 纯 UI
│   ├── AnesthesiaCalcApp.swift           # @main 入口
│   ├── MainTabView.swift                 # 4 Tab 根视图 (.ultraThinMaterial tab bar)
│   ├── ContentView.swift                 # 主计算器视图 (病人卡片 + DrugCard 列表)
│   ├── PropofolCardView.swift            # [NEW] 丙泊酚卡片 (Liquid Glass 模板)
│   ├── CalculatorViewModel.swift         # @Observable VM (尚未接入 View)
│   ├── AIDecisionView.swift              # AI 麻醉方案生成
│   ├── DirectorLoadingView.swift         # 全屏 Liquid Glass AI 等待动画
│   ├── MaLeMeView.swift                  # 医疗 Q&A 聊天
│   ├── SettingsView.swift                # 设置 + 药物管理 + AI 配置
│   ├── CaseHistoryView.swift             # 病例历史列表
│   ├── CaseRecord.swift                  # CaseRecord 模型 + HistoryManager
│   ├── QAHistoryView.swift               # Q&A 对话历史
│   └── QARecord.swift                    # QARecord 模型 + QAHistoryManager
├── Architecture.md                       # 架构蓝图
├── Harness.md                            # 自动审查与熔断机制
└── CLAUDE.md                             # 全局智能体执行规范
```

## 3. 核心架构

### 3.1 模块边界（红线）

```
┌──────────────────────────────────────────────┐
│  AnesthesiaCalc (UI)                          │
│  - SwiftUI Views                              │
│  - 只能调用 Core 暴露的 public API             │
│  - 禁止在 View 内做任何医学数学计算             │
│  - Liquid Glass 毛玻璃 + 20pt 圆角             │
├──────────────────────────────────────────────┤
│  AnesthesiaCalcCore (纯逻辑)                   │
│  - import Foundation  ONLY                    │
│  - 零 UI 框架依赖 (无 SwiftUI/UIKit)            │
│  - 全部类型为 public value-type / enum        │
│  - 线程安全，无副作用                          │
└──────────────────────────────────────────────┘
```

### 3.2 计算路径（双轨制）

| 路径 | 入口 | 规则来源 | 适用 |
|------|------|---------|------|
| **新 AI 路径** | `DrugCalculator.calculateDose(patient:drug:doseType:)` | `AIRuleEngine` → `DosageRule` | 所有药物，支持输液 |
| **旧版回退** | `DrugCalculator.calculateLegacyDose(patient:drug:)` | `DrugLibrary` → `DrugRule` → `CalculationEngine` | 4 个内置药物 |
| **专用计算器** | `PropofolCalculator.*` | 硬编码常量 (TBW only) | 丙泊酚，UI 模板卡片 |

### 3.3 核心类型链

```
PatientContext (TBW, IBW, LBW, BMI, age, sex)
    ↓
WeightBase (.totalBodyWeight / .idealBodyWeight / .leanBodyWeight)
    ↓
DrugRule { weightBase, doseRange (per kg), concentrationMgPerMl, ageAdjustments[], doseUnit }
    ↓
CalculationEngine.calculate(rule:patient:) → DoseResult { minMg, maxMg, minMl, maxMl, display... }
```

## 4. 丙泊酚模块 (本轮新建/重构)

### 4.1 PropofolCalculator (`Core/Calculators/`)

纯数学枚举，仅基于 **TBW**，不含年龄调整或任何额外变量：

| 常量 | 值 | 说明 |
|------|-----|------|
| `defaultConcentration` | 10.0 mg/mL | Diprivan 1% |
| `inductionMinMgPerKg` | 1.5 mg/kg | 诱导下限 |
| `inductionMaxMgPerKg` | 2.5 mg/kg | 诱导上限 |
| `maintenanceMinMgPerKgPerH` | 4.0 mg/kg/h | 维持下限 |
| `maintenanceMaxMgPerKgPerH` | 12.0 mg/kg/h | 维持上限 |

| 方法 | 输入 | 输出 |
|------|------|------|
| `calculateInduction(weight:concentration:)` | TBW + 浓度 | `PropofolInductionResult` (min/max mg, min/max mL) |
| `calculateMaintenance(weight:concentration:)` | TBW + 浓度 | `PropofolMaintenanceResult` (min/max mg/h, min/max mL/h) |
| `pumpRate(weight:doseRateMgPerKgPerH:concentration:)` | TBW + 目标速率 + 浓度 | `Double` mL/h |

### 4.2 PropofolCardView (`AnesthesiaCalc/`)

Liquid Glass 卡片模板，固定 200pt 高度。全部计算委托 `PropofolCalculator`：

- **顶部**: 药品名 (primary) + "维持" Tag (accentColor 浅底胶囊)
- **诱导行**: 紧凑次要 (`105 – 175 mg` / `10.5 – 17.5 mL`)
- **核心数值**: 34pt 圆体 `.accentColor` (`28.0 mL/h`)
- **范围提示**: `.caption2` + `.secondary`
- **微量泵入口**: 点击弹出 Bottom Sheet (`presentationDetents: .height(160)`) 内含滑块 (4.0–12.0 mg/kg/h, step 0.1)
- **图标**: `drop.fill` (微量泵), `cross.case.fill` (药物), `chevron.up.chevron.down` (展开)

## 5. UI 设计系统

| 属性 | 规范值 |
|------|--------|
| 卡片材质 | `.ultraThinMaterial` (Liquid Glass 毛玻璃) |
| 卡片圆角 | 20pt (`RoundedRectangle(cornerRadius: 20)`) |
| 图标 | SF Symbols 单色线条风格 (`.fill` 变体仅做单色渲染) |
| 字号层级 | 34pt 圆体 (核心值) / headline (标题) / caption (次级标签) / caption2 (范围提示) |
| 强调色 | `.accentColor` (iOS 系统蓝) |
| 文字对比度 | `.primary` (纯黑/白) / `.secondary` (浅灰) |
| 卡片高度 | 固定 200pt（所有药品卡片严格统一） |
| 交互控件 | 滑块置于半屏 Bottom Sheet，卡片内零动态高度变化 |

## 6. 关键架构规则（来自 Architecture.md / Harness.md）

1. **物理隔离**: View 文件零数学公式，Calculator 文件零 UI 引用
2. **幻觉阻断**: 所有计算收敛于 TBW 等通用基数，禁止自行推演额外变量
3. **熔断机制**: 同一模块连续 3 次失败 → 强制回滚 → 输出《逻辑崩塌分析报告》
4. **关注点分离**: UI 调 Core，Core 不调 UI
5. **单色极简**: 无多余内边距、无多彩图标、高对比度数值

## 7. 当前状态

- [x] 核心计算层：10 个源文件，57 个测试 (4 个预先存在的 IBW/LBW 精度偏差)
- [x] 丙泊酚计算器：新建完成，构建通过，物理隔离通过
- [x] 丙泊酚卡片：重构完成，Liquid Glass 模板，固定高度，Bottom Sheet 滑块
- [ ] 其他药物卡片未按模板统一
- [ ] CalculatorViewModel 未接入 View
- [ ] 旧版 DrugLibrary.propofol 含年龄调整 (>65 ×0.7)，与新 PropofolCalculator 逻辑不一致，需决策是否统一
