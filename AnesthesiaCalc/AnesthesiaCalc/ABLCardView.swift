import SwiftUI
import AnesthesiaCalcCore

// MARK: - ABLCardView

struct ABLCardView: View {

    @ObservedObject private var ctx = ClinicalContext.shared
    @State private var preoperativeHct: Double = 0.40
    @State private var targetHct: Double = 0.25
    @State private var isExpanded: Bool = false

    private var result: ABLResult? {
        guard let p = ctx.patient, preoperativeHct > 0 else { return nil }
        let input = ABLInput(
            weightKg: p.actualWeight,
            sex: p.sex,
            age: p.age,
            preoperativeHct: preoperativeHct,
            preoperativeHb: preoperativeHct * 3.3,
            targetHct: targetHct
        )
        return ABLCalculator.calculate(input)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label("允许失血量 (ABL)", systemImage: "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { isExpanded.toggle() } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }

            if isExpanded {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("术前 Hct").font(.caption)
                        Picker("", selection: $preoperativeHct) {
                            ForEach([0.30, 0.33, 0.35, 0.38, 0.40, 0.42, 0.45, 0.48, 0.50, 0.55], id: \.self) { v in
                                Text(String(format: "%.2f", v)).tag(v)
                            }
                        }.pickerStyle(.menu)
                    }
                    HStack(spacing: 4) {
                        Text("目标").font(.caption)
                        Picker("", selection: $targetHct) {
                            Text("0.25 (常规)").tag(0.25)
                            Text("0.30 (心血管)").tag(0.30)
                        }.pickerStyle(.menu)
                    }
                }
            }

            if let r = result {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ABL \(String(format: "%.0f", r.allowableBloodLoss)) mL")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                        Text("EBV \(String(format: "%.0f", r.estimatedBloodVolume)) mL · 可失 \(String(format: "%.0f", r.bloodLossAsPercentage))%")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(r.formulaTrace)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .frame(maxWidth: 140, alignment: .trailing)
                }
            } else {
                Text("输入术前 Hct 并展开以计算")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
