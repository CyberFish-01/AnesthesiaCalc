# AnesthesiaCalc 系统架构决策记录 (ADR)

## 1. 数据源真理唯一 (Single Source of Truth)
- **状态归一**：彻底废弃各视图内部私有的 `@State` 患者数据变量。
- **全局上下文**：所有患者核心体征由 `ClinicalContext.shared` 统一接管，并使用 `@Published` 广播。依赖患者数据的视图必须通过 `@ObservedObject` 监听，确保跨页面数据绝对同步。

## 2. 软删除与硬删除的并行架构 (Visibility vs. Physical Deletion)
- **可见性控制 (Soft Delete)**：药物模型引入 `isActive` 状态。用户可通过开关隐藏未采购的药物，保持界面清爽且不丢失底层学术数据。
- **物理兜底 (Hard Delete)**：引入原生 `EditButton` 和 `.onDelete` 机制。专门用于彻底抹除 AI 生成的错误规则或产生幻觉的自定义药物。

## 3. 展开交互的状态隔离
- 当列表进入编辑模式时，必须强制锁定所有下拉详情 (`isExpanded = false`)，并屏蔽展开热区。日常模式与管理模式在交互层必须严格互斥。

## 4. 核心计算与 UI 的绝对隔离
- **Core 层**：仅 `import Foundation`，零 UI 依赖，零视觉属性。所有剂量公式、数学运算、单位转换在此层完成。
- **UI 层**：零药物数学公式，所有计算均委托 Core 公开 API。数据流：`PatientContext` → `DrugCalculator.calculateDose(...)` → `DrugDoseRange` → View 渲染。

## 5. 双轨规则体系
- **AI 规则路径**：`AIRuleEngine` + `DosageRule`，由 LLM 动态生成并注入，支持自定义 API 和模型。
- **手动规则路径**：`DrugLibrary` + `CalculationEngine` / `DrugRule`，静态编译的循证基线规则作为 fallback。
- 两种规则在 `AnesthesiaDrug` 中并行存在，用户可随时通过 `RuleSource` 切换。
