import XCTest
@testable import AnesthesiaCalcCore

final class ABLCalculatorTests: XCTestCase {

    func test_adult_male_EBV_and_ABL() {
        // 70kg male, Hct 0.40 → target 0.25
        // EBV = 70 × 70 = 4900 mL
        // ABL = 4900 × (0.40 - 0.25) / 0.40 = 4900 × 0.15/0.40 = 1837.5
        let input = ABLInput(
            weightKg: 70, sex: .male, age: 40,
            preoperativeHct: 0.40, preoperativeHb: 132,
            targetHct: 0.25, targetHb: 70
        )
        let result = ABLCalculator.calculate(input)
        XCTAssertEqual(result.estimatedBloodVolume, 4900, accuracy: 0.1)
        XCTAssertEqual(result.allowableBloodLoss, 1837.5, accuracy: 1.0)
        XCTAssertEqual(result.bloodLossAsPercentage, 37.5, accuracy: 0.5)
    }

    func test_adult_female_EBV() {
        let input = ABLInput(
            weightKg: 60, sex: .female, age: 40,
            preoperativeHct: 0.40, preoperativeHb: 132,
            targetHct: 0.25
        )
        let result = ABLCalculator.calculate(input)
        XCTAssertEqual(result.estimatedBloodVolume, 3900, accuracy: 0.1)  // 60 × 65
    }

    func test_pregnant_female_EBV_increased() {
        let input = ABLInput(
            weightKg: 60, sex: .female, isPregnant: true, age: 30,
            preoperativeHct: 0.35, preoperativeHb: 115,
            targetHct: 0.25
        )
        let result = ABLCalculator.calculate(input)
        // EBV = 60 × 65 × 1.2 = 4680
        XCTAssertEqual(result.estimatedBloodVolume, 4680, accuracy: 0.1)
    }

    func test_child_EBV() {
        let input = ABLInput(
            weightKg: 25, sex: .male, age: 8,
            preoperativeHct: 0.38, preoperativeHb: 125,
            targetHct: 0.25
        )
        let result = ABLCalculator.calculate(input)
        XCTAssertEqual(result.estimatedBloodVolume, 2000, accuracy: 0.1)  // 25 × 80
    }

    func test_neonate_EBV() {
        let input = ABLInput(
            weightKg: 3.5, sex: .female, age: 0,
            preoperativeHct: 0.45, preoperativeHb: 150,
            targetHct: 0.30
        )
        let result = ABLCalculator.calculate(input)
        XCTAssertEqual(result.estimatedBloodVolume, 297.5, accuracy: 0.1)  // 3.5 × 85
    }

    func test_zero_Hct_returns_zero_result() {
        let input = ABLInput(
            weightKg: 70, sex: .male,
            preoperativeHct: 0, preoperativeHb: 0,
            targetHct: 0.25
        )
        let result = ABLCalculator.calculate(input)
        XCTAssertEqual(result.allowableBloodLoss, 0)
        XCTAssertEqual(result.formulaTrace, "术前 Hct/Hb 无效")
    }

    func test_formulaTrace_not_empty() {
        let input = ABLInput(
            weightKg: 70, sex: .male,
            preoperativeHct: 0.40, preoperativeHb: 132,
            targetHct: 0.25
        )
        let result = ABLCalculator.calculate(input)
        XCTAssertFalse(result.formulaTrace.isEmpty)
        XCTAssertTrue(result.formulaTrace.contains("EBV="))
    }
}
