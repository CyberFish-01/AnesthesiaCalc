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
struct UniversalDrugCardView: View {

    let drug: AnesthesiaDrug
    let patient: Patient?
    let calculator: DrugCalculator

    @State private var selectedDoseType: String = ""

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

    // MARK: Body

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leftSection
            Spacer(minLength: 8)
            rightSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: Left — 药品名+Tag（并排）+ 浓度（layoutPriority 防截断）

    private var leftSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
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
        if c < 1 {
            return String(format: "%g μg/mL", c * 1000)
        }
        return String(format: "%g mg/mL", c)
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
                Text(r.volumeString)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

                Text("\(r.displayString)  ·  \(weightBasisLabel(r.weightBase)) \(String(format: "%.1f", r.weightUsed)) kg")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.trailing)
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
