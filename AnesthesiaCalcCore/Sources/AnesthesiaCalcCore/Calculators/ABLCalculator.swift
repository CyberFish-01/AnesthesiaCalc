import Foundation

// MARK: - ABLInput

public struct ABLInput: Equatable {
    public let weightKg: Double
    public let sex: BiologicalSex
    public let isPregnant: Bool
    public let age: Int                        // 用于判断儿童血容量系数
    public let preoperativeHct: Double         // 0.30–0.55
    public let preoperativeHb: Double          // g/L
    public let targetHct: Double               // 默认 0.25，心血管病 0.30
    public let targetHb: Double                // 默认 70 g/L

    public init(
        weightKg: Double,
        sex: BiologicalSex,
        isPregnant: Bool = false,
        age: Int = 40,
        preoperativeHct: Double,
        preoperativeHb: Double,
        targetHct: Double = 0.25,
        targetHb: Double = 70
    ) {
        self.weightKg = weightKg
        self.sex = sex
        self.isPregnant = isPregnant
        self.age = age
        self.preoperativeHct = preoperativeHct
        self.preoperativeHb = preoperativeHb
        self.targetHct = targetHct
        self.targetHb = targetHb
    }
}

// MARK: - ABLResult

public struct ABLResult: Equatable {
    public let estimatedBloodVolume: Double       // mL
    public let allowableBloodLoss: Double          // mL (基于 Hct)
    public let allowableBloodLossHb: Double        // mL (基于 Hb)
    public let rbcTransfusionTrigger: Double       // 开始输血阈值 (失血量 mL)
    public let ffpTransfusionTrigger: Double       // 开始 FFP 阈值
    public let bloodLossAsPercentage: Double       // ABL/EBV × 100%
    public let formulaTrace: String
}

// MARK: - ABLCalculator

/// 允许失血量计算器 — 基于 EBV 和术前/目标 Hct。
///
/// 引用 2025 中国围术期输血指南。
public enum ABLCalculator {

    /// 计算允许失血量
    public static func calculate(_ input: ABLInput) -> ABLResult {
        // 防御：术前 Hct/Hb 为 0 时直接返回空结果
        guard input.preoperativeHct > 0, input.preoperativeHb > 0 else {
            return ABLResult(
                estimatedBloodVolume: 0,
                allowableBloodLoss: 0,
                allowableBloodLossHb: 0,
                rbcTransfusionTrigger: 0,
                ffpTransfusionTrigger: 0,
                bloodLossAsPercentage: 0,
                formulaTrace: "术前 Hct/Hb 无效"
            )
        }

        // 1. 估算血容量 (EBV)
        let ebvCoef: Double
        if input.age < 2 {
            ebvCoef = 85   // 新生儿/婴儿
        } else if input.age < 12 {
            ebvCoef = 80   // 儿童
        } else if input.sex == .male {
            ebvCoef = 70
        } else {
            ebvCoef = input.isPregnant ? 65 * 1.2 : 65  // 妊娠上调 20%
        }

        let ebv = input.weightKg * ebvCoef

        // 2. 允许失血量 (ABL)
        let abl = ebv * (input.preoperativeHct - input.targetHct) / input.preoperativeHct
        let ablHb = ebv * (input.preoperativeHb - input.targetHb) / input.preoperativeHb

        // 3. 输血指征
        let rbcTrigger = abl     // Hb<70 或同等失血量 → 开始输血
        let ffpTrigger = abl * 1.5  // MTP 激活阈值

        // 4. 公式溯源
        let trace = "EBV=\(String(format: "%.0f", input.weightKg))×\(String(format: "%.0f", ebvCoef))=\(String(format: "%.0f", ebv))mL | ABL=\(String(format: "%.0f", ebv))×(\(String(format: "%.2f", input.preoperativeHct))-\(String(format: "%.2f", input.targetHct)))/\(String(format: "%.2f", input.preoperativeHct))"

        return ABLResult(
            estimatedBloodVolume: ebv,
            allowableBloodLoss: abl,
            allowableBloodLossHb: ablHb,
            rbcTransfusionTrigger: rbcTrigger,
            ffpTransfusionTrigger: ffpTrigger,
            bloodLossAsPercentage: (abl / ebv) * 100,
            formulaTrace: trace
        )
    }
}
