import XCTest
@testable import AnesthesiaCalcCore

final class DrugCalculatorTests: XCTestCase {

    let calculator = DrugCalculator()

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Patient struct
    // ══════════════════════════════════════════════════════════════════

    func test_patient_IBW_delegates_to_PatientContext() {
        // Patient.idealBodyWeight must equal PatientContext.idealBodyWeight
        // for identical inputs — no logic duplication.
        let patient = Patient(weight: 75, height: 175, age: 40, sex: .male)
        let ctx     = PatientContext(actualWeight: 75, heightCm: 175, age: 40, sex: .male)
        XCTAssertEqual(patient.idealBodyWeight, ctx.idealBodyWeight, accuracy: 0.001)
        XCTAssertEqual(patient.leanBodyWeight,  ctx.leanBodyWeight,  accuracy: 0.001)
    }

    func test_patient_bmi_and_isElderly() {
        let young = Patient(weight: 70, height: 175, age: 40, sex: .male)
        let elder = Patient(weight: 70, height: 175, age: 65, sex: .male)
        XCTAssertFalse(young.isElderly)
        XCTAssertTrue(elder.isElderly)
        XCTAssertEqual(young.bmi, 70.0 / (1.75 * 1.75), accuracy: 0.01)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Fentanyl (mcg unit, TBW, elderly adjustment)
    // ══════════════════════════════════════════════════════════════════

    func test_fentanyl_adult_dose_in_mcg() throws {
        // Adult male 70 kg, 40 y — no age adjustment.
        // Dose: 1–2 mcg/kg × 70 kg = 70–140 mcg
        // Internal mg: 0.07–0.14 mg
        // Volume: 0.07/0.05 – 0.14/0.05 = 1.4–2.8 mL  (50 mcg/mL = 0.05 mg/mL)
        let patient = Patient(weight: 70, height: 175, age: 40, sex: .male)
        let result  = try XCTUnwrap(calculator.calculateLegacyDose(patient: patient, drug: .fentanyl))

        XCTAssertEqual(result.doseUnit, .mcg)
        XCTAssertEqual(result.appliedScalingFactor, 1.0, accuracy: 0.001)

        XCTAssertEqual(result.minDisplayDose,  70.0, accuracy: 0.01)
        XCTAssertEqual(result.maxDisplayDose, 140.0, accuracy: 0.01)

        XCTAssertEqual(result.minDoseMg, 0.07, accuracy: 0.0001)
        XCTAssertEqual(result.maxDoseMg, 0.14, accuracy: 0.0001)

        XCTAssertEqual(result.minDoseMl, 1.4, accuracy: 0.001)
        XCTAssertEqual(result.maxDoseMl, 2.8, accuracy: 0.001)
    }

    func test_fentanyl_elderly_dose_halved() throws {
        // Elderly female 60 kg, 70 y — scalingFactor 0.5 triggers.
        // Dose: 1–2 mcg/kg × 0.5 × 60 = 30–60 mcg
        let patient = Patient(weight: 60, height: 160, age: 70, sex: .female)
        let result  = try XCTUnwrap(calculator.calculateLegacyDose(patient: patient, drug: .fentanyl))

        XCTAssertEqual(result.appliedScalingFactor, 0.5, accuracy: 0.001)
        XCTAssertEqual(result.appliedAgeAdjustments.count, 1)

        XCTAssertEqual(result.minDisplayDose,  30.0, accuracy: 0.01)
        XCTAssertEqual(result.maxDisplayDose,  60.0, accuracy: 0.01)
        XCTAssertEqual(result.minDoseMl, 0.6, accuracy: 0.001)
        XCTAssertEqual(result.maxDoseMl, 1.2, accuracy: 0.001)
    }

    func test_fentanyl_uses_TBW() throws {
        let patient = Patient(weight: 100, height: 170, age: 40, sex: .male)
        let result  = try XCTUnwrap(calculator.calculateLegacyDose(patient: patient, drug: .fentanyl))
        XCTAssertEqual(result.weightBase, .totalBodyWeight)
        XCTAssertEqual(result.weightUsed, 100.0, accuracy: 0.001)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Rocuronium uses IBW (safety-critical)
    // ══════════════════════════════════════════════════════════════════

    func test_rocuronium_obese_patient_uses_IBW_via_Patient_API() throws {
        // Obese male 120 kg, 170 cm.  IBW ≈ 65.9 kg, NOT 120 kg.
        let patient = Patient(weight: 120, height: 170, age: 45, sex: .male)
        let result  = try XCTUnwrap(calculator.calculateLegacyDose(patient: patient, drug: .rocuronium))

        XCTAssertEqual(result.weightBase, .idealBodyWeight)
        XCTAssertEqual(result.weightUsed, patient.idealBodyWeight, accuracy: 0.001)

        // IBW-based dose must be substantially less than TBW-based
        let tbwDose = 0.6 * patient.weight  // 72 mg — what a naive calculator would give
        XCTAssertLessThan(result.minDoseMg, tbwDose * 0.65,
                          "IBW-based dose should be < 65 % of TBW for obese patient")
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — DoseResult display formatting
    // ══════════════════════════════════════════════════════════════════

    func test_formattedDose_range_propofol() throws {
        let patient = Patient(weight: 70, height: 175, age: 40, sex: .male)
        let result  = try XCTUnwrap(calculator.calculateLegacyDose(patient: patient, drug: .propofol))
        XCTAssertEqual(result.formattedDose, "105.0 – 175.0 mg")
    }

    func test_formattedDose_fixed_rocuronium() throws {
        let patient = Patient(weight: 70, height: 175, age: 40, sex: .male)
        let result  = try XCTUnwrap(calculator.calculateLegacyDose(patient: patient, drug: .rocuronium))
        XCTAssertFalse(result.formattedDose.contains("–"),
                       "Fixed-dose drug should not render as a range")
        XCTAssertTrue(result.formattedDose.hasSuffix("mg"))
    }

    func test_formattedDose_fentanyl_shows_mcg() throws {
        let patient = Patient(weight: 70, height: 175, age: 40, sex: .male)
        let result  = try XCTUnwrap(calculator.calculateLegacyDose(patient: patient, drug: .fentanyl))
        XCTAssertTrue(result.formattedDose.hasSuffix("μg"),
                      "Fentanyl dose must be in μg, got: \(result.formattedDose)")
    }

    func test_formattedVolume_propofol() throws {
        let patient = Patient(weight: 70, height: 175, age: 40, sex: .male)
        let result  = try XCTUnwrap(calculator.calculateLegacyDose(patient: patient, drug: .propofol))
        XCTAssertEqual(result.formattedVolume, "10.50 – 17.50 mL")
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — calculateAll convenience method
    // ══════════════════════════════════════════════════════════════════

    func test_calculateAll_returns_every_drug() {
        let patient = Patient(weight: 70, height: 175, age: 40, sex: .male)
        let all     = calculator.calculateAll(patient: patient)
        let active  = DrugManager.shared.activeDrugs

        XCTAssertEqual(all.count, active.count)
        for drug in active {
            XCTAssertNotNil(all[drug], "Missing result for \(drug.displayName)")
        }
    }

    func test_calculateAll_results_match_individual_calls() {
        let patient = Patient(weight: 80, height: 170, age: 50, sex: .female)
        let all     = calculator.calculateAll(patient: patient)

        for drug in DrugManager.shared.activeDrugs {
            let individual = calculator.calculateLegacyDose(patient: patient, drug: drug)
            XCTAssertEqual(all[drug], individual,
                           "calculateAll result differs from individual call for \(drug.name)")
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — DrugLibrary legacy rules
    // ══════════════════════════════════════════════════════════════════

    func test_rocuronium_legacyRule_uses_IBW() {
        let rule = DrugLibrary.rule(for: AnesthesiaDrug.rocuronium.name)
        XCTAssertEqual(rule?.weightBase, .idealBodyWeight,
                       "Rocuronium MUST use IBW — do not change this without clinical review")
    }

    func test_fentanyl_legacyRule_dose_unit_is_mcg() {
        let rule = DrugLibrary.rule(for: AnesthesiaDrug.fentanyl.name)
        XCTAssertEqual(rule?.doseUnit, .mcg)
    }

    func test_propofol_and_rocuronium_legacyRule_dose_unit_is_mg() {
        XCTAssertEqual(DrugLibrary.rule(for: AnesthesiaDrug.propofol.name)?.doseUnit,   .mg)
        XCTAssertEqual(DrugLibrary.rule(for: AnesthesiaDrug.rocuronium.name)?.doseUnit, .mg)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — DoseUnit arithmetic sanity
    // ══════════════════════════════════════════════════════════════════

    func test_doseUnit_toMgFactor_roundtrip() {
        for unit in DoseUnit.allCases {
            let original  = 100.0
            let roundtrip = (original * unit.toMgFactor) * unit.fromMgFactor
            XCTAssertEqual(roundtrip, original, accuracy: 1e-9,
                           "Round-trip conversion failed for \(unit)")
        }
    }
}
