# 核心架构蓝图 (Architecture Blueprint)

## 目录与职责划分
1. `/Core/Calculators/` 
   - 职责：仅负责纯粹的医学公式与剂量计算。
   - 依赖限制：绝对禁止包含 UI 代码（如 SwiftUI/UIKit 引用）。
2. `/UI/Views/`
   - 职责：仅负责界面展示与用户交互。
   - 依赖限制：只允许调用 Core 传来的计算结果，禁止在本地 View 文件内进行二次医学数据逻辑计算。
3. `/Models/`
   - 职责：定义通用的数据结构。