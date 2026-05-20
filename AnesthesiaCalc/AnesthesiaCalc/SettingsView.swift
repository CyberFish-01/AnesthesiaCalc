//
//  SettingsView.swift
//  AnesthesiaCalc
//

import SwiftUI
import AnesthesiaCalcCore

// ══════════════════════════════════════════════════════════════════════
// MARK: — SettingsView（主入口）
// ══════════════════════════════════════════════════════════════════════

struct SettingsView: View {

    @AppStorage("app_appearance") private var appearanceRaw: Int = 0

    var body: some View {
        NavigationStack {
            List {
                Section("外观") {
                    Picker(selection: $appearanceRaw) {
                        Label("跟随系统", systemImage: "circle.lefthalf.filled").tag(0)
                        Label("浅色模式", systemImage: "sun.max.fill").tag(1)
                        Label("深色模式", systemImage: "moon.fill").tag(2)
                    } label: {
                        Label("界面外观", systemImage: "paintbrush.fill")
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("功能") {
                    NavigationLink {
                        DrugConcentrationSettingsView()
                    } label: {
                        Label("药物浓度与清单设置", systemImage: "pills.fill")
                    }

                    NavigationLink {
                        AISettingsView()
                    } label: {
                        Label("AI 模型与接口设置", systemImage: "cpu.fill")
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — DrugConcentrationSettingsView
// ══════════════════════════════════════════════════════════════════════

struct DrugConcentrationSettingsView: View {

    @ObservedObject private var drugManager = DrugManager.shared
    @Environment(\.editMode) private var editMode
    @State private var showAIDrugSheet    = false
    @State private var showManualDrugSheet = false

    var body: some View {
        Form {
            drugListSection
            addDrugSection
                .disabled(editMode?.wrappedValue.isEditing == true)
        }
        .navigationTitle("药物浓度与清单设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAIDrugSheet) {
            AddDrugPlaceholderView()
        }
        .sheet(isPresented: $showManualDrugSheet) {
            ManualDrugAddView()
        }
    }

    // ── Drug list — split into active / hidden sections ─────────────────

    private var activeDrugIDs: [UUID] {
        drugManager.allDrugs.lazy.filter(\.isActive).map(\.id)
    }

    private var hiddenDrugIDs: [UUID] {
        drugManager.allDrugs.lazy.filter { !$0.isActive }.map(\.id)
    }

    private func binding(for drugID: UUID) -> Binding<AnesthesiaDrug> {
        Binding(
            get: { drugManager.allDrugs.first(where: { $0.id == drugID }) ?? drugManager.allDrugs[0] },
            set: { newValue in
                if let idx = drugManager.allDrugs.firstIndex(where: { $0.id == drugID }) {
                    drugManager.allDrugs[idx] = newValue
                }
            }
        )
    }

    private var drugListSection: some View {
        Group {
            if !activeDrugIDs.isEmpty {
                Section {
                    ForEach(activeDrugIDs, id: \.self) { drugID in
                        DrugDisclosureRow(
                            drug: binding(for: drugID),
                            onToggle: { drugManager.toggleActive(drugID) }
                        )
                        .id(drugID)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { activeDrugIDs[$0] }
                        drugManager.deleteDrugs(Set(ids))
                    }
                } header: {
                    Text("已启用药物 (\(activeDrugIDs.count))")
                }
                .transition(.opacity)
            }

            if !hiddenDrugIDs.isEmpty {
                Section {
                    ForEach(hiddenDrugIDs, id: \.self) { drugID in
                        DrugDisclosureRow(
                            drug: binding(for: drugID),
                            onToggle: { drugManager.toggleActive(drugID) }
                        )
                        .id(drugID)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { hiddenDrugIDs[$0] }
                        drugManager.deleteDrugs(Set(ids))
                    }
                } header: {
                    Text("已隐藏药物 (\(hiddenDrugIDs.count))")
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: activeDrugIDs)
        .animation(.default, value: hiddenDrugIDs)
    }

    // ── Add drug — dual-track menu ─────────────────────────────────────

    private var addDrugSection: some View {
        Section {
            // AI add
            Button {
                showAIDrugSheet = true
            } label: {
                Label("✨ AI 辅助添加药物", systemImage: "sparkles")
                    .foregroundStyle(Color.accentColor)
            }

            // Manual add
            Button {
                showManualDrugSheet = true
            } label: {
                Label("✍️ 手动添加药物", systemImage: "pencil")
                    .foregroundStyle(.primary)
            }
        } footer: {
            Text("AI 辅助：输入药名由 AI 自动查询临床剂量规则。手动添加：自行填写药物信息和经验规则。")
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — DrugDisclosureRow
// ══════════════════════════════════════════════════════════════════════

private struct DrugDisclosureRow: View {

    @Binding var drug: AnesthesiaDrug
    var onToggle: (() -> Void)?
    @Environment(\.editMode) private var editMode

    // String-backed concentration field avoids the SwiftUI Form quirk where
    // TextField(value:format:) gets extracted as a separate list row.
    @State private var concText: String = ""
    @State private var isExpanded = false

    /// Rules to display based on the current active source.
    private var displayedRules: [DosageRule] {
        switch drug.activeRuleSource {
        case .ai:     return drug.aiRules.sorted { $0.doseType < $1.doseType }
        case .manual: return drug.manualRules.sorted { $0.doseType < $1.doseType }
        }
    }

    var body: some View {
        if editMode?.wrappedValue.isEditing == true {
            editModeRow
        } else {
            normalRow
        }
    }

    // ── Edit mode: flat row, no expansion, Toggle still interactive ──────

    private var editModeRow: some View {
        HStack(spacing: 8) {
            Label(drug.name, systemImage: "pills.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(drug.isActive ? .primary : .secondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { drug.isActive },
                set: { _ in onToggle?() }
            ))
            .labelsHidden()
            .scaleEffect(0.85)
            .fixedSize()
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    // ── Normal mode: DisclosureGroup + separate Toggle ───────────────────

    private var normalRow: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            disclosureContent
        } label: {
            Label(drug.name, systemImage: "pills.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(drug.isActive ? .primary : .secondary)
        }
        .disabled(!drug.isActive)
    }

    // ── Shared detail content ────────────────────────────────────────────

    private var disclosureContent: some View {
        Group {
            // Rule-source switch
            Picker("规则来源", selection: $drug.activeRuleSource) {
                Text("AI 规则").tag(RuleSource.ai)
                Text("手动规则").tag(RuleSource.manual)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)

            // Concentration
            HStack(spacing: 10) {
                Image(systemName: "drop.circle")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text("浓度")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if drug.defaultConcentration == 0 {
                    Text(drug.concentrationUnit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("浓度", text: $concText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .font(.subheadline.weight(.medium))
                        .frame(width: 72)
                        .onAppear {
                            let v = drug.defaultConcentration
                            concText = v.truncatingRemainder(dividingBy: 1) == 0
                                ? String(format: "%.0f", v)
                                : String(format: "%g", v)
                        }
                        .onChange(of: concText) { _, s in
                            let normalized = s.replacingOccurrences(of: ",", with: ".")
                            if let d = Double(normalized), d > 0 {
                                drug.defaultConcentration = d
                            }
                        }
                    Text(drug.concentrationUnit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            // Rule list
            if displayedRules.isEmpty {
                Label(
                    drug.activeRuleSource == .ai
                        ? "暂无 AI 规则，可通过【AI 辅助添加】生成"
                        : "暂无手动规则，点击【手动添加药物】编写",
                    systemImage: "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            } else {
                Text(drug.activeRuleSource == .ai ? "AI 生成规则" : "手动经验规则")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(displayedRules, id: \.doseType) { rule in
                    AIRuleRow(rule: rule)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — AIRuleRow
// ══════════════════════════════════════════════════════════════════════

private struct AIRuleRow: View {

    let rule: DosageRule

    private var typeLabel: String {
        DoseType(rawValue: rule.doseType)?.displayName ?? rule.doseType
    }

    private var doseRangeText: String {
        let min = formatDose(rule.minMultiplier)
        let max = formatDose(rule.maxMultiplier)
        let interval: String
        switch rule.doseInterval {
        case .bolus:     interval = ""
        case .perHour:   interval = "/h"
        case .perMinute: interval = "/min"
        }
        return "\(min) – \(max) \(rule.unit)/kg\(interval)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(typeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())

                Text(doseRangeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }

            if let note = rule.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDose(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%g", value)
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — ManualDrugAddView
// ══════════════════════════════════════════════════════════════════════

struct ManualDrugAddView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var drugManager = DrugManager.shared

    // Drug basics
    @State private var drugName:    String = ""
    @State private var concText:    String = ""
    @State private var concUnit:    String = "mg/mL"

    // Pending rules
    @State private var pendingRules: [DosageRule] = []
    @State private var showRuleForm: Bool = false

    private var canSave: Bool {
        !drugName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && Double(concText) != nil
        && !pendingRules.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Drug basic info ──────────────────────────────────────
                Section("药物基本信息") {
                    LabeledContent("药物名称") {
                        TextField("例：右美托咪定", text: $drugName)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("浓度") {
                        HStack(spacing: 6) {
                            TextField("数值", text: $concText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 72)
                            Picker("单位", selection: $concUnit) {
                                Text("mg/mL").tag("mg/mL")
                                Text("μg/mL").tag("mcg/mL")
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }

                // ── Rules ────────────────────────────────────────────────
                Section {
                    if pendingRules.isEmpty {
                        Label("尚未添加任何规则", systemImage: "tray")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pendingRules, id: \.doseType) { rule in
                            AIRuleRow(rule: rule)
                        }
                        .onDelete { pendingRules.remove(atOffsets: $0) }
                    }

                    Button {
                        showRuleForm = true
                    } label: {
                        Label("添加新规则", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                } header: {
                    Text("剂量规则")
                } footer: {
                    Text("可添加多条规则覆盖不同临床场景（诱导 / 维持 / 镇静等）。左滑可删除。")
                }

                // ── Save ─────────────────────────────────────────────────
                Section {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Text("保存并加入清单")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fontWeight(.semibold)
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("手动添加药物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showRuleForm) {
                ManualRuleFormView(
                    drugName: drugName.trimmingCharacters(in: .whitespacesAndNewlines),
                    concentrationMgPerMl: {
                        let val = Double(concText) ?? 1.0
                        // If unit is mcg/mL, convert to mg/mL
                        return concUnit == "mcg/mL" ? val / 1000.0 : val
                    }(),
                    existingDoseTypes: Set(pendingRules.map { $0.doseType })
                ) { newRule in
                    pendingRules.removeAll { $0.doseType == newRule.doseType }
                    pendingRules.append(newRule)
                }
            }
        }
    }

    private func saveAndDismiss() {
        let concentration = Double(concText) ?? 1.0
        let concMgPerMl   = concUnit == "mcg/mL" ? concentration / 1000.0 : concentration
        let trimmedName   = drugName.trimmingCharacters(in: .whitespacesAndNewlines)

        var drug = AnesthesiaDrug(
            name:                 trimmedName,
            defaultConcentration: concMgPerMl,
            concentrationUnit:    concUnit,
            manualRules:          pendingRules,
            activeRuleSource:     .manual
        )

        // Back-fill drug name in each rule
        drug.manualRules = pendingRules.map {
            var r = $0; r.drug = trimmedName; return r
        }

        drugManager.allDrugs.append(drug)
        dismiss()
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — ManualRuleFormView
// ══════════════════════════════════════════════════════════════════════

private struct ManualRuleFormView: View {

    let drugName: String
    let concentrationMgPerMl: Double
    let existingDoseTypes: Set<String>
    let onSave: (DosageRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var doseType:    DoseType    = .induction
    @State private var minText:     String      = ""
    @State private var maxText:     String      = ""
    @State private var weightBase:  WeightBase  = .totalBodyWeight
    @State private var unit:        String      = "mg"
    @State private var doseInterval: DoseInterval = .bolus

    private var canSave: Bool {
        guard let mn = Double(minText), let mx = Double(maxText) else { return false }
        return mn > 0 && mx >= mn
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("适用场景") {
                    Picker("场景", selection: $doseType) {
                        ForEach(DoseType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    if existingDoseTypes.contains(doseType.rawValue) {
                        Label("已存在该场景的规则，保存后将覆盖", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("剂量参数") {
                    LabeledContent("最小 (/kg)") {
                        TextField("例：1.5", text: $minText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    LabeledContent("最大 (/kg)") {
                        TextField("例：2.5", text: $maxText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    Picker("剂量单位", selection: $unit) {
                        Text("mg").tag("mg")
                        Text("μg").tag("mcg")
                    }
                    Picker("体重基准", selection: $weightBase) {
                        Text("实际体重 (TBW)").tag(WeightBase.totalBodyWeight)
                        Text("理想体重 (IBW)").tag(WeightBase.idealBodyWeight)
                        Text("瘦体重 (LBW)").tag(WeightBase.leanBodyWeight)
                    }
                    Picker("给药方式", selection: $doseInterval) {
                        Text("单次推注").tag(DoseInterval.bolus)
                        Text("持续输注 /h").tag(DoseInterval.perHour)
                        Text("持续输注 /min").tag(DoseInterval.perMinute)
                    }
                }
            }
            .navigationTitle("添加规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let rule = DosageRule(
                            drug:                 drugName.isEmpty ? nil : drugName,
                            doseType:             doseType.rawValue,
                            minMultiplier:        Double(minText) ?? 0,
                            maxMultiplier:        Double(maxText) ?? 0,
                            weightBase:           weightBase,
                            unit:                 unit,
                            concentrationMgPerMl: concentrationMgPerMl,
                            absoluteMaxDose:      nil,
                            ageAdjustments:       [],
                            doseInterval:         doseInterval
                        )
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — PromptEditorRow
// ══════════════════════════════════════════════════════════════════════

/// A collapsible row inside a Form that exposes a `TextEditor` for editing
/// an AI system prompt. Tap the header to expand/collapse.
private struct PromptEditorRow: View {

    let icon: String
    let title: String
    let subtitle: String
    @Binding var text: String
    let defaultText: String

    @State private var isExpanded = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $text)
                    .font(.footnote.monospaced())
                    .frame(minHeight: 180)
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if !defaultText.isEmpty {
                    Button {
                        text = defaultText
                    } label: {
                        Label("恢复默认提示词", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                } else {
                    Button {
                        text = ""
                    } label: {
                        Label("清空（使用内置默认）", systemImage: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 6)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isEditorFocused = false }
                        .font(.body.bold())
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !text.isEmpty {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                        .font(.caption)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — AISettingsView
// ══════════════════════════════════════════════════════════════════════

private let aiDefaultSystemPrompt = """
    你是一位资深的三甲医院麻醉科主治医师。
    根据最新临床麻醉指南（ASA / 中华医学会麻醉学分会 / ESAIC / SmPC），为指定药物生成剂量规则。

    严格规则：
    1. 只返回合法 JSON，不含 markdown、注释、解释文字。
    2. 所有数值必须是 JSON 数字，禁止用字符串表示数值。
    3. doseType 只能是以下英文值之一：induction / maintenance / intubation / sedation / analgesia / antagonism
    4. weightBase 只能是：TBW / IBW / LBW
    5. unit 只能是：mg / mcg
    6. doseInterval 只能是：bolus / perHour / perMinute
    7. ageAdjustments.scalingFactor 必须 >0 且 ≤1（只减量）。
    8. 可选字段（absoluteMaxDose、ageAdjustments）不适用时直接省略，不要写 null。
    9. 尽可能完整覆盖该药物所有临床适用的 doseType。

    JSON 结构：
    {
      "drug": {
        "name": "中文名 (英文名)",
        "defaultConcentration": 数值(mg/mL),
        "concentrationUnit": "mg/mL"
      },
      "rules": [{
        "doseType": "英文值",
        "minMultiplier": 数值,
        "maxMultiplier": 数值,
        "weightBase": "TBW/IBW/LBW",
        "unit": "mg/mcg",
        "concentrationMgPerMl": 数值,
        "doseInterval": "bolus/perHour/perMinute"
      }]
    }
    """

struct AISettingsView: View {

    @AppStorage("ai_api_url")       private var apiURL       = "https://api.openai.com/v1/chat/completions"
    @AppStorage("ai_api_key")       private var apiKey       = ""
    @AppStorage("ai_model_name")    private var modelName    = "deepseek-chat"
    // Per-module system prompts (empty = use built-in default)
    @AppStorage("ai_system_prompt") private var calcPrompt    = aiDefaultSystemPrompt
    @AppStorage("ai_decision_prompt") private var decisionPrompt = ""
    @AppStorage("ai_qa_prompt")     private var qaPrompt     = ""

    var body: some View {
        Form {
            apiConfigSection
            promptsSection
        }
        .navigationTitle("AI 模型与接口设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var apiConfigSection: some View {
        Section(header: Text("API 配置")) {
            LabeledContent("接口地址") {
                TextField("https://api.openai.com/v1/chat/completions", text: $apiURL)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            LabeledContent("API 密钥") {
                SecureField("sk-...", text: $apiKey)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            LabeledContent("模型") {
                TextField("gpt-4o-mini", text: $modelName)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }

    // ── Per-module collapsible prompt editors ──────────────────────────

    private var promptsSection: some View {
        Section {
            PromptEditorRow(
                icon: "scalemass.fill",
                title: "计算模块",
                subtitle: "AI 辅助添加药物规则",
                text: $calcPrompt,
                defaultText: aiDefaultSystemPrompt
            )
            PromptEditorRow(
                icon: "brain.head.profile",
                title: "决策模块",
                subtitle: "AI 麻醉方案生成",
                text: $decisionPrompt,
                defaultText: ""   // shown empty; service uses built-in when empty
            )
            PromptEditorRow(
                icon: "magnifyingglass",
                title: "问答模块",
                subtitle: "医学知识问答",
                text: $qaPrompt,
                defaultText: ""
            )
        } header: {
            Text("各模块系统提示词")
        } footer: {
            Text("留空时各模块使用内置默认提示词。修改后立即生效，下次 AI 请求即采用新提示词。")
        }
    }

}

// ══════════════════════════════════════════════════════════════════════
// MARK: — AddDrugPlaceholderView  (AI add sheet from drug-list page)
// ══════════════════════════════════════════════════════════════════════

private struct AddDrugPlaceholderView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var drugManager = DrugManager.shared

    @State private var drugName: String = ""
    @State private var isLoading: Bool  = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "cpu.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.purple)

                Text("AI 药物录入")
                    .font(.title2.weight(.bold))

                VStack(spacing: 12) {
                    TextField("例如：右美托咪定 或 顺式阿曲库铵", text: $drugName)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .disabled(isLoading)
                        .padding(.horizontal, 24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        isLoading = true
                        errorMessage = nil
                        let name = drugName.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            do {
                                var (drug, rules) = try await AIAssistantService.shared.fetchDrugRules(for: name)
                                // Embed rules into drug.aiRules (dual-track)
                                drug.aiRules = rules
                                await MainActor.run {
                                    drugManager.allDrugs.append(drug)
                                    AIRuleEngine.shared.replaceAllRules(
                                        with: AIRuleEngine.shared.allRules + rules
                                    )
                                    isLoading = false
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    errorMessage = error.localizedDescription
                                    isLoading = false
                                }
                            }
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().progressViewStyle(.circular).tint(.white)
                            } else {
                                Text("AI 智能生成规则").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            drugName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                                ? Color.accentColor.opacity(0.4) : Color.accentColor
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 24)
                    }
                    .disabled(drugName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("✨ AI 辅助添加药物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — Preview
// ══════════════════════════════════════════════════════════════════════

#Preview {
    SettingsView()
}
