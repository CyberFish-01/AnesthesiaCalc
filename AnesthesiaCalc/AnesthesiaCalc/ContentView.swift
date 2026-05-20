//
//  ContentView.swift
//  AnesthesiaCalc
//
//  Created by 虞家琦 on 2026/5/2.
//

import SwiftUI
import AnesthesiaCalcCore

struct CalculatorHomeView: View {

    // ── Single source of truth — global patient context ────────────────────
    @ObservedObject private var ctx = ClinicalContext.shared

    // ── Pediatric mode ─────────────────────────────────────────────────────
    @State private var pediatricOverride: Bool = false

    // ── Consult / Monitor ──────────────────────────────────────────────────
    @State private var showConsultView:      Bool   = false
    @State private var consultPrefillQuestion: String = ""

    // ── Sheet / alert presentation ────────────────────────────────────────
    @State private var showImportSheet:   Bool   = false
    @State private var showArchiveAlert:  Bool   = false
    @State private var archiveAlertMessage: String = ""
    @State private var showEmergencySheet: Bool   = false

    // ── Shared managers ───────────────────────────────────────────────────
    @ObservedObject private var drugManager    = DrugManager.shared
    @ObservedObject private var historyManager = HistoryManager.shared

    private let calculator = DrugCalculator()

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Derived state
    // ══════════════════════════════════════════════════════════════════════

    private var weightSummary: String? {
        guard let p = ctx.patient else { return nil }
        return String(format: "BMI %.1f  ·  IBW %.1f kg  ·  LBW %.1f kg",
                      p.bmi, p.idealBodyWeight, p.leanBodyWeight)
    }

    private var pediatricStatus: PediatricStatus {
        guard let p = ctx.patient else { return .inactive }
        if pediatricOverride { return .active }
        return PediatricLogic.assess(age: p.age, weightKg: p.actualWeight)
    }

    private var isPediatricActive: Bool { pediatricStatus == .active }

    private var monitorAlert: MonitorAlert? {
        ActiveMonitor.check(patient: ctx.patient, drugs: drugManager.activeDrugs)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Body
    // ══════════════════════════════════════════════════════════════════════

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    patientCard
                    if pediatricStatus == .prompt {
                        pediatricPromptButton
                    }
                    if let alert = monitorAlert {
                        ActiveMonitorBanner(alert: alert) {
                            consultPrefillQuestion = alert.prefillQuestion
                            showConsultView = true
                        }
                    }
                    AirwayCardView()
                    ABLCardView()
                    FluidCardView()
                    drugCardsSection
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("麻醉用药计算")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showEmergencySheet = true }) {
                            Label("预案", systemImage: "cross.case.fill")
                        }
                        Button(action: archiveCurrentPatient) {
                            Label("归档", systemImage: "doc.badge.plus")
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .font(.body.bold())
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportPatientSheet(records: historyManager.records) { record in
                    applyRecord(record)
                    showImportSheet = false
                }
            }
            .sheet(isPresented: $showConsultView) {
                ConsultView(initialQuestion: consultPrefillQuestion)
            }
            .sheet(isPresented: $showEmergencySheet) {
                EmergencySheetView()
            }
            .alert(archiveAlertMessage, isPresented: $showArchiveAlert) {
                Button("好", role: .cancel) {}
            }
            .onChange(of: drugManager.allDrugs) { _, _ in
                ctx.syncDrugs(drugManager.activeDrugs)
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Patient Card
    // ══════════════════════════════════════════════════════════════════════

    private var patientCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Section header — label left, import button right
            HStack {
                Label("患者基础信息", systemImage: "person.text.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showImportSheet = true } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                }
            }

            // 2-column symmetric grid
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {

                // Row 1 — identity
                CompactTextField(icon: "person.fill",  title: "姓名",   placeholder: "请输入", text: $ctx.patientName)
                CompactTextField(icon: "number",       title: "住院号", placeholder: "请输入", text: $ctx.hospitalNumber)

                // Row 2 — anthropometrics (P3: zero out on empty/invalid input)
                CompactTextField(icon: "scalemass.fill", title: "体重 (kg)", placeholder: "70",
                                 text: $ctx.weightInput, keyboard: .decimalPad)
                    .onChange(of: ctx.weightInput) { _, v in
                        let s = v.replacingOccurrences(of: ",", with: ".")
                        ctx.patientWeight = (Double(s).map { $0 > 0 ? $0 : 0 }) ?? 0
                    }
                CompactTextField(icon: "ruler.fill", title: "身高 (cm)", placeholder: "170",
                                 text: $ctx.heightInput, keyboard: .decimalPad)
                    .onChange(of: ctx.heightInput) { _, v in
                        let s = v.replacingOccurrences(of: ",", with: ".")
                        ctx.patientHeight = (Double(s).map { $0 > 0 ? $0 : 0 }) ?? 0
                    }

                // Row 3 — age + gender
                CompactTextField(icon: "calendar", title: "年龄 (岁)", placeholder: "40",
                                 text: $ctx.ageText, keyboard: .numberPad)
                CompactGenderPicker(isMale: $ctx.isMale)
            }

            // Derived weight summary
            if let summary = weightSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Drug Cards Section
    // ══════════════════════════════════════════════════════════════════════

    private var drugCardsSection: some View {
        let grouped = groupedDrugs
        let sortedKeys = grouped.keys.sorted { a, b in
            let ia = DrugCatalog.categoryOrder.firstIndex(of: a) ?? Int.max
            let ib = DrugCatalog.categoryOrder.firstIndex(of: b) ?? Int.max
            return ia < ib
        }
        return VStack(spacing: 16) {
            ForEach(sortedKeys, id: \.self) { category in
                VStack(alignment: .leading, spacing: 8) {
                    categoryHeader(category)
                    ForEach(grouped[category] ?? []) { drug in
                        UniversalDrugCardView(
                            drug: drug,
                            patient: ctx.patient,
                            calculator: calculator,
                            isPediatricActive: isPediatricActive
                        )
                    }
                }
            }
        }
    }

    /// Group active drugs by their Chinese pharmacological category.
    private var groupedDrugs: [String: [AnesthesiaDrug]] {
        var map = [String: [AnesthesiaDrug]]()
        for drug in drugManager.activeDrugs {
            let cat = DrugCatalog.category(for: drug.name)
            map[cat, default: []].append(drug)
        }
        // Sort groups by categoryOrder; unknown categories go last
        return map
    }

    private func categoryHeader(_ category: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(category)
                .font(.caption.weight(.semibold))
                .foregroundColor(.accentColor)
        }
        .padding(.top, 4)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Pediatric prompt
    // ══════════════════════════════════════════════════════════════════════

    private var pediatricPromptButton: some View {
        Button {
            pediatricOverride = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "figure.child")
                    .font(.subheadline)
                Text("患者年龄或体重接近儿科范围，点击启用儿科模式")
                    .font(.caption.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Archive / Import helpers
    // ══════════════════════════════════════════════════════════════════════

    /// One-tap archive: upserts the current patient using `hospitalNumber` as
    /// the unique key — merges into an existing record or creates a new one.
    private func archiveCurrentPatient() {
        let ageStr = ctx.ageText.isEmpty ? "0岁" : "\(ctx.ageText)岁"
        let record = CaseRecord(
            patientName:    ctx.patientName.isEmpty ? "佚名" : ctx.patientName,
            hospitalNumber: ctx.hospitalNumber,
            age:            ageStr,
            surgery:        "",
            conditions:     [],
            anesthesiaPlan: "",
            weightKg:       ctx.patientWeight,
            heightCm:       ctx.patientHeight
        )
        archiveAlertMessage = historyManager.upsert(record).message
        showArchiveAlert = true
    }

    /// Populate all patient fields from a tapped CaseRecord.
    private func applyRecord(_ record: CaseRecord) {
        ctx.patientName    = record.patientName
        ctx.hospitalNumber = record.hospitalNumber

        let rawAge = record.age
            .replacingOccurrences(of: "岁", with: "")
            .trimmingCharacters(in: .whitespaces)
        ctx.ageText = rawAge.isEmpty ? "40" : rawAge

        if let w = record.weightKg, w > 0 {
            ctx.patientWeight = w
            ctx.weightInput   = w.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", w) : String(format: "%.1f", w)
        }
        if let h = record.heightCm, h > 0 {
            ctx.patientHeight = h
            ctx.heightInput   = h.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", h) : String(format: "%.1f", h)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: — CompactTextField
// ══════════════════════════════════════════════════════════════════════════

/// Uniform compact input cell: tinted icon on the left, small label + TextField stacked on the right.
/// Used for all six patient-info grid items that require text/numeric entry.
private struct CompactTextField: View {
    let icon:        String
    let title:       String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: — CompactGenderPicker
// ══════════════════════════════════════════════════════════════════════════

/// Compact gender cell styled to match CompactTextField — fits the same grid slot.
/// Tapping opens a Menu; no tinted background on the trigger.
private struct CompactGenderPicker: View {
    @Binding var isMale: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text("性别")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Menu {
                    Button { isMale = true } label: {
                        if isMale { Label("男", systemImage: "checkmark") } else { Text("男") }
                    }
                    Button { isMale = false } label: {
                        if !isMale { Label("女", systemImage: "checkmark") } else { Text("女") }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(isMale ? "男" : "女")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color(UIColor.label))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: — ImportPatientSheet
// ══════════════════════════════════════════════════════════════════════════

/// Modal sheet that lists all saved CaseRecords so the user can tap one to
/// pre-fill the patient card fields.
private struct ImportPatientSheet: View {
    let records:  [CaseRecord]
    let onSelect: (CaseRecord) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "暂无历史病例",
                        systemImage: "tray",
                        description: Text("在 AI 决策页面保存病例后将在此显示")
                    )
                } else {
                    List(records) { record in
                        Button {
                            onSelect(record)
                        } label: {
                            ImportRecordRow(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("导入历史患者")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

/// Single row inside ImportPatientSheet — shows name, hospital number,
/// age/weight/height chips, surgery name, and relative timestamp.
private struct ImportRecordRow: View {
    let record: CaseRecord

    private var relativeDate: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.unitsStyle = .short
        return f.localizedString(for: record.date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(record.patientName)
                    .font(.headline)
                if !record.hospitalNumber.isEmpty {
                    Text("·  \(record.hospitalNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(relativeDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                if !record.age.isEmpty {
                    chip(record.age)
                }
                if let w = record.weightKg {
                    chip(String(format: "%.0f kg", w))
                }
                if let h = record.heightCm {
                    chip(String(format: "%.0f cm", h))
                }
                if !record.surgery.isEmpty {
                    chip(record.surgery)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(UIColor.tertiarySystemGroupedBackground),
                        in: Capsule())
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: — Preview
// ══════════════════════════════════════════════════════════════════════════

#Preview {
    CalculatorHomeView()
}
