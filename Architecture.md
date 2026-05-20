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

## 6. 自动体重路由（DrugCatalog 驱动）
- `RiskEngine.resolveWeightBase(drugName:bmi:)` 不再硬编码单个药名。
- 改为查询 `DrugCatalog.category(for:)`，匹配**药理分类字符串**（"神经肌肉阻滞药""阿片类镇痛药"）。
- 新增药物只需加入 `DrugCatalog` 即可自动获得正确的体重路由，无需修改 `RiskEngine`。

## 7. 患者类型归一（Patient 中间类型已删除）
- 原三层 `ClinicalContext → Patient → PatientContext` 简化为 `PatientContext` 直通。
- `PatientContext.resolvedWeight(for:)` 方法统一处理 TBW/IBW/LBW 解析。
- Core 所有计算器直接接收 `PatientContext`，零中间跳转。

## 8. 新模块隔离（围术期辅助决策）
- 五个新模块（气道/ABL/液体/预案/ABG）均为**独立的 Core 枚举引擎 + SwiftUI 视图**。
- 每个引擎 `import Foundation` only，接收各自独立的 Input struct，返回 Output struct。
- 与已有 `RiskEngine`、`DrugCalculator` 无耦合，通过 `ClinicalContext.shared` 共享患者数据。

## 9. AI 接口优化
- 默认模型 `deepseek-chat` (Flash)，不再默认 `gpt-4o-mini`。
- 药物规则请求携带 `response_format: { type: "json_object" }` 减少思考开销。
- 系统提示词压缩 65%，doseType 值域改为英文 (induction/maintenance/...) 与代码库一致。
