import SwiftUI
import AnesthesiaCalcCore

// MARK: - ABGTabView

struct ABGTabView: View {

    @State private var pH: String = "7.40"
    @State private var paCO2: String = "40"
    @State private var paO2: String = "90"
    @State private var hco3: String = "24"
    @State private var be: String = "0"
    @State private var lac: String = ""
    @State private var na: String = ""
    @State private var cl: String = ""
    @State private var fio2: Double = 0.21

    private var result: ABGInterpretation? {
        guard let ph = Double(pH), ph > 0,
              let co2 = Double(paCO2), co2 > 0,
              let o2 = Double(paO2), o2 > 0,
              let h = Double(hco3), h > 0,
              let b = Double(be) else { return nil }
        return ABGAnalyzer.analyze(ABGInput(
            pH: ph, paCO2: co2, paO2: o2, hco3: h, baseExcess: b,
            lactate: Double(lac).flatMap { $0 > 0 ? $0 : nil },
            na: Double(na).flatMap { $0 > 0 ? $0 : nil },
            cl: Double(cl).flatMap { $0 > 0 ? $0 : nil },
            fio2: fio2
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    inputSection
                    if let r = result {
                        resultSection(r)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("血气分析")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }.font(.body.bold())
                }
            }
        }
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            Label("动脉血气参数", systemImage: "heart.text.square")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                abgField("pH", $pH, "7.40")
                abgField("PaCO₂", $paCO2, "40")
                abgField("PaO₂", $paO2, "90")
                abgField("HCO₃⁻", $hco3, "24")
                abgField("BE", $be, "0")
                abgField("Lac", $lac, "可选")
                abgField("Na⁺", $na, "可选")
                abgField("Cl⁻", $cl, "可选")
            }

            HStack(spacing: 8) {
                Text("FIO₂").font(.caption)
                Picker("", selection: $fio2) {
                    Text("0.21").tag(0.21)
                    Text("0.30").tag(0.30)
                    Text("0.40").tag(0.40)
                    Text("0.50").tag(0.50)
                    Text("0.60").tag(0.60)
                    Text("0.80").tag(0.80)
                    Text("1.0").tag(1.0)
                }.pickerStyle(.segmented)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    private func abgField(_ label: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .padding(.vertical, 6)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(6)
        }
    }

    private func resultSection(_ r: ABGInterpretation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("判读结果", systemImage: "doc.text.magnifyingglass")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)

            // 主要诊断
            HStack {
                Text("\(r.primaryDisorder.rawValue) · \(r.compensation.rawValue)")
                    .font(.title3.weight(.bold))
                Spacer()
            }

            // AG
            if let ag = r.anionGap {
                HStack {
                    Text("AG = \(String(format: "%.0f", ag))")
                        .font(.subheadline)
                    if ag > 12 { Text("(↑)").foregroundStyle(.orange) }
                    if let dg = r.deltaGap {
                        Text("ΔAG/ΔHCO₃ = \(String(format: "%.2f", dg))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // P/F + A-aDO₂
            HStack {
                Label("P/F \(String(format: "%.0f", r.paO2FiO2Ratio)) · \(r.oxygenationStatus.rawValue)", systemImage: "lungs")
                    .font(.subheadline)
                Spacer()
                Text("A-aDO₂ \(String(format: "%.0f", r.aADO2)) mmHg")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // 乳酸
            if let lr = r.lactateRisk {
                HStack {
                    Label("乳酸 \(lr.rawValue)", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(lr == .severe ? .red : lr == .moderate ? .orange : .secondary)
                }
            }

            // 临床建议
            if !r.clinicalSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("临床建议").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(Array(r.clinicalSuggestions.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundStyle(.orange)
                            Text(s).font(.caption).foregroundStyle(.primary)
                        }
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(8)
            }

            Text(r.formulaExplanation)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}
