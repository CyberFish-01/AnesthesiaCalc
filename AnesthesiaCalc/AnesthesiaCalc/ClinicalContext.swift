import SwiftUI
import Combine
import AnesthesiaCalcCore

// MARK: - ClinicalContext

/// 全局临床上下文单例 — 实时同步计算器页面的患者画像与药物列表，
/// 使问答 (MaLeMeView / ConsultView) 页面初始化时可自动读取当前临床背景。
final class ClinicalContext: ObservableObject {
    static let shared = ClinicalContext()

    @Published var patient: Patient?
    @Published var activeDrugs: [AnesthesiaDrug] = []

    /// 由 ContentView 在每次患者数据变化时调用
    func sync(patient: Patient?, drugs: [AnesthesiaDrug]) {
        self.patient = patient
        self.activeDrugs = drugs
    }

    /// 为问答页构建上下文摘要
    var contextSummary: String {
        var parts: [String] = []
        if let p = patient {
            parts.append("\(p.sex == .male ? "男" : "女")，\(p.age)岁，\(String(format: "%.0f", p.weight))kg，\(String(format: "%.0f", p.height))cm")
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
