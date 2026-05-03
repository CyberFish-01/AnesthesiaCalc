//
//  AIDecisionView.swift
//  AnesthesiaCalc
//

import SwiftUI
import AnesthesiaCalcCore

// ══════════════════════════════════════════════════════════════════════
// MARK: — AIDecisionView
// ══════════════════════════════════════════════════════════════════════

struct AIDecisionView: View {

    // ── Free-text input ──────────────────────────────────────────────
    @State private var freeText = ""

    // ── Structured form ───────────────────────────────────────────────
    @State private var isStructuredExpanded = false
    @State private var formName           = ""
    @State private var formHospitalNumber = ""
    @State private var formAge            = ""
    @State private var formSurgery        = ""
    @State private var formConditions     = ""    // comma-separated

    // ── API state ─────────────────────────────────────────────────────
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    // ── Result sheet ──────────────────────────────────────────────────
    @State private var savedRecord: CaseRecord?
    @State private var showResult = false

    // ── History ───────────────────────────────────────────────────────
    @StateObject private var history = HistoryManager.shared

    // ── Focus ─────────────────────────────────────────────────────────
    @FocusState private var isFreeTextFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    freeTextCard
                    structuredFormCard
                    generateButton
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("AI 决策")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CaseHistoryView()) {
                        Image(systemName: "clock.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("历史病例")
                }
            }
            .alert("查询失败", isPresented: $showError, presenting: errorMessage) { _ in
                Button("好的", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
            .sheet(isPresented: $showResult) {
                if let record = savedRecord {
                    DecisionResultSheet(record: record)
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Free-text card
    // ══════════════════════════════════════════════════════════════════

    private var freeTextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("病历描述", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if freeText.isEmpty && !isFreeTextFocused {
                    Text("输入患者大白话病历...\n例如：65岁男性，拟行腹腔镜胆囊切除，有高血压史、对青霉素过敏")
                        .font(.body)
                        .foregroundStyle(Color(UIColor.placeholderText))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $freeText)
                    .focused($isFreeTextFocused)
                    .font(.body)
                    .frame(minHeight: 140, maxHeight: 200)
                    .scrollContentBackground(.hidden)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Structured form card
    // ══════════════════════════════════════════════════════════════════

    private var structuredFormCard: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $isStructuredExpanded) {
                VStack(spacing: 10) {
                    Divider()
                        .padding(.vertical, 4)

                    formField(icon: "person.fill",
                              label: "姓名",
                              placeholder: "患者姓名（选填）",
                              text: $formName)

                    formField(icon: "number",
                              label: "住院号",
                              placeholder: "如：12345678（选填）",
                              text: $formHospitalNumber,
                              keyboardType: .numberPad)

                    formField(icon: "calendar",
                              label: "年龄",
                              placeholder: "如：45岁（选填）",
                              text: $formAge)

                    formField(icon: "cross.case.fill",
                              label: "手术名称",
                              placeholder: "如：腹腔镜胆囊切除术",
                              text: $formSurgery)

                    formField(icon: "exclamationmark.triangle.fill",
                              label: "既往史 / 异常",
                              placeholder: "多项用逗号分隔，如：高血压,糖尿病",
                              text: $formConditions,
                              tint: .orange)
                }
                .padding(.top, 2)
                .padding(.bottom, 4)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .foregroundStyle(.teal)
                    Text("结构化录入（可选）")
                        .font(.subheadline.weight(.medium))
                }
            }
            .tint(.primary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func formField(
        icon: String,
        label: String,
        placeholder: String,
        text: Binding<String>,
        tint: Color = .accentColor,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: text)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .keyboardType(keyboardType)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 8))
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Generate button
    // ══════════════════════════════════════════════════════════════════

    private var generateButton: some View {
        Button(action: generate) {
            Group {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                        Text("AI 生成中...")
                            .font(.headline.weight(.semibold))
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .symbolRenderingMode(.hierarchical)
                        Text("生成 AI 麻醉计划")
                            .font(.headline.weight(.semibold))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canGenerate ? Color.purple : Color.purple.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canGenerate || isLoading)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Logic
    // ══════════════════════════════════════════════════════════════════

    private var canGenerate: Bool {
        !freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !formSurgery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Builds a combined natural-language string from free text + structured fields.
    private func buildCombinedInput() -> String {
        var parts: [String] = []

        let ft = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ft.isEmpty { parts.append("病历描述：\(ft)") }

        let name           = formName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hospitalNumber = formHospitalNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let age            = formAge.trimmingCharacters(in: .whitespacesAndNewlines)
        let surgery        = formSurgery.trimmingCharacters(in: .whitespacesAndNewlines)
        let conds          = formConditions.trimmingCharacters(in: .whitespacesAndNewlines)

        if !name.isEmpty           { parts.append("姓名：\(name)") }
        if !hospitalNumber.isEmpty { parts.append("住院号：\(hospitalNumber)") }
        if !age.isEmpty            { parts.append("年龄：\(age)") }
        if !surgery.isEmpty        { parts.append("手术名称：\(surgery)") }
        if !conds.isEmpty          { parts.append("既往史 / 异常情况：\(conds)") }

        return parts.joined(separator: "\n")
    }

    private func generate() {
        isFreeTextFocused = false
        isLoading = true
        let combined = buildCombinedInput()

        Task {
            do {
                let response = try await AIAssistantService.shared.fetchDecisionPlan(
                    combinedInput: combined
                )
                let record = CaseRecord(
                    patientName:    response.patient.name,
                    hospitalNumber: response.patient.hospitalNumber,
                    age:            response.patient.age,
                    surgery:        response.patient.surgery,
                    conditions:     response.patient.conditions,
                    anesthesiaPlan: response.plan
                )
                await MainActor.run {
                    history.save(record)
                    savedRecord = record
                    isLoading   = false
                    showResult  = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError    = true
                    isLoading    = false
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — DecisionResultSheet
// ══════════════════════════════════════════════════════════════════════

private struct DecisionResultSheet: View {

    let record: CaseRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CaseRecordCard(record: record, initiallyExpanded: true)
                        .padding()
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("麻醉计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — Preview
// ══════════════════════════════════════════════════════════════════════

#Preview {
    AIDecisionView()
}
