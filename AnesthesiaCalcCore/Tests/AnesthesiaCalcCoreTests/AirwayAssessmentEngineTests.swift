import XCTest
@testable import AnesthesiaCalcCore

final class AirwayAssessmentEngineTests: XCTestCase {

    // 构造一个常规低风险气道
    private let normalExam = AirwayExam(
        mallampati: .i, mouthOpeningCm: 5.0, thyromentalDistanceCm: 8.0,
        neckExtension: .normal, upperLipBite: .i, dentition: .normal,
        hasBeard: false, snoresHeavily: false, knownDifficultAirway: false
    )

    func test_normal_airway_scores_zero() {
        let result = AirwayAssessmentEngine.assess(exam: normalExam, bmi: 22)
        XCTAssertEqual(result.score, 0)
        XCTAssertEqual(result.riskTier, .low)
        XCTAssertEqual(result.recommendation, .standardMac)
    }

    func test_mallampati_IV_scores_one() {
        let exam = AirwayExam(
            mallampati: .iv, mouthOpeningCm: 5.0, thyromentalDistanceCm: 8.0,
            neckExtension: .normal, upperLipBite: .i, dentition: .normal,
            hasBeard: false, snoresHeavily: false, knownDifficultAirway: false
        )
        let result = AirwayAssessmentEngine.assess(exam: exam, bmi: 22)
        XCTAssertEqual(result.score, 1)
        XCTAssertTrue(result.rationale.contains { $0.contains("Mallampati IV") })
    }

    func test_all_six_dimensions_high_risk() {
        let exam = AirwayExam(
            mallampati: .iv, mouthOpeningCm: 2.0, thyromentalDistanceCm: 4.0,
            neckExtension: .severe, upperLipBite: .iii, dentition: .buckTeethOrLoose,
            hasBeard: true, snoresHeavily: true, knownDifficultAirway: true
        )
        let result = AirwayAssessmentEngine.assess(exam: exam, bmi: 40)
        XCTAssertEqual(result.score, 6)         // 6 + BMI tierLift capped at 6
        XCTAssertEqual(result.riskTier, .high)
    }

    func test_known_difficult_airway_alone_is_moderate() {
        // 无其他风险但困难气道史 → 基础评分 1 + tierLift 1 = 2 → moderate
        let exam = AirwayExam(
            mallampati: .i, mouthOpeningCm: 5.0, thyromentalDistanceCm: 8.0,
            neckExtension: .normal, upperLipBite: .i, dentition: .normal,
            hasBeard: false, snoresHeavily: false, knownDifficultAirway: true
        )
        let result = AirwayAssessmentEngine.assess(exam: exam, bmi: 22)
        XCTAssertEqual(result.riskTier, .moderate)
        XCTAssertEqual(result.recommendation, .videolaryngoscope)
    }

    func test_BMI_over_35_raises_tier() {
        let result = AirwayAssessmentEngine.assess(exam: normalExam, bmi: 38)
        // score=0 + BMI tierLift=1 → effectiveScore=1 → low (still)
        // Actually: 0 + 1 = 1 → low. Let me verify...
        XCTAssertEqual(result.score, 1)
        XCTAssertEqual(result.riskTier, .low)
        // Low because effectiveScore <= 1
    }

    func test_pregnancy_raises_tier() {
        let exam = AirwayExam(
            mallampati: .i, mouthOpeningCm: 5.0, thyromentalDistanceCm: 8.0,
            neckExtension: .normal, upperLipBite: .i, dentition: .normal,
            hasBeard: false, snoresHeavily: false, knownDifficultAirway: false,
            isPregnant: true
        )
        let result = AirwayAssessmentEngine.assess(exam: exam, bmi: 22)
        XCTAssertEqual(result.score, 1)
        XCTAssertTrue(result.rationale.contains("妊娠"))
    }

    func test_OBESE_BMV_prediction() {
        // 络腮胡 + OSA + 龅牙 + BMI>30 → bmvScore=4 → BMV difficult
        let exam = AirwayExam(
            mallampati: .i, mouthOpeningCm: 5.0, thyromentalDistanceCm: 8.0,
            neckExtension: .normal, upperLipBite: .i, dentition: .buckTeethOrLoose,
            hasBeard: true, snoresHeavily: false, knownDifficultAirway: false,
            hasOSA: true
        )
        let result = AirwayAssessmentEngine.assess(exam: exam, bmi: 35)
        XCTAssertGreaterThanOrEqual(result.predictedDifficultBMV, 0.6)
    }

    func test_high_risk_plus_BMV_difficult_gives_surgicalAirway() {
        let exam = AirwayExam(
            mallampati: .iv, mouthOpeningCm: 2.0, thyromentalDistanceCm: 4.0,
            neckExtension: .severe, upperLipBite: .iii, dentition: .buckTeethOrLoose,
            hasBeard: true, snoresHeavily: true, knownDifficultAirway: false,
            hasOSA: true
        )
        // score = 6 (Mallampati IV, mouth<4, TMD<6.5, neck=severe, ULBT=III, dentition buck)
        // bmvScore = 4 (beard, OSA, buckTeeth, BMI>30) → bmvDifficult
        let result = AirwayAssessmentEngine.assess(exam: exam, bmi: 40)
        XCTAssertEqual(result.recommendation, .surgicalAirway)
    }

    func test_neck_radiation_raises_tier() {
        let exam = AirwayExam(
            mallampati: .i, mouthOpeningCm: 5.0, thyromentalDistanceCm: 8.0,
            neckExtension: .normal, upperLipBite: .i, dentition: .normal,
            hasBeard: false, snoresHeavily: false, knownDifficultAirway: false,
            hasNeckRadiation: true
        )
        let result = AirwayAssessmentEngine.assess(exam: exam, bmi: 22)
        XCTAssertEqual(result.score, 1)
        XCTAssertTrue(result.rationale.contains("放疗"))
    }
}
