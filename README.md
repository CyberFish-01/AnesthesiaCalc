# AnesthesiaCalc — 麻醉用药剂量计算器

一款面向麻醉科医师的 iOS 辅助应用。输入患者体重、身高、年龄、性别后，自动计算临床常用麻醉药物的诱导与维持剂量区间，并提供 AI 辅助麻醉方案生成能力。

## 功能概览

### 计算器（主屏）
- 输入患者基本信息：体重 (kg)、身高 (cm)、年龄、性别
- 自动推导 IBW（理想体重，Devine 公式）、LBW（瘦体重，Boer 公式）、BMI
- 以横向卡片形式展示全部药物的剂量计算结果
- 每张卡片支持切换剂量类型（诱导 / 维持 / 镇静 / 镇痛等），实时刷新
- 全局单列布局，纯白卡片 + 细微弥散阴影，视觉整齐一致

### 内置药物与剂量规则

| 药物 | 浓度 | 诱导 | 维持 / 其他 |
|------|------|------|------------|
| **丙泊酚** (Propofol) | 10 mg/mL | 1.5 – 2.5 mg/kg TBW | 4.0 – 12.0 mg/kg/h (维持) · 0.5 – 4.0 mg/kg/h (镇静) |
| **罗库溴铵** (Rocuronium) | 10 mg/mL | 0.6 mg/kg **IBW**（肥胖患者安全关键规则） | — |
| **芬太尼** (Fentanyl) | 50 μg/mL | 1.0 – 2.0 μg/kg TBW（≥65 岁减半） | — |
| **瑞芬太尼** (Remifentanil) | 50 μg/mL | 1.0 – 2.0 μg/kg TBW | 0.1 – 0.5 μg/kg/min (维持) · 0.05 – 0.2 μg/kg/min (镇痛) |

### 剂量计算引擎
- **双轨制**：AI 规则路径（`AIRuleEngine`）+ 传统规则回退路径（`DrugLibrary` / `CalculationEngine`）
- 支持三种体重基数：TBW（实际体重）、IBW（理想体重）、LBW（瘦体重）
- 年龄触发剂量削减（如 ≥65 岁丙泊酚 ×0.7、芬太尼 ×0.5）
- 绝对最大剂量安全上限钳制
- 丙泊酚专用计算器（`PropofolCalculator`）：纯 TBW，零额外变量，适用简单快速估算

### AI 辅助
- **AI 麻醉决策**：输入手术名称与患者情况，AI 生成结构化麻醉方案（术前评估、诱导方案、维持方案、拔管条件、术后镇痛、风险预案）
- **AI 药物规则获取**：为药品库动态添加 AI 生成的剂量规则，支持中文剂量类型（如"诱导""维持"）
- **"麻了么"问答**：自由文本麻醉学知识问答
- 支持自定义 API 地址与模型（兼容 OpenAI 接口）

### 病例管理
- 一键归档当前患者信息（自动按住院号合并去重）
- 所有计算器内字段均可从历史病例导入
- 搜索、按日期筛选

### 设置
- 药物列表管理（查看药品、切换规则来源 AI / 手动）
- AI API 配置（地址、密钥、模型名称）
- 三套独立系统提示词可自定义（决策 / 药物规则 / 问答）

## 技术架构

```
AnesthesiaCalc/
├── AnesthesiaCalcCore/         # Swift Package — 纯计算逻辑层
│   └── Sources/
│       ├── Calculators/        # 专用药物计算器（PropofolCalculator）
│       ├── AIEngine/           # AI 规则引擎 + API 服务
│       ├── DrugLibrary/        # 药物实体、计算器、规则目录、管理器
│       ├── Engine/             # 传统计算引擎
│       └── Models/             # DrugRule、PatientContext、DoseUnit 等核心类型
├── AnesthesiaCalc/             # App Target — 纯 UI 展示层
│   └── AnesthesiaCalc/
│       ├── ContentView.swift        # 主计算器
│       ├── UniversalDrugCardView.swift  # 通用药品卡片模板
│       ├── AIDecisionView.swift     # AI 麻醉方案生成
│       ├── MaLeMeView.swift         # "麻了么"问答
│       ├── SettingsView.swift       # 设置与药物管理
│       ├── CaseHistoryView.swift    # 病例历史
│       ├── QAHistoryView.swift      # 问答历史
│       └── ...
└── Architecture.md / Harness.md / CLAUDE.md  # 项目治理文档
```

### 架构红线
- **Core 层**：仅 `import Foundation`，零 UI 依赖，零视觉属性
- **UI 层**：零药物数学公式（`weight * dose / concentration` 等），所有计算均委托 Core 公开 API
- 数据流：`PatientContext` → `DrugCalculator.calculateDose(...)` → `DrugDoseRange` → View 渲染

### 关键类型
- `PatientContext` — 患者快照（TBW/IBW/LBW/BMI，线程安全值类型）
- `DrugRule` / `DosageRule` — 可替换的剂量规则（支持 AI 动态更新）
- `DrugDoseRange` — 标准化计算结果（含体积、流速、体重基准、钳制标记等）
- `DoseUnit.displayValue` — 内部存储 `mcg` 以保证 AI JSON 兼容性，展示层自动映射为 `μg` 节省横向空间

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
