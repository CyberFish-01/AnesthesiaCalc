import XCTest
@testable import AnesthesiaCalcCore

final class FluidManagementCalculatorTests: XCTestCase {

    func test_4_2_1_70kg() {
        // 70kg: 4×10 + 2×10 + 1×50 = 40 + 20 + 50 = 110 mL/h
        let rate = FluidManagementCalculator.maintenanceRate(weightKg: 70)
        XCTAssertEqual(rate, 110, accuracy: 0.01)
    }

    func test_4_2_1_25kg() {
        // 25kg: 4×10 + 2×10 + 1×5 = 40 + 20 + 5 = 65 mL/h
        let rate = FluidManagementCalculator.maintenanceRate(weightKg: 25)
        XCTAssertEqual(rate, 65, accuracy: 0.01)
    }

    func test_4_2_1_8kg() {
        // 8kg: 4×8 = 32 mL/h
        let rate = FluidManagementCalculator.maintenanceRate(weightKg: 8)
        XCTAssertEqual(rate, 32, accuracy: 0.01)
    }

    func test_third_space_rates() {
        XCTAssertEqual(FluidManagementCalculator.thirdSpaceRate(for: .superficial), 1.5)
        XCTAssertEqual(FluidManagementCalculator.thirdSpaceRate(for: .moderate), 3.5)
        XCTAssertEqual(FluidManagementCalculator.thirdSpaceRate(for: .major), 7.0)
        XCTAssertEqual(FluidManagementCalculator.thirdSpaceRate(for: .severe), 9.0)
    }

    func test_full_plan_70kg_major_surgery() {
        let input = FluidInput(
            weightKg: 70, fastingHours: 8,
            surgeryType: .major, estimatedSurgeryMinutes: 180,
            crystalloidType: .lactatedRinger
        )
        let plan = FluidManagementCalculator.calculate(input)
        // maintenance = 110
        // fastingDeficit = 110 × 8 = 880
        // firstHourBolus = 440
        // thirdSpace = 7.0 × 70 = 490
        // hourlyTotal = 110 + 490 = 600
        // surgeryHours = 3
        // totalCrystalloid = 440 + 600 × 3 = 2240
        XCTAssertEqual(plan.maintenanceRateMLPerH, 110, accuracy: 0.1)
        XCTAssertEqual(plan.fastingDeficitML, 880, accuracy: 0.1)
        XCTAssertEqual(plan.firstHourReplacementML, 440, accuracy: 0.1)
        XCTAssertEqual(plan.thirdSpaceRateMLPerH, 490, accuracy: 0.1)
        XCTAssertEqual(plan.hourlyTotalML, 600, accuracy: 0.1)
        XCTAssertEqual(plan.totalCrystalloidForCaseML, 2240, accuracy: 1)
    }

    func test_formulaTrace_contains_math() {
        let input = FluidInput(
            weightKg: 70, fastingHours: 8,
            surgeryType: .moderate, estimatedSurgeryMinutes: 120
        )
        let plan = FluidManagementCalculator.calculate(input)
        XCTAssertTrue(plan.formulaTrace.contains("4×"))
        XCTAssertTrue(plan.formulaTrace.contains("3rd:"))
    }
}
