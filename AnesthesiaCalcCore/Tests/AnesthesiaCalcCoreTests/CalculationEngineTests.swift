import XCTest
@testable import AnesthesiaCalcCore

final class CalculationEngineTests: XCTestCase {

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Propofol (TBW, with elderly age adjustment)
    // ══════════════════════════════════════════════════════════════════

    func test_propofol_adult_normal_dose() {
        // Adult male, 70 kg, 40 y — no age adjustment should apply.
        // min: 1.5 × 70 = 105 mg = 10.5 mL
        // max: 2.5 × 70 = 175 mg = 17.5 mL
        let patient = PatientContext(actualWeight: 70, heightCm: 175, age: 40, sex: .male)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.propofol, patient: patient)

        XCTAssertEqual(result.weightUsed,           70.0,  accuracy: 0.001)
        XCTAssertEqual(result.weightBase,           .totalBodyWeight)
        XCTAssertEqual(result.appliedScalingFactor, 1.0,   accuracy: 0.001)
        XCTAssertTrue(result.appliedAgeAdjustments.isEmpty)

        XCTAssertEqual(result.minDoseMg, 105.0, accuracy: 0.001)
        XCTAssertEqual(result.maxDoseMg, 175.0, accuracy: 0.001)
        XCTAssertEqual(result.minDoseMl,  10.5, accuracy: 0.001)
        XCTAssertEqual(result.maxDoseMl,  17.5, accuracy: 0.001)
    }

    func test_propofol_elderly_dose_reduced_by_30_percent() {
        // Elderly female, 60 kg, 68 y → scaling factor 0.7 must trigger.
        // min: 1.5 × 0.7 × 60 = 63 mg  = 6.3 mL
        // max: 2.5 × 0.7 × 60 = 105 mg = 10.5 mL
        let patient = PatientContext(actualWeight: 60, heightCm: 160, age: 68, sex: .female)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.propofol, patient: patient)

        XCTAssertEqual(result.appliedScalingFactor, 0.7, accuracy: 0.001)
        XCTAssertEqual(result.appliedAgeAdjustments.count, 1)
        XCTAssertEqual(result.appliedAgeAdjustments.first?.ageThreshold, 65)

        XCTAssertEqual(result.minDoseMg,  63.0, accuracy: 0.001)
        XCTAssertEqual(result.maxDoseMg, 105.0, accuracy: 0.001)
        XCTAssertEqual(result.minDoseMl,   6.3, accuracy: 0.001)
        XCTAssertEqual(result.maxDoseMl,  10.5, accuracy: 0.001)
    }

    func test_propofol_age_64_no_reduction() {
        // One year below the threshold — no adjustment.
        let patient = PatientContext(actualWeight: 70, heightCm: 170, age: 64, sex: .male)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.propofol, patient: patient)

        XCTAssertEqual(result.appliedScalingFactor, 1.0, accuracy: 0.001)
        XCTAssertTrue(result.appliedAgeAdjustments.isEmpty)
        XCTAssertEqual(result.minDoseMg, 1.5 * 70, accuracy: 0.001)
    }

    func test_propofol_age_65_reduction_triggers_exactly_at_boundary() {
        let patient = PatientContext(actualWeight: 70, heightCm: 170, age: 65, sex: .male)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.propofol, patient: patient)

        XCTAssertEqual(result.appliedScalingFactor, 0.7, accuracy: 0.001)
        XCTAssertEqual(result.minDoseMg, 1.5 * 0.7 * 70, accuracy: 0.001)
    }

    func test_propofol_uses_TBW_not_IBW() {
        // Even for an obese patient, Propofol dose is based on TBW.
        let patient = PatientContext(actualWeight: 120, heightCm: 170, age: 45, sex: .male)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.propofol, patient: patient)

        XCTAssertEqual(result.weightBase, .totalBodyWeight)
        XCTAssertEqual(result.weightUsed, 120.0, accuracy: 0.001)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Rocuronium (IBW — critical safety tests)
    // ══════════════════════════════════════════════════════════════════

    func test_rocuronium_normal_weight_male() {
        // Male 75 kg, 175 cm, 40 y.
        // IBW = 50 + 2.3 × (175/2.54 − 60) ≈ 70.465 kg
        // dose = 0.6 × 70.465 ≈ 42.279 mg ≈ 4.228 mL
        let patient = PatientContext(actualWeight: 75, heightCm: 175, age: 40, sex: .male)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.rocuronium, patient: patient)

        XCTAssertEqual(result.weightBase, .idealBodyWeight)
        XCTAssertEqual(result.weightUsed, patient.idealBodyWeight, accuracy: 0.001)

        let expectedMg = 0.6 * patient.idealBodyWeight
        XCTAssertEqual(result.minDoseMg, expectedMg, accuracy: 0.001)
        XCTAssertEqual(result.maxDoseMg, expectedMg, accuracy: 0.001)
        XCTAssertEqual(result.minDoseMl, expectedMg / 10.0, accuracy: 0.001)
        XCTAssertEqual(result.maxDoseMl, expectedMg / 10.0, accuracy: 0.001)
    }

    // ── SAFETY-CRITICAL SCENARIO ──────────────────────────────────────
    // An obese patient (120 kg, 170 cm) should receive a dose based on
    // IBW (~65.9 kg), NOT on TBW (120 kg).
    // Dosing on TBW would give 72 mg — ~82 % too much — risking
    // dangerously prolonged neuromuscular blockade.
    func test_rocuronium_obese_patient_uses_IBW_not_TBW() {
        let patient = PatientContext(actualWeight: 120, heightCm: 170, age: 45, sex: .male)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.rocuronium, patient: patient)

        // IBW for 170 cm male: 50 + 2.3 × (66.929 − 60) ≈ 65.937 kg
        let ibw = patient.idealBodyWeight
        XCTAssertEqual(ibw, 65.937, accuracy: 0.01, "IBW for 170 cm male should be ~65.9 kg")

        // Engine must use IBW
        XCTAssertEqual(result.weightBase, .idealBodyWeight)
        XCTAssertEqual(result.weightUsed, ibw, accuracy: 0.001)

        let expectedMg = 0.6 * ibw   // ≈ 39.56 mg
        XCTAssertEqual(result.minDoseMg, expectedMg, accuracy: 0.01)

        // Verify the IBW-based dose is substantially lower than TBW-based
        let tbwBasedMg = 0.6 * patient.actualWeight  // 72 mg
        XCTAssertLessThan(
            result.minDoseMg,
            tbwBasedMg * 0.65,
            "IBW-based dose should be < 65 % of TBW-based dose for BMI ~42"
        )
    }

    func test_rocuronium_has_no_age_adjustment() {
        let elderly = PatientContext(actualWeight: 65, heightCm: 165, age: 75, sex: .female)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.rocuronium, patient: elderly)

        XCTAssertEqual(result.appliedScalingFactor, 1.0, accuracy: 0.001)
        XCTAssertTrue(result.appliedAgeAdjustments.isEmpty)
    }

    func test_rocuronium_fixed_dose_min_equals_max() {
        let patient = PatientContext(actualWeight: 70, heightCm: 170, age: 40, sex: .male)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.rocuronium, patient: patient)

        XCTAssertEqual(result.minDoseMg, result.maxDoseMg, accuracy: 0.0001)
        XCTAssertEqual(result.minDoseMl, result.maxDoseMl, accuracy: 0.0001)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Stacking age adjustments (custom rule)
    // ══════════════════════════════════════════════════════════════════

    func test_stacked_age_adjustments_multiply() {
        // Hypothetical rule: ≥65 → ×0.8, ≥80 → ×0.75 (combined = ×0.60)
        let customRule = DrugRule(
            name: "Test Drug",
            weightBase: .totalBodyWeight,
            doseRange: DoseRange(minDosePerKg: 1.0, maxDosePerKg: 1.0),
            concentrationMgPerMl: 1.0,
            ageAdjustments: [
                AgeAdjustment(ageThreshold: 65, scalingFactor: 0.8),
                AgeAdjustment(ageThreshold: 80, scalingFactor: 0.75)
            ]
        )
        let patient80 = PatientContext(actualWeight: 60, heightCm: 165, age: 80, sex: .female)
        let result    = CalculationEngine.calculate(rule: customRule, patient: patient80)

        // Both thresholds triggered: 0.8 × 0.75 = 0.60
        XCTAssertEqual(result.appliedScalingFactor, 0.60, accuracy: 0.001)
        XCTAssertEqual(result.appliedAgeAdjustments.count, 2)

        // 1.0 mg/kg × 0.60 × 60 kg = 36 mg
        XCTAssertEqual(result.minDoseMg, 36.0, accuracy: 0.001)
    }

    func test_stacked_only_first_threshold_triggered() {
        let customRule = DrugRule(
            name: "Test Drug",
            weightBase: .totalBodyWeight,
            doseRange: DoseRange(minDosePerKg: 1.0, maxDosePerKg: 1.0),
            concentrationMgPerMl: 1.0,
            ageAdjustments: [
                AgeAdjustment(ageThreshold: 65, scalingFactor: 0.8),
                AgeAdjustment(ageThreshold: 80, scalingFactor: 0.75)
            ]
        )
        let patient70 = PatientContext(actualWeight: 60, heightCm: 165, age: 70, sex: .female)
        let result    = CalculationEngine.calculate(rule: customRule, patient: patient70)

        // Only the ≥65 rule fires; ≥80 does not.
        XCTAssertEqual(result.appliedScalingFactor, 0.8, accuracy: 0.001)
        XCTAssertEqual(result.appliedAgeAdjustments.count, 1)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Output invariants (sanity checks)
    // ══════════════════════════════════════════════════════════════════

    func test_minDose_always_le_maxDose() {
        let patients: [PatientContext] = [
            PatientContext(actualWeight: 50,  heightCm: 155, age: 30,  sex: .female),
            PatientContext(actualWeight: 80,  heightCm: 175, age: 55,  sex: .male),
            PatientContext(actualWeight: 120, heightCm: 170, age: 70,  sex: .male),
        ]
        let rules = [DrugLibrary.propofol, DrugLibrary.rocuronium]

        for rule in rules {
            for patient in patients {
                let r = CalculationEngine.calculate(rule: rule, patient: patient)
                XCTAssertLessThanOrEqual(r.minDoseMg, r.maxDoseMg,
                    "\(rule.name): minMg > maxMg for \(patient)")
                XCTAssertLessThanOrEqual(r.minDoseMl, r.maxDoseMl,
                    "\(rule.name): minMl > maxMl for \(patient)")
            }
        }
    }

    func test_ml_consistent_with_concentration() {
        let patient = PatientContext(actualWeight: 70, heightCm: 170, age: 40, sex: .male)
        let result  = CalculationEngine.calculate(rule: DrugLibrary.propofol, patient: patient)

        // mL = mg ÷ concentration; concentration = 10 mg/mL
        XCTAssertEqual(result.minDoseMl, result.minDoseMg / 10.0, accuracy: 0.0001)
        XCTAssertEqual(result.maxDoseMl, result.maxDoseMg / 10.0, accuracy: 0.0001)
    }
}
