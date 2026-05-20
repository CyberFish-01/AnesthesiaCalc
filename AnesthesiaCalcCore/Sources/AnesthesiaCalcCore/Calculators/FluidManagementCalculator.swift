import Foundation

// MARK: - SurgeryInvasiveness

public enum SurgeryInvasiveness: String, CaseIterable {
    case superficial   = "体表手术"
    case moderate      = "腔镜/小切口"
    case major         = "开腹/开胸"
    case severe        = "重大创伤/烧伤"
}

// MARK: - CrystalloidType

public enum CrystalloidType: String, CaseIterable {
    case lactatedRinger = "乳酸林格液"
    case acetateRinger  = "醋酸林格液"
    case normalSaline   = "生理盐水"
}

// MARK: - FluidInput

public struct FluidInput: Equatable {
    public let weightKg: Double
    public let fastingHours: Double
    public let surgeryType: SurgeryInvasiveness
    public let estimatedSurgeryMinutes: Int
    public let crystalloidType: CrystalloidType

    public init(
        weightKg: Double,
        fastingHours: Double = 8,
        surgeryType: SurgeryInvasiveness,
        estimatedSurgeryMinutes: Int = 120,
        crystalloidType: CrystalloidType = .lactatedRinger
    ) {
        self.weightKg = weightKg
        self.fastingHours = fastingHours
        self.surgeryType = surgeryType
        self.estimatedSurgeryMinutes = estimatedSurgeryMinutes
        self.crystalloidType = crystalloidType
    }
}

// MARK: - FluidPlan

public struct FluidPlan: Equatable {
    public let maintenanceRateMLPerH: Double
    public let fastingDeficitML: Double
    public let firstHourReplacementML: Double
    public let hourlyMaintenanceML: Double
    public let thirdSpaceRateMLPerH: Double
    public let hourlyTotalML: Double
    public let totalCrystalloidForCaseML: Double
    public let recommendedBolusML: Double
    public let formulaTrace: String
}

// MARK: - FluidManagementCalculator

/// 液体管理计算器 — 4-2-1 法则 + 第三间隙丢失。
public enum FluidManagementCalculator {

    /// 计算 4-2-1 法则下的生理维持量
    public static func maintenanceRate(weightKg: Double) -> Double {
        let w = weightKg
        let first10 = min(w, 10) * 4
        let next10  = max(0, min(w - 10, 10)) * 2
        let rest    = max(0, w - 20) * 1
        return first10 + next10 + rest
    }

    /// 第三间隙丢失速率 (mL/kg/h)
    public static func thirdSpaceRate(for surgery: SurgeryInvasiveness) -> Double {
        switch surgery {
        case .superficial: return 1.5
        case .moderate:    return 3.5
        case .major:       return 7.0
        case .severe:      return 9.0
        }
    }

    /// 计算完整液体管理方案
    public static func calculate(_ input: FluidInput) -> FluidPlan {
        let maintenance = maintenanceRate(weightKg: input.weightKg)
        let fastingDeficit = maintenance * input.fastingHours
        let firstHourBolus = fastingDeficit / 2

        let thirdSpace = thirdSpaceRate(for: input.surgeryType) * input.weightKg
        let hourlyTotal = maintenance + thirdSpace

        let surgeryHours = Double(input.estimatedSurgeryMinutes) / 60.0
        let totalCrystalloid = firstHourBolus + hourlyTotal * surgeryHours

        // 公式溯源
        let w = input.weightKg
        let first10 = min(w, 10) * 4
        let next10 = max(0, min(w - 10, 10)) * 2
        let rest = max(0, w - 20) * 1
        let trace = "4×\(String(format: "%.0f", min(w,10)))+2×\(String(format: "%.0f", min(max(w-10,0),10)))+1×\(String(format: "%.0f", max(w-20,0)))=\(String(format: "%.0f", maintenance)) mL/h | 3rd: \(String(format: "%.1f", thirdSpaceRate(for: input.surgeryType)))×\(String(format: "%.0f", w))=\(String(format: "%.0f", thirdSpace)) mL/h"

        return FluidPlan(
            maintenanceRateMLPerH: maintenance,
            fastingDeficitML: fastingDeficit,
            firstHourReplacementML: firstHourBolus,
            hourlyMaintenanceML: maintenance,
            thirdSpaceRateMLPerH: thirdSpace,
            hourlyTotalML: hourlyTotal,
            totalCrystalloidForCaseML: totalCrystalloid,
            recommendedBolusML: firstHourBolus,
            formulaTrace: trace
        )
    }
}
