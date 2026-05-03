import XCTest
@testable import AnesthesiaCalcCore

final class AIRuleEngineTests: XCTestCase {

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Helpers
    // ══════════════════════════════════════════════════════════════════

    /// A fresh engine with default rules loaded (no shared-state pollution)
    private func freshEngine() -> AIRuleEngine { AIRuleEngine() }

    private let adultMale70 = Patient(weight: 70,  height: 175, age: 40, sex: .male)
    private let elderly60   = Patient(weight: 60,  height: 160, age: 68, sex: .female)
    private let obese120    = Patient(weight: 120, height: 170, age: 45, sex: .male)

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Default rules loaded correctly
    // ══════════════════════════════════════════════════════════════════

    func test_defaultRules_arePresent_for_all_three_drugs() {
        let engine = freshEngine()
        XCTAssertNotNil(engine.dosageRule(for: .propofol,   doseType: .induction))
        XCTAssertNotNil(engine.dosageRule(for: .rocuronium, doseType: .intubation))
        XCTAssertNotNil(engine.dosageRule(for: .fentanyl,   doseType: .induction))
    }

    func test_propofol_defaultRule_values() {
        let rule = freshEngine().dosageRule(for: .propofol, doseType: .induction)!
        XCTAssertEqual(rule.minMultiplier, 1.5, accuracy: 0.001)
        XCTAssertEqual(rule.maxMultiplier, 2.5, accuracy: 0.001)
        XCTAssertEqual(rule.weightBase, .totalBodyWeight)
        XCTAssertEqual(rule.unit, "mg")
        XCTAssertEqual(rule.concentrationMgPerMl, 10.0, accuracy: 0.001)
        XCTAssertEqual(rule.absoluteMaxDose, 300.0)
        XCTAssertEqual(rule.ageAdjustments?.first?.ageThreshold, 65)
    }

    func test_rocuronium_defaultRule_uses_IBW() {
        let rule = freshEngine().dosageRule(for: .rocuronium, doseType: .intubation)!
        XCTAssertEqual(rule.weightBase, .idealBodyWeight,
                       "Rocuronium MUST default to IBW — changing this requires clinical sign-off")
    }

    func test_fentanyl_defaultRule_unit_is_mcg() {
        let rule = freshEngine().dosageRule(for: .fentanyl, doseType: .induction)!
        XCTAssertEqual(rule.unit, "mcg")
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — calculateDose via AIRuleEngine path
    // ══════════════════════════════════════════════════════════════════

    func test_propofol_adult_dose_uses_TBW() {
        // 1.5–2.5 mg/kg × TBW 70 kg = 105–175 mg
        let calc = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: adultMale70, drug: .propofol, doseType: .induction)!

        XCTAssertEqual(range.weightBase, .totalBodyWeight)
        XCTAssertEqual(range.weightUsed, 70.0, accuracy: 0.001)
        XCTAssertEqual(range.minDose, 105.0, accuracy: 0.01)
        XCTAssertEqual(range.maxDose, 175.0, accuracy: 0.01)
        XCTAssertEqual(range.unit, "mg")
        XCTAssertFalse(range.wasClampedByAbsoluteMax)
    }

    func test_propofol_elderly_dose_reduced_by_30_percent() {
        // Age 68 triggers ageAdjustment(≥65, 0.7)
        // 1.5–2.5 × 0.7 × 60 = 63–105 mg
        let calc = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: elderly60, drug: .propofol, doseType: .induction)!

        XCTAssertEqual(range.minDose,  63.0, accuracy: 0.01)
        XCTAssertEqual(range.maxDose, 105.0, accuracy: 0.01)
        XCTAssertFalse(range.wasClampedByAbsoluteMax)
    }

    func test_rocuronium_obese_patient_uses_IBW_not_TBW() {
        // Obese male 120 kg, 170 cm → IBW ≈ 65.9 kg
        // 0.6–0.9 mg/kg × IBW ≈ 39.6–59.4 mg   (NOT 72–108 mg from TBW)
        let calc  = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: obese120, drug: .rocuronium, doseType: .intubation)!

        XCTAssertEqual(range.weightBase, .idealBodyWeight)
        XCTAssertEqual(range.weightUsed, obese120.idealBodyWeight, accuracy: 0.001)

        let tbwMax = 0.9 * obese120.weight  // 108 mg — what TBW would give
        XCTAssertLessThan(range.maxDose, tbwMax,
                          "IBW-based dose must be lower than TBW-based for obese patient")
    }

    func test_fentanyl_adult_dose_in_mcg() {
        // 1–2 mcg/kg × TBW 70 kg = 70–140 mcg → 1.4–2.8 mL  (50 mcg/mL)
        let calc  = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: adultMale70, drug: .fentanyl, doseType: .induction)!

        XCTAssertEqual(range.unit, "mcg")
        XCTAssertEqual(range.minDose,  70.0, accuracy: 0.01)
        XCTAssertEqual(range.maxDose, 140.0, accuracy: 0.01)
        XCTAssertEqual(range.minVolumeMl, 1.4, accuracy: 0.001)
        XCTAssertEqual(range.maxVolumeMl, 2.8, accuracy: 0.001)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — absoluteMaxDose clamping
    // ══════════════════════════════════════════════════════════════════

    func test_absoluteMaxDose_clamps_maxDose_when_exceeded() {
        // Patient heavy enough to exceed the 300 mg propofol cap
        // TBW = 200 kg → 2.5 × 200 = 500 mg > 300 mg cap
        let heavyPatient = Patient(weight: 200, height: 190, age: 40, sex: .male)
        let calc  = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: heavyPatient, drug: .propofol, doseType: .induction)!

        XCTAssertEqual(range.maxDose, 300.0, accuracy: 0.001,
                       "maxDose must be clamped to absoluteMaxDose = 300 mg")
        XCTAssertTrue(range.wasClampedByAbsoluteMax)
    }

    func test_absoluteMaxDose_not_triggered_for_normal_patient() {
        // TBW = 70 kg → 2.5 × 70 = 175 mg < 300 mg cap — no clamping
        let calc  = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: adultMale70, drug: .propofol, doseType: .induction)!

        XCTAssertFalse(range.wasClampedByAbsoluteMax)
        XCTAssertEqual(range.maxDose, 175.0, accuracy: 0.001)
    }

    func test_absoluteMaxDose_clamps_minDose_when_both_exceed_cap() {
        // Inject a test rule with a very low cap so even minDose is above it
        let tightRule = DosageRule(
            drug:                 AnesthesiaDrug.propofol.name,
            doseType:             DoseType.induction.rawValue,
            minMultiplier:        2.0,
            maxMultiplier:        3.0,
            weightBase:           .totalBodyWeight,
            unit:                 "mg",
            concentrationMgPerMl: 10.0,
            absoluteMaxDose:      50.0,   // extremely low cap for the test
            ageAdjustments:       nil
        )
        let engine = freshEngine()
        engine.replaceAllRules(with: [tightRule])
        // Give queue time to process (barrier write is async)
        Thread.sleep(forTimeInterval: 0.05)

        let patient = Patient(weight: 70, height: 175, age: 40, sex: .male)
        let calc    = DrugCalculator(ruleEngine: engine)
        let range   = calc.calculateDose(patient: patient, drug: .propofol, doseType: .induction)!

        // maxDose clamped to 50; minDose clamped to maxDose (50 as well)
        XCTAssertEqual(range.maxDose, 50.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(range.minDose, range.maxDose)
        XCTAssertTrue(range.wasClampedByAbsoluteMax)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — JSON update path
    // ══════════════════════════════════════════════════════════════════

    func test_updateRules_from_JSON_overrides_existing_rule() throws {
        let json = """
        [
          {
            "drug": "丙泊酚",
            "doseType": "induction",
            "minMultiplier": 1.0,
            "maxMultiplier": 2.0,
            "weightBase": "TBW",
            "unit": "mg",
            "concentrationMgPerMl": 10.0,
            "absoluteMaxDose": null
          }
        ]
        """.data(using: .utf8)!

        let engine = freshEngine()
        try engine.updateRules(from: json)
        Thread.sleep(forTimeInterval: 0.05)   // wait for barrier write

        let updated = engine.dosageRule(for: .propofol, doseType: .induction)!
        XCTAssertEqual(updated.minMultiplier, 1.0, accuracy: 0.001)
        XCTAssertEqual(updated.maxMultiplier, 2.0, accuracy: 0.001)
        XCTAssertNil(updated.absoluteMaxDose)
    }

    func test_updateRules_malformed_JSON_throws() {
        let bad = "{ not valid json }".data(using: .utf8)!
        let engine = freshEngine()
        XCTAssertThrowsError(try engine.updateRules(from: bad))
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — DrugDoseRange formatting
    // ══════════════════════════════════════════════════════════════════

    func test_displayString_range() {
        let calc  = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: adultMale70, drug: .propofol, doseType: .induction)!
        XCTAssertEqual(range.displayString, "105.0 – 175.0 mg")
    }

    func test_volumeString_range() {
        let calc  = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: adultMale70, drug: .propofol, doseType: .induction)!
        XCTAssertEqual(range.volumeString, "10.50 – 17.50 mL")
    }

    func test_displayString_fixed_dose() {
        let calc  = DrugCalculator(ruleEngine: freshEngine())
        let range = calc.calculateDose(patient: adultMale70, drug: .rocuronium, doseType: .intubation)!
        // Rocuronium min == max → single-value string
        if abs(range.minDose - range.maxDose) < 1e-9 {
            XCTAssertFalse(range.displayString.contains("–"))
        }
    }

    func test_returns_nil_for_unknown_indication() {
        let calc  = DrugCalculator(ruleEngine: freshEngine())
        // No fentanyl rule exists for .sedation in the default catalogue
        let range = calc.calculateDose(patient: adultMale70, drug: .fentanyl, doseType: .sedation)
        XCTAssertNil(range, "Should return nil when no rule is cached for this indication")
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — asDrugRule bridge
    // ══════════════════════════════════════════════════════════════════

    func test_asDrugRule_roundtrip_preserves_weightBase_and_unit() {
        let rule     = freshEngine().dosageRule(for: .propofol, doseType: .induction)!
        let drugRule = rule.asDrugRule()
        XCTAssertNotNil(drugRule)
        XCTAssertEqual(drugRule?.weightBase, .totalBodyWeight)
        XCTAssertEqual(drugRule?.doseUnit, .mg)
        if let minDose = drugRule?.doseRange.minDosePerKg {
            XCTAssertEqual(minDose, 1.5, accuracy: 0.001)
        } else {
            XCTFail("doseRange.minDosePerKg should not be nil")
        }
    }
}
