import SwiftUI
import Combine
import AnesthesiaCalcCore

// MARK: - ClinicalContext

/// 全局临床上下文单例 — 患者画像与药物列表的唯一权威数据源 (Single Source of Truth)。
///
/// 所有视图通过 `@ObservedObject var ctx = ClinicalContext.shared` 绑定，
/// 确保跨页面（计算器、AI 决策、会诊、问答）数据绝对同步。
final class ClinicalContext: ObservableObject {
    static let shared = ClinicalContext()

    // ── Patient identity ────────────────────────────────────────────────
    @Published var patientName: String = ""
    @Published var hospitalNumber: String = ""

    // ── String-backed TextField bindings ─────────────────────────────────
    @Published var weightInput: String = "70"
    @Published var heightInput: String = "170"
    @Published var ageText: String = "40"
    @Published var isMale: Bool = true

    // ── Canonical Double values (validated from string inputs) ───────────
    @Published var patientWeight: Double = 70.0
    @Published var patientHeight: Double = 170.0

    // ── Drug context ─────────────────────────────────────────────────────
    @Published var activeDrugs: [AnesthesiaDrug] = []

    // ── Derived ──────────────────────────────────────────────────────────
    var patient: PatientContext? {
        guard patientWeight > 0, patientHeight > 0,
              let age = Int(ageText), age >= 0 else { return nil }
        return PatientContext(actualWeight: patientWeight, heightCm: patientHeight,
                              age: age, sex: isMale ? .male : .female)
    }

    /// Backward-compatible sync — used when external code pushes a full patient snapshot.
    func sync(patient: PatientContext?, drugs: [AnesthesiaDrug]) {
        self.activeDrugs = drugs
        guard let p = patient else { return }
        patientWeight = p.actualWeight
        patientHeight = p.heightCm
        isMale = p.sex == .male
        ageText = String(p.age)
        weightInput = p.actualWeight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", p.actualWeight) : String(format: "%.1f", p.actualWeight)
        heightInput = p.heightCm.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", p.heightCm) : String(format: "%.1f", p.heightCm)
    }

    func syncDrugs(_ drugs: [AnesthesiaDrug]) {
        self.activeDrugs = drugs
    }

    /// 为问答页构建上下文摘要
    var contextSummary: String {
        var parts: [String] = []
        if let p = patient {
            parts.append("\(p.sex == .male ? "男" : "女")，\(p.age)岁，\(String(format: "%.0f", p.actualWeight))kg，\(String(format: "%.0f", p.heightCm))cm")
            parts.append("BMI \(String(format: "%.1f", p.bmi))，IBW \(String(format: "%.1f", p.idealBodyWeight))kg")
        }
        if !activeDrugs.isEmpty {
            parts.append("当前药物：" + activeDrugs.map(\.name).joined(separator: "、"))
        }
        return parts.joined(separator: "；")
    }

    var isEmpty: Bool { patient == nil && activeDrugs.isEmpty }

    private init() {}
}
