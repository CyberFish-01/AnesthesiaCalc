import XCTest
@testable import AnesthesiaCalcCore

final class EmergencyProtocolEngineTests: XCTestCase {

    func test_generateAll_returns_six_protocols() {
        let protocols = EmergencyProtocolEngine.generateAll(for: 70)
        XCTAssertEqual(protocols.count, 6)
    }

    func test_each_protocol_has_non_empty_sections() {
        let protocols = EmergencyProtocolEngine.generateAll(for: 70)
        for p in protocols {
            XCTAssertFalse(p.recognition.isEmpty, "\(p.name): recognition is empty")
            XCTAssertFalse(p.immediateActions.isEmpty, "\(p.name): immediateActions is empty")
            XCTAssertFalse(p.drugSteps.isEmpty, "\(p.name): drugSteps is empty")
            XCTAssertFalse(p.escalation.isEmpty, "\(p.name): escalation is empty")
        }
    }

    func test_cardiac_arrest_epinephrine_is_fixed_dose() {
        guard let p = EmergencyProtocolEngine.generate(for: 70, id: "cardiac_arrest") else {
            XCTFail(); return
        }
        let epiStep = p.drugSteps.first { $0.drugName == "肾上腺素" }
        XCTAssertNotNil(epiStep)
        XCTAssertEqual(epiStep?.calculatedDose, "1mg")
    }

    func test_anaphylaxis_epinephrine_weight_dependent() {
        guard let p = EmergencyProtocolEngine.generate(for: 70, id: "anaphylaxis") else {
            XCTFail(); return
        }
        let epiStep = p.drugSteps.first { $0.drugName == "肾上腺素" && $0.route == "IV" }
        XCTAssertNotNil(epiStep)
        // 70kg → 70μg, max cap 100μg
        XCTAssertEqual(epiStep?.calculatedDose, "70 μg")
    }

    func test_anaphylaxis_epinephrine_capped_at_100() {
        guard let p = EmergencyProtocolEngine.generate(for: 150, id: "anaphylaxis") else {
            XCTFail(); return
        }
        let epiStep = p.drugSteps.first { $0.drugName == "肾上腺素" && $0.route == "IV" }
        XCTAssertNotNil(epiStep)
        XCTAssertEqual(epiStep?.calculatedDose, "100 μg")
    }

    func test_malignant_hyperthermia_dantrolene_weight_based() {
        guard let p = EmergencyProtocolEngine.generate(for: 70, id: "malignant_hyperthermia") else {
            XCTFail(); return
        }
        let dantrolene = p.drugSteps.first { $0.drugName == "丹曲林" }
        XCTAssertNotNil(dantrolene)
        // 70 × 2.5 = 175 mg
        XCTAssertEqual(dantrolene?.calculatedDose, "175 mg")
    }

    func test_LAST_lipid_emulsion_doses() {
        guard let p = EmergencyProtocolEngine.generate(for: 70, id: "last") else {
            XCTFail(); return
        }
        let bolus = p.drugSteps.first { $0.route == "IV" }
        let infusion = p.drugSteps.first { $0.route == "IV 输注" }
        XCTAssertNotNil(bolus)
        XCTAssertNotNil(infusion)
        XCTAssertEqual(bolus?.calculatedDose, "105 mL bolus")    // 70 × 1.5
        XCTAssertEqual(infusion?.calculatedDose, "17.5 mL/min")   // 70 × 0.25
    }

    func test_massive_hemorrhage_FFP_weight_based() {
        guard let p = EmergencyProtocolEngine.generate(for: 70, id: "massive_hemorrhage") else {
            XCTFail(); return
        }
        let ffp = p.drugSteps.first { $0.drugName == "FFP" }
        XCTAssertNotNil(ffp)
        XCTAssertEqual(ffp?.calculatedDose, "1050 mL")  // 70 × 15
    }

    func test_tranexamic_acid_is_fixed_1g() {
        guard let p = EmergencyProtocolEngine.generate(for: 70, id: "massive_hemorrhage") else {
            XCTFail(); return
        }
        let txa = p.drugSteps.first { $0.drugName == "氨甲环酸" }
        XCTAssertNotNil(txa)
        XCTAssertEqual(txa?.calculatedDose, "1g")
    }

    func test_high_spinal_has_four_drug_steps() {
        guard let p = EmergencyProtocolEngine.generate(for: 70, id: "high_spinal") else {
            XCTFail(); return
        }
        XCTAssertEqual(p.drugSteps.count, 4)
    }

    func test_generate_unknown_id_returns_nil() {
        XCTAssertNil(EmergencyProtocolEngine.generate(for: 70, id: "nonexistent"))
    }
}
