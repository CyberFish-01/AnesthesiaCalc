import Foundation

// MARK: - MallampatiClass

public enum MallampatiClass: String, CaseIterable {
    case i   = "I"
    case ii  = "II"
    case iii = "III"
    case iv  = "IV"
}

// MARK: - NeckExtensionGrade

public enum NeckExtensionGrade: String, CaseIterable {
    case normal    = "正常"
    case mild      = "轻度受限"
    case severe    = "重度受限"
}

// MARK: - ULBTClass

public enum ULBTClass: String, CaseIterable {
    case i   = "I"
    case ii  = "II"
    case iii = "III"
}

// MARK: - DentitionRisk

public enum DentitionRisk: String, CaseIterable {
    case edentulous       = "无牙"
    case normal           = "正常"
    case buckTeethOrLoose = "龅牙/松动"
}

// MARK: - AirwayRiskTier

public enum AirwayRiskTier: String {
    case low
    case moderate
    case high
}

// MARK: - AirwayPlan

public enum AirwayPlan: String {
    case standardMac       = "常规喉镜 (Macintosh)"
    case videolaryngoscope = "可视喉镜 (GlideScope / UE)"
    case awakeFiberoptic   = "清醒纤支镜插管"
    case surgicalAirway    = "备外科气道"
}

// MARK: - AirwayExam

public struct AirwayExam: Equatable {
    public let mallampati: MallampatiClass
    public let mouthOpeningCm: Double
    public let thyromentalDistanceCm: Double
    public let neckExtension: NeckExtensionGrade
    public let upperLipBite: ULBTClass
    public let dentition: DentitionRisk
    public let hasBeard: Bool
    public let snoresHeavily: Bool
    public let knownDifficultAirway: Bool
    public let isPregnant: Bool
    public let hasNeckRadiation: Bool
    public let hasOSA: Bool

    public init(
        mallampati: MallampatiClass,
        mouthOpeningCm: Double,
        thyromentalDistanceCm: Double,
        neckExtension: NeckExtensionGrade,
        upperLipBite: ULBTClass,
        dentition: DentitionRisk,
        hasBeard: Bool,
        snoresHeavily: Bool,
        knownDifficultAirway: Bool,
        isPregnant: Bool = false,
        hasNeckRadiation: Bool = false,
        hasOSA: Bool = false
    ) {
        self.mallampati = mallampati
        self.mouthOpeningCm = mouthOpeningCm
        self.thyromentalDistanceCm = thyromentalDistanceCm
        self.neckExtension = neckExtension
        self.upperLipBite = upperLipBite
        self.dentition = dentition
        self.hasBeard = hasBeard
        self.snoresHeavily = snoresHeavily
        self.knownDifficultAirway = knownDifficultAirway
        self.isPregnant = isPregnant
        self.hasNeckRadiation = hasNeckRadiation
        self.hasOSA = hasOSA
    }
}

// MARK: - AirwayRiskAssessment

public struct AirwayRiskAssessment: Equatable {
    public let score: Int
    public let riskTier: AirwayRiskTier
    public let predictedDifficultLaryngoscopy: Double
    public let predictedDifficultBMV: Double
    public let recommendation: AirwayPlan
    public let rationale: [String]
}

// MARK: - AirwayAssessmentEngine

public enum AirwayAssessmentEngine {

    /// 评估气道风险，基于 6 维度评分 + 独立加权 + OBESE 面罩通气预测。
    public static func assess(exam: AirwayExam, bmi: Double) -> AirwayRiskAssessment {
        var score = 0
        var rationale: [String] = []

        // 6 维度评分
        if exam.mallampati == .iii || exam.mallampati == .iv {
            score += 1
            rationale.append("Mallampati \(exam.mallampati.rawValue)")
        }
        if exam.mouthOpeningCm < 4.0 {
            score += 1
            rationale.append("张口度 \(String(format: "%.1f", exam.mouthOpeningCm)) cm (<4.0)")
        }
        if exam.thyromentalDistanceCm < 6.5 {
            score += 1
            rationale.append("甲颏距 \(String(format: "%.1f", exam.thyromentalDistanceCm)) cm (<6.5)")
        }
        if exam.neckExtension != .normal {
            score += 1
            rationale.append("颈活动度 \(exam.neckExtension.rawValue)")
        }
        if exam.upperLipBite != .i {
            score += 1
            rationale.append("上唇咬合 \(exam.upperLipBite.rawValue) 级")
        }
        if exam.knownDifficultAirway {
            score += 1
            rationale.append("既往困难气道史")
        }

        // 困难插管概率
        let laryngoscopyProb: Double = {
            switch score {
            case 0...1: return Double(score) * 0.15
            case 2:     return 0.40
            case 3:     return 0.65
            case 4:     return 0.80
            default:    return 0.92
            }
        }()

        // 独立加权（升档）
        var tierLifts = 0
        if exam.knownDifficultAirway && score <= 1 { tierLifts += 1 }
        if bmi > 35 {
            tierLifts += 1
            rationale.append("BMI \(String(format: "%.1f", bmi)) (>35)")
        }
        if exam.isPregnant {
            tierLifts += 1
            rationale.append("妊娠晚期气道水肿")
        }
        if exam.hasNeckRadiation {
            tierLifts += 1
            rationale.append("颈部放疗后组织纤维化")
        }

        let effectiveScore = min(score + tierLifts, 6)
        let riskTier: AirwayRiskTier = {
            if effectiveScore <= 1 { return .low }
            if effectiveScore == 2 { return .moderate }
            return .high
        }()

        // OBESE 面罩通气困难预测
        var bmvScore = 0
        if exam.hasBeard { bmvScore += 1 }
        if exam.hasOSA || exam.snoresHeavily { bmvScore += 1 }
        if exam.dentition == .buckTeethOrLoose { bmvScore += 1 }
        if bmi > 30 { bmvScore += 1 }

        let bmvDifficult = bmvScore >= 3
        let bmvProb: Double = {
            switch bmvScore {
            case 0:  return 0.05
            case 1:  return 0.15
            case 2:  return 0.35
            case 3:  return 0.60
            default: return 0.80
            }
        }()

        // 推荐方案
        let recommendation: AirwayPlan
        if riskTier == .high && bmvDifficult {
            recommendation = .surgicalAirway
            rationale.append("插管困难合并面罩通气困难，建议备外科气道")
        } else if riskTier == .high {
            recommendation = .awakeFiberoptic
        } else if riskTier == .moderate {
            recommendation = .videolaryngoscope
        } else {
            recommendation = .standardMac
        }

        return AirwayRiskAssessment(
            score: effectiveScore,
            riskTier: riskTier,
            predictedDifficultLaryngoscopy: laryngoscopyProb,
            predictedDifficultBMV: bmvProb,
            recommendation: recommendation,
            rationale: rationale
        )
    }
}
