import SwiftUI
import AnesthesiaCalcCore

// MARK: - FluidCardView

struct FluidCardView: View {

    @ObservedObject private var ctx = ClinicalContext.shared
    @State private var fastingHours: Double = 8
    @State private var surgeryType: SurgeryInvasiveness = .moderate
    @State private var surgeryMinutes: Int = 120
    @State private var isExpanded: Bool = false

    private var result: FluidPlan? {
        guard let p = ctx.patient else { return nil }
        return FluidManagementCalculator.calculate(FluidInput(
            weightKg: p.actualWeight,
            fastingHours: fastingHours,
            surgeryType: surgeryType,
            estimatedSurgeryMinutes: surgeryMinutes
        ))
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label("液体管理", systemImage: "ivfluid.bag.fill")
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
                    Stepper("禁食 \(String(format: "%.0f", fastingHours))h", value: $fastingHours, in: 2...24, step: 1)
                        .font(.caption)
                    Picker("手术", selection: $surgeryType) {
                        ForEach(SurgeryInvasiveness.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }
            }

            if let r = result {
                VStack(spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("术中 \(String(format: "%.0f", r.hourlyTotalML)) mL/h")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                            Text("维持 \(String(format: "%.0f", r.hourlyMaintenanceML)) + 第三间隙 \(String(format: "%.0f", r.thirdSpaceRateMLPerH)) mL/h")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    HStack {
                        Text("术前缺失 \(String(format: "%.0f", r.fastingDeficitML)) mL → 首时补 \(String(format: "%.0f", r.firstHourReplacementML)) mL")
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                    }
                    Text(r.formulaTrace)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("输入患者体重以计算液体方案")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
