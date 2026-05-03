//
//  ContentView.swift
//  AnesthesiaCalc
//
//  Created by 虞家琦 on 2026/5/2.
//

import SwiftUI
import AnesthesiaCalcCore

struct CalculatorHomeView: View {

    // ── Patient identity ──────────────────────────────────────────────────
    @State private var patientName:     String = ""
    @State private var hospitalNumber:  String = ""

    // ── Primary patient anthropometrics ───────────────────────────────────
    @State private var patientWeight: Double = 70.0
    @State private var patientHeight: Double = 170.0
    @State private var isMale:        Bool   = true

    // ── String backing for numeric TextFields ─────────────────────────────
    // TextFields bind to String for smooth per-keystroke UX;
    // onChange syncs each String → its canonical Double @State var.
    @State private var weightInput = "70"
    @State private var heightInput = "170"
    @State private var ageText     = "40"

    // ── Sheet / alert presentation ────────────────────────────────────────
    @State private var showImportSheet:   Bool   = false
    @State private var showArchiveAlert:  Bool   = false
    @State private var archiveAlertMessage: String = ""

    // ── Shared managers ───────────────────────────────────────────────────
    @StateObject private var drugManager    = DrugManager.shared
    @StateObject private var historyManager = HistoryManager.shared

    private let calculator = DrugCalculator()

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Derived state
    // ══════════════════════════════════════════════════════════════════════

    private var patient: Patient? {
        guard patientWeight > 0, patientHeight > 0,
              let age = Int(ageText), age >= 0 else { return nil }
        return Patient(weight: patientWeight, height: patientHeight,
                       age: age, sex: isMale ? .male : .female)
    }

    private var weightSummary: String? {
        guard let p = patient else { return nil }
        return String(format: "BMI %.1f  ·  IBW %.1f kg  ·  LBW %.1f kg",
                      p.bmi, p.idealBodyWeight, p.leanBodyWeight)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Body
    // ══════════════════════════════════════════════════════════════════════

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    patientCard
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
                    Button(action: archiveCurrentPatient) {
                        Label("归档", systemImage: "doc.badge.plus")
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
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportPatientSheet(records: historyManager.records) { record in
                    applyRecord(record)
                    showImportSheet = false
                }
            }
            .alert(archiveAlertMessage, isPresented: $showArchiveAlert) {
                Button("好", role: .cancel) {}
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
                CompactTextField(icon: "person.fill",  title: "姓名",   placeholder: "请输入", text: $patientName)
                CompactTextField(icon: "number",       title: "住院号", placeholder: "请输入", text: $hospitalNumber)

                // Row 2 — anthropometrics
                CompactTextField(icon: "scalemass.fill", title: "体重 (kg)", placeholder: "70",
                                 text: $weightInput, keyboard: .decimalPad)
                    .onChange(of: weightInput) { _, v in
                        let s = v.replacingOccurrences(of: ",", with: ".")
                        if let d = Double(s), d > 0 { patientWeight = d }
                    }
                CompactTextField(icon: "ruler.fill", title: "身高 (cm)", placeholder: "170",
                                 text: $heightInput, keyboard: .decimalPad)
                    .onChange(of: heightInput) { _, v in
                        let s = v.replacingOccurrences(of: ",", with: ".")
                        if let d = Double(s), d > 0 { patientHeight = d }
                    }

                // Row 3 — age + gender
                CompactTextField(icon: "calendar", title: "年龄 (岁)", placeholder: "40",
                                 text: $ageText, keyboard: .numberPad)
                CompactGenderPicker(isMale: $isMale)
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
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(drugManager.activeDrugs) { drug in
                DrugCard(drug: drug, patient: patient, calculator: calculator)
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: — Archive / Import helpers
    // ══════════════════════════════════════════════════════════════════════

    /// One-tap archive: updates an existing record if hospitalNumber matches,
    /// otherwise inserts a new minimal CaseRecord.
    private func archiveCurrentPatient() {
        let ageStr = ageText.isEmpty ? "0岁" : "\(ageText)岁"
        if !hospitalNumber.isEmpty,
           let idx = historyManager.records.firstIndex(where: {
               $0.hospitalNumber == hospitalNumber
           }) {
            historyManager.update(
                at: idx,
                weight: patientWeight,
                height: patientHeight,
                age:    ageStr,
                name:   patientName.isEmpty ? nil : patientName
            )
            archiveAlertMessage = "已更新该患者信息"
        } else {
            historyManager.save(CaseRecord(
                patientName:    patientName.isEmpty ? "佚名" : patientName,
                hospitalNumber: hospitalNumber,
                age:            ageStr,
                surgery:        "",
                conditions:     [],
                anesthesiaPlan: "",
                weightKg:       patientWeight,
                heightCm:       patientHeight
            ))
            archiveAlertMessage = "已创建新患者档案"
        }
        showArchiveAlert = true
    }

    /// Populate all patient fields from a tapped CaseRecord.
    private func applyRecord(_ record: CaseRecord) {
        patientName    = record.patientName
        hospitalNumber = record.hospitalNumber

        let rawAge = record.age
            .replacingOccurrences(of: "岁", with: "")
            .trimmingCharacters(in: .whitespaces)
        ageText = rawAge.isEmpty ? "40" : rawAge

        if let w = record.weightKg, w > 0 {
            patientWeight = w
            weightInput   = w.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", w) : String(format: "%.1f", w)
        }
        if let h = record.heightCm, h > 0 {
            patientHeight = h
            heightInput   = h.truncatingRemainder(dividingBy: 1) == 0
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
// MARK: — DrugCard
// ══════════════════════════════════════════════════════════════════════════

private struct DrugCard: View {
    let drug:       AnesthesiaDrug
    let patient:    Patient?
    let calculator: DrugCalculator

    @State private var storedDoseType: DoseType? = nil

    private var availableDoseTypes: [DoseType] {
        // Prefer embedded activeRules; fall back to AIRuleEngine for legacy drugs.
        let activeDoseTypes = Set(drug.activeRules.map { $0.doseType })
        if !activeDoseTypes.isEmpty {
            return DoseType.allCases.filter { activeDoseTypes.contains($0.rawValue) }
        }
        return DoseType.allCases.filter {
            AIRuleEngine.shared.dosageRule(for: drug, doseType: $0) != nil
        }
    }

    private var selectedDoseType: DoseType {
        let avail = availableDoseTypes
        if let stored = storedDoseType, avail.contains(stored) { return stored }
        return avail.first ?? .induction
    }

    private var doseRange: DrugDoseRange? {
        guard let p = patient else { return nil }
        return calculator.calculateDose(patient: p, drug: drug, doseType: selectedDoseType)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            Divider().padding(.horizontal, 16)
            resultSection
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(drug.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                scenarioPicker
            }
            Text(concentrationLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var concentrationLabel: String {
        let c = drug.defaultConcentration
        let u = drug.concentrationUnit
        if c < 1 {
            return String(format: "%.3g %@  (%g mcg/mL)", c, u, c * 1000)
        }
        return String(format: "%g %@", c, u)
    }

    @ViewBuilder
    private var scenarioPicker: some View {
        if availableDoseTypes.count > 1 {
            Menu {
                ForEach(availableDoseTypes, id: \.self) { type in
                    Button(action: { storedDoseType = type }) {
                        if type == selectedDoseType {
                            Label(type.displayName, systemImage: "checkmark")
                        } else {
                            Text(type.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(selectedDoseType.displayName)
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9).weight(.bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(Color.accentColor)
            }
        } else {
            Text(selectedDoseType.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 7))
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let r = doseRange {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(volumeString(for: r))
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.accentColor)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    if r.wasClampedByAbsoluteMax {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Text(r.displayString)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(weightBasisLabel(for: r))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "keyboard")
                    .foregroundStyle(.tertiary)
                Text("请输入患者信息")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    private func volumeString(for r: DrugDoseRange) -> String {
        let toMg  = DoseUnit(rawValue: r.unit)?.toMgFactor ?? 1.0
        let conc  = drug.defaultConcentration
        let minMl = (r.minDose * toMg) / conc
        let maxMl = (r.maxDose * toMg) / conc
        let suffix = "mL" + r.doseInterval.displaySuffix
        if abs(minMl - maxMl) < 1e-9 {
            return String(format: "%.1f \(suffix)", minMl)
        }
        return String(format: "%.1f – %.1f \(suffix)", minMl, maxMl)
    }

    private func weightBasisLabel(for r: DrugDoseRange) -> String {
        let basis: String
        switch r.weightBase {
        case .totalBodyWeight: basis = "实际体重 (TBW)"
        case .idealBodyWeight: basis = "理想体重 (IBW)"
        case .leanBodyWeight:  basis = "瘦体重 (LBW)"
        }
        return "\(basis)  \(String(format: "%.1f", r.weightUsed)) kg"
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: — Preview
// ══════════════════════════════════════════════════════════════════════════

#Preview {
    CalculatorHomeView()
}
