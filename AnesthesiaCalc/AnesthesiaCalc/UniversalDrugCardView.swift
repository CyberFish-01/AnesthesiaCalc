import SwiftUI
import AnesthesiaCalcCore

// MARK: - UniversalDrugCardView

/// 通用药品卡片模板 — 横向长条布局，展控分离，零直接数学运算。
///
/// 所有药品强制共用此模板：
/// - 无 Slider 控件，仅展示计算结果区间或固定值
/// - HStack 左右分立：左侧药品信息，右侧核心数值
/// - 纯白底色 + 极轻微弥散阴影，20pt 圆角
/// - 全部计算委托 Core 层 `DrugCalculator`
/// - 集成 RiskEngine 风险预警图标 + 公式溯源 + 微量泵矩阵 + 儿科精度
struct UniversalDrugCardView: View {

    let drug: AnesthesiaDrug
    let patient: Patient?
    let calculator: DrugCalculator
    let isPediatricActive: Bool

    @State private var selectedDoseType: String = ""
    @State private var showRiskPopover: Bool = false
    @State private var showDeepDive: Bool = false

    // MARK: 剂量类型列表

    private var availableDoseTypes: [String] {
        let fromActive = drug.activeRules.map { $0.doseType }
        if !fromActive.isEmpty {
            var seen = Set<String>()
            return fromActive.filter { seen.insert($0).inserted }
        }
        return DoseType.allCases.compactMap { type in
            AIRuleEngine.shared.dosageRule(for: drug, doseType: type) != nil ? type.rawValue : nil
        }
    }

    private var resolvedDoseType: String {
        if selectedDoseType.isEmpty || !availableDoseTypes.contains(selectedDoseType) {
            return availableDoseTypes.first ?? DoseType.induction.rawValue
        }
        return selectedDoseType
    }

    // MARK: 全部计算委托 Core

    private var doseRange: DrugDoseRange? {
        guard let p = patient else { return nil }
        return calculator.calculateDose(patient: p, drug: drug, doseTypeString: resolvedDoseType)
    }

    // MARK: 风险评估

    private var riskAssessment: RiskAssessment? {
        guard let p = patient else { return nil }
        return RiskEngine.assess(patient: p.context, drugName: drug.name)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                leftSection
                Spacer(minLength: 8)
                rightSection
            }

            // 底部信息行：公式溯源 (左) + 微量泵矩阵 (右)
            if let formula = doseRange?.formulaString {
                HStack(spacing: 4) {
                    Text(formula)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer(minLength: 4)
                    if let matrix = doseRange?.infusionMatrixString {
                        Text(matrix)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .layoutPriority(-1)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(.separator), lineWidth: 0.5))
        .onTapGesture {
            if riskAssessment?.hasWarnings == true {
                showRiskPopover = true
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            showDeepDive = true
        }
        .popover(isPresented: $showRiskPopover, arrowEdge: .top) {
            riskPopoverContent
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $showDeepDive) {
            DrugDeepDiveView(drug: drug)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Left — 药品名 + 风险图标 + Tag（并排）+ 浓度

    private var leftSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                riskIcon
                doseTypeTag
            }
            Text(concentrationLabel)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .layoutPriority(1)
    }

    private var displayName: String {
        let name = drug.name
        if let r = name.range(of: " (") { return String(name[..<r.lowerBound]) }
        if let r = name.range(of: "（") { return String(name[..<r.lowerBound]) }
        return name
    }

    private var concentrationLabel: String {
        let c = drug.defaultConcentration
        if c == 0 {
            return drug.concentrationUnit
        }
        if c < 1 {
            return String(format: "%g μg/mL", c * 1000)
        }
        return String(format: "%g mg/mL", c)
    }

    // MARK: 风险图标

    @ViewBuilder
    private var riskIcon: some View {
        if riskAssessment?.hasWarnings == true {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
        }
    }

    // MARK: Tag

    @ViewBuilder
    private var doseTypeTag: some View {
        let label = doseTypeDisplayName(resolvedDoseType)

        if availableDoseTypes.count > 1 {
            Menu {
                ForEach(availableDoseTypes, id: \.self) { type in
                    Button {
                        selectedDoseType = type
                    } label: {
                        if type == resolvedDoseType {
                            Label(doseTypeDisplayName(type), systemImage: "checkmark")
                        } else {
                            Text(doseTypeDisplayName(type))
                        }
                    }
                }
            } label: {
                tagLabel(label, isMenu: true)
            }
        } else {
            tagLabel(label, isMenu: false)
        }
    }

    private func tagLabel(_ text: String, isMenu: Bool) -> some View {
        HStack(spacing: 3) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            if isMenu {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8).weight(.bold))
            }
        }
        .foregroundColor(.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: Right — 核心数值 + 支撑信息

    @ViewBuilder
    private var rightSection: some View {
        if let r = doseRange {
            VStack(alignment: .trailing, spacing: 2) {
                Text(r.volumeString(precision: isPediatricActive ? 2 : 2))
                    .font(.system(size: isPediatricActive ? 24 : 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

                HStack(spacing: 2) {
                    Text("\(r.displayString(precision: isPediatricActive ? 2 : 1))  ·  ")
                    if r.wasAutoRouted {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                        Text("\(weightBasisLabel(r.weightBase)) \(String(format: "%.1f", r.weightUsed)) kg")
                    } else {
                        Text("\(weightBasisLabel(r.weightBase)) \(String(format: "%.1f", r.weightUsed)) kg")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(r.wasAutoRouted ? .blue : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        } else {
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "keyboard")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                Text("请输入患者信息")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: 风险 Popover 内容

    private var riskPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("风险提示")
                .font(.headline)
            if let warnings = riskAssessment?.warnings {
                ForEach(warnings) { warning in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text(warning.message)
                            .font(.callout)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: Helpers (纯枚举映射，零数学)

    private func doseTypeDisplayName(_ raw: String) -> String {
        DoseType(rawValue: raw)?.displayName ?? raw
    }

    private func weightBasisLabel(_ base: WeightBase) -> String {
        switch base {
        case .totalBodyWeight: return "TBW"
        case .idealBodyWeight: return "IBW"
        case .leanBodyWeight:  return "LBW"
        }
    }
}
