import Foundation

// MARK: - PropofolInductionResult

/// 丙泊酚诱导剂量计算结果（纯数据结构，零 UI 依赖）
public struct PropofolInductionResult: Equatable {
    public let minMg: Double
    public let maxMg: Double
    public let minMl: Double
    public let maxMl: Double
    public let weightKg: Double
}

// MARK: - PropofolMaintenanceResult

/// 丙泊酚维持剂量计算结果（纯数据结构，零 UI 依赖）
public struct PropofolMaintenanceResult: Equatable {
    /// 维持剂量范围 (mg/h)
    public let minMgPerH: Double
    public let maxMgPerH: Double
    /// 微量泵流速范围 (mL/h)
    public let minMlPerH: Double
    public let maxMlPerH: Double
    public let weightKg: Double
    public let concentrationMgPerMl: Double
}

// MARK: - PropofolCalculator

/// 丙泊酚专用计算器 — 纯数学逻辑，仅基于总体重 (TBW)。
///
/// 本计算器严格遵守以下边界：
/// - 只使用总体重 (TBW) 作为体重基数
/// - 不包含年龄调整、合并症修正等任何额外变量
/// - 不含任何 UI 库引用，仅依赖 Foundation
public enum PropofolCalculator {

    /// 默认制剂浓度 (mg/mL) — Diprivan® 1% / 丙泊酚 10 mg/mL
    public static let defaultConcentration = 10.0

    /// 诱导剂量范围 (mg/kg, TBW)
    public static let inductionMinMgPerKg = 1.5
    public static let inductionMaxMgPerKg = 2.5

    /// 维持剂量范围 (mg/kg/h, TBW)
    public static let maintenanceMinMgPerKgPerH = 4.0
    public static let maintenanceMaxMgPerKgPerH = 12.0

    // MARK: 诱导

    /// 计算丙泊酚诱导剂量
    /// - Parameters:
    ///   - weight: 患者总体重 (kg)
    ///   - concentration: 制剂浓度 (mg/mL)，默认 10.0
    /// - Returns: 诱导剂量结果 (mg 与 mL)
    public static func calculateInduction(
        weight: Double,
        concentration: Double = defaultConcentration
    ) -> PropofolInductionResult {
        precondition(weight > 0, "体重必须大于 0")
        precondition(concentration > 0, "浓度必须大于 0")

        let minMg = inductionMinMgPerKg * weight
        let maxMg = inductionMaxMgPerKg * weight

        return PropofolInductionResult(
            minMg: minMg,
            maxMg: maxMg,
            minMl: minMg / concentration,
            maxMl: maxMg / concentration,
            weightKg: weight
        )
    }

    // MARK: 维持

    /// 计算丙泊酚维持剂量及微量泵流速
    /// - Parameters:
    ///   - weight: 患者总体重 (kg)
    ///   - concentration: 制剂浓度 (mg/mL)，默认 10.0
    /// - Returns: 维持剂量结果 (mg/h 与 mL/h)
    public static func calculateMaintenance(
        weight: Double,
        concentration: Double = defaultConcentration
    ) -> PropofolMaintenanceResult {
        precondition(weight > 0, "体重必须大于 0")
        precondition(concentration > 0, "浓度必须大于 0")

        let minMgPerH = maintenanceMinMgPerKgPerH * weight
        let maxMgPerH = maintenanceMaxMgPerKgPerH * weight

        return PropofolMaintenanceResult(
            minMgPerH: minMgPerH,
            maxMgPerH: maxMgPerH,
            minMlPerH: minMgPerH / concentration,
            maxMlPerH: maxMgPerH / concentration,
            weightKg: weight,
            concentrationMgPerMl: concentration
        )
    }

    // MARK: 微量泵

    /// 按指定维持速率计算微量泵流速
    /// - Parameters:
    ///   - weight: 患者总体重 (kg)
    ///   - doseRateMgPerKgPerH: 目标维持速率 (mg/kg/h)，通常在 4.0–12.0 范围内
    ///   - concentration: 制剂浓度 (mg/mL)，默认 10.0
    /// - Returns: 微量泵流速 (mL/h)
    public static func pumpRate(
        weight: Double,
        doseRateMgPerKgPerH: Double,
        concentration: Double = defaultConcentration
    ) -> Double {
        precondition(weight > 0, "体重必须大于 0")
        precondition(doseRateMgPerKgPerH > 0, "维持速率必须大于 0")
        precondition(concentration > 0, "浓度必须大于 0")
        let mgPerH = doseRateMgPerKgPerH * weight
        return mgPerH / concentration
    }
}
