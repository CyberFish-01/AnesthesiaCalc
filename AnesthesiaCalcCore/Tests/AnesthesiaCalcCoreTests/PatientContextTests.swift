import XCTest
@testable import AnesthesiaCalcCore

final class PatientContextTests: XCTestCase {

    // ── Fixtures ───────────────────────────────────────────────────────

    /// Male, 175 cm, 75 kg, 40 y — healthy adult reference
    let adultMale   = PatientContext(actualWeight: 75,  heightCm: 175, age: 40, sex: .male)
    /// Female, 160 cm, 60 kg, 35 y — healthy adult reference
    let adultFemale = PatientContext(actualWeight: 60,  heightCm: 160, age: 35, sex: .female)
    /// Male, 175 cm, 120 kg — obese, IBW ≠ TBW
    let obeseMale   = PatientContext(actualWeight: 120, heightCm: 175, age: 45, sex: .male)

    // ── IBW — Devine formula ───────────────────────────────────────────

    func test_IBW_male_175cm() {
        // 175 cm ÷ 2.54 = 68.8976 in
        // IBW = 50 + 2.3 × (68.8976 − 60) = 50 + 20.4645 = 70.4645 kg
        XCTAssertEqual(adultMale.idealBodyWeight, 70.465, accuracy: 0.001)
    }

    func test_IBW_female_160cm() {
        // 160 cm ÷ 2.54 = 62.9921 in
        // IBW = 45.5 + 2.3 × (62.9921 − 60) = 45.5 + 6.8819 = 52.382 kg
        XCTAssertEqual(adultFemale.idealBodyWeight, 52.382, accuracy: 0.001)
    }

    func test_IBW_isClamped_for_short_patients() {
        // Patient shorter than 5 ft (152.4 cm) must never get a negative IBW.
        let shortFemale = PatientContext(actualWeight: 45, heightCm: 145, age: 30, sex: .female)
        // IBW = 45.5 + 2.3 × (57.09 − 60) = 45.5 − 6.69 = 38.81
        // Clamped to base 45.5
        XCTAssertEqual(shortFemale.idealBodyWeight, 45.5, accuracy: 0.001)
    }

    func test_IBW_obese_same_as_normal_height_reference() {
        // An obese patient's IBW depends only on height, not actual weight.
        let normalMale = PatientContext(actualWeight: 70,  heightCm: 175, age: 40, sex: .male)
        XCTAssertEqual(obeseMale.idealBodyWeight, normalMale.idealBodyWeight, accuracy: 0.001)
    }

    // ── LBW — Janmahasatian formula ────────────────────────────────────

    func test_LBW_male_80kg_175cm() {
        let patient = PatientContext(actualWeight: 80, heightCm: 175, age: 40, sex: .male)
        // BMI = 80 / 1.75² = 26.1224
        // LBW = (9270 × 80) / (6680 + 216 × 26.1224)
        //     = 741600 / (6680 + 5642.44)
        //     = 741600 / 12322.44
        //     ≈ 60.183 kg
        XCTAssertEqual(patient.leanBodyWeight, 60.183, accuracy: 0.01)
    }

    func test_LBW_female_60kg_160cm() {
        // BMI = 60 / 1.60² = 23.4375
        // LBW = (9270 × 60) / (8780 + 244 × 23.4375)
        //     = 556200 / (8780 + 5718.75)
        //     = 556200 / 14498.75
        //     ≈ 38.362 kg
        XCTAssertEqual(adultFemale.leanBodyWeight, 38.362, accuracy: 0.01)
    }

    func test_LBW_is_always_less_than_TBW() {
        // LBW < TBW must hold for every realistic patient.
        XCTAssertLessThan(adultMale.leanBodyWeight,   adultMale.actualWeight)
        XCTAssertLessThan(adultFemale.leanBodyWeight, adultFemale.actualWeight)
        XCTAssertLessThan(obeseMale.leanBodyWeight,   obeseMale.actualWeight)
    }

    func test_LBW_obese_is_much_less_than_TBW() {
        // For obese patients the divergence must be substantial.
        let difference = obeseMale.actualWeight - obeseMale.leanBodyWeight
        XCTAssertGreaterThan(difference, 30, "Expected LBW to be >30 kg below TBW for BMI ~39")
    }

    // ── BMI ────────────────────────────────────────────────────────────

    func test_BMI_normal() {
        // 75 / 1.75² = 24.49
        XCTAssertEqual(adultMale.bmi, 24.49, accuracy: 0.01)
    }

    // ── isElderly ──────────────────────────────────────────────────────

    func test_isElderly_boundary() {
        let at64 = PatientContext(actualWeight: 70, heightCm: 170, age: 64, sex: .male)
        let at65 = PatientContext(actualWeight: 70, heightCm: 170, age: 65, sex: .male)
        XCTAssertFalse(at64.isElderly, "64 years old should NOT be classified as elderly")
        XCTAssertTrue(at65.isElderly,  "65 years old SHOULD be classified as elderly")
    }
}
