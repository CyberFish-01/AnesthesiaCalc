import Foundation
import Observation
import AnesthesiaCalcCore

@Observable
final class CalculatorViewModel {

    // ── Patient inputs ────────────────────────────────────────────────
    var weightText = ""
    var heightText = ""
    var ageText    = ""
    var sex        = BiologicalSex.male

    // ── Drug selection ────────────────────────────────────────────────
    var selectedDrug = AnesthesiaDrug.propofol

    // ── Engine ────────────────────────────────────────────────────────
    private let calculator = DrugCalculator()

    // ── Derived ───────────────────────────────────────────────────────

    var parsedWeight: Double? { Double(weightText).flatMap { $0 > 0 ? $0 : nil } }
    var parsedHeight: Double? { Double(heightText).flatMap { $0 > 0 ? $0 : nil } }
    var parsedAge:    Int?    { Int(ageText).flatMap    { $0 >= 0 ? $0 : nil } }

    /// Returns a fully-formed `Patient` when all inputs are valid, nil otherwise.
    var patient: Patient? {
        guard let w = parsedWeight, let h = parsedHeight, let a = parsedAge else { return nil }
        return Patient(weight: w, height: h, age: a, sex: sex)
    }

    /// Live calculation result — recomputes automatically whenever any input changes.
    /// Returns `nil` when inputs are incomplete or the drug has no legacy rule.
    var result: DoseResult? {
        guard let p = patient else { return nil }
        return calculator.calculateLegacyDose(patient: p, drug: selectedDrug)
    }

    /// Human-readable description of the weight basis actually used.
    var effectiveWeightLabel: String? {
        guard let r = result else { return nil }
        let kg = String(format: "%.1f kg", r.weightUsed)
        switch r.weightBase {
        case .totalBodyWeight: return "实际体重  \(kg)"
        case .idealBodyWeight: return "理想体重 (IBW)  \(kg)"
        case .leanBodyWeight:  return "瘦体重 (LBW)  \(kg)"
        }
    }

    /// Non-nil when at least one age-triggered dose reduction was applied.
    var ageAdjustmentNote: String? {
        guard let r = result, !r.appliedAgeAdjustments.isEmpty else { return nil }
        let pct = Int((1.0 - r.appliedScalingFactor) * 100)
        return "已按年龄（≥\(r.appliedAgeAdjustments[0].ageThreshold)岁）减量 \(pct)%"
    }

    /// IBW and LBW for display in the patient info footer.
    var patientWeightSummary: String? {
        guard let p = patient else { return nil }
        return String(format: "BMI %.1f  |  IBW %.1f kg  |  LBW %.1f kg",
                      p.bmi, p.idealBodyWeight, p.leanBodyWeight)
    }
}
