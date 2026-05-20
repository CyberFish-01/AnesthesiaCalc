import SwiftUI
import AnesthesiaCalcCore

// MARK: - AirwayCardView

struct AirwayCardView: View {

    @ObservedObject private var ctx = ClinicalContext.shared
    @State private var showSheet = false

    // Input state
    @State private var mallampati: MallampatiClass = .i
    @State private var mouthOpening: Double = 4.5
    @State private var tmd: Double = 7.0
    @State private var neckExt: NeckExtensionGrade = .normal
    @State private var ulbt: ULBTClass = .i
    @State private var dentition: DentitionRisk = .normal
    @State private var hasBeard: Bool = false
    @State private var snores: Bool = false
    @State private var knownDA: Bool = false
    @State private var isPregnant: Bool = false
    @State private var neckRadiation: Bool = false
    @State private var hasOSA: Bool = false

    private var assessment: AirwayRiskAssessment? {
        guard let p = ctx.patient else { return nil }
        let exam = AirwayExam(
            mallampati: mallampati,
            mouthOpeningCm: mouthOpening,
            thyromentalDistanceCm: tmd,
            neckExtension: neckExt,
            upperLipBite: ulbt,
            dentition: dentition,
            hasBeard: hasBeard,
            snoresHeavily: snores,
            knownDifficultAirway: knownDA,
            isPregnant: isPregnant,
            hasNeckRadiation: neckRadiation,
            hasOSA: hasOSA
        )
        return AirwayAssessmentEngine.assess(exam: exam, bmi: p.bmi)
    }

    private var tierColor: Color {
        guard let a = assessment else { return .secondary }
        switch a.riskTier {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label("气道评估", systemImage: "lungs.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let a = assessment {
                    HStack(spacing: 4) {
                        Circle().fill(tierColor).frame(width: 8, height: 8)
                        Text(a.riskTier == .low ? "低风险" : a.riskTier == .moderate ? "中风险" : "高风险")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(tierColor)
                        Text(a.recommendation.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("未评估")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Button { showSheet = true } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showSheet) {
            airwaySheet
                .presentationDetents([.medium, .large])
        }
    }

    private var airwaySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Inputs
                    Group {
                        pickerRow("Mallampati", selection: $mallampati)
                        stepperRow("张口度", value: $mouthOpening, range: 1...8, step: 0.5, unit: "cm")
                        stepperRow("甲颏距", value: $tmd, range: 3...12, step: 0.5, unit: "cm")
                        pickerRow("颈活动度", selection: $neckExt)
                        pickerRow("上唇咬合", selection: $ulbt)
                        pickerRow("牙齿", selection: $dentition)
                    }
                    Group {
                        Toggle("络腮胡", isOn: $hasBeard)
                        Toggle("鼾症", isOn: $snores)
                        Toggle("OSA", isOn: $hasOSA)
                        Toggle("困难气道史", isOn: $knownDA)
                        Toggle("妊娠", isOn: $isPregnant)
                        Toggle("颈部放疗后", isOn: $neckRadiation)
                    }
                    .font(.subheadline)

                    // Result
                    if let a = assessment {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle().fill(tierColor).frame(width: 14, height: 14)
                                Text(a.riskTier == .low ? "低风险" : a.riskTier == .moderate ? "中风险" : "高风险")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(tierColor)
                                Spacer()
                                Text("评分 \(a.score)/6")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("推荐：\(a.recommendation.rawValue)")
                                .font(.headline)
                            Text("插管困难概率：\(String(format: "%.0f", a.predictedDifficultLaryngoscopy * 100))% · 面罩通气困难概率：\(String(format: "%.0f", a.predictedDifficultBMV * 100))%")
                                .font(.caption).foregroundStyle(.secondary)
                            if !a.rationale.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("危险因素：").font(.caption.weight(.medium))
                                    ForEach(a.rationale, id: \.self) { r in
                                        Text("• \(r)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("气道评估")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showSheet = false }
                }
            }
        }
    }

    private func pickerRow<T: CaseIterable & RawRepresentable & Hashable>(
        _ label: String, selection: Binding<T>
    ) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Picker("", selection: selection) {
                ForEach(Array(T.allCases), id: \.self) { v in
                    Text(v.rawValue).tag(v)
                }
            }.pickerStyle(.menu)
        }
    }

    private func stepperRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text("\(String(format: "%.1f", value.wrappedValue)) \(unit)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
    }
}
