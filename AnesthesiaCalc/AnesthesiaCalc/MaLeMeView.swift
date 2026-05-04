//
//  MaLeMeView.swift
//  AnesthesiaCalc
//

import SwiftUI
import AnesthesiaCalcCore

// ══════════════════════════════════════════════════════════════════════
// MARK: — MaLeMeView
// ══════════════════════════════════════════════════════════════════════

struct MaLeMeView: View {

    // ── Input state ───────────────────────────────────────────────────
    @State private var questionText: String = ""
    @FocusState private var isEditorFocused: Bool

    // ── API state ─────────────────────────────────────────────────────
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    // ── Sheet: used for both new results and tapped history rows ──────
    @State private var sheetRecord: QARecord?

    // ── History ───────────────────────────────────────────────────────
    @StateObject private var qaHistory = QAHistoryManager.shared

    // ── Helpers ───────────────────────────────────────────────────────
    private var canSend: Bool {
        !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Body
    // ══════════════════════════════════════════════════════════════════

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        titleSection
                        inputCard
                        if !qaHistory.records.isEmpty {
                            recentSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
                .onTapGesture { isEditorFocused = false }
                .alert("查询失败", isPresented: $showError, presenting: errorMessage) { _ in
                    Button("好的", role: .cancel) {}
                } message: { msg in
                    Text(msg)
                }
                .sheet(item: $sheetRecord) { record in
                    QAResultSheet(record: record)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完成") { isEditorFocused = false }
                    }
                }
            }

            // ── Premium loading overlay ────────────────────────────────
            if isLoading {
                DirectorLoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Title
    // ══════════════════════════════════════════════════════════════════

    private var titleSection: some View {
        VStack(spacing: 6) {
            Text("麻了么")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(.primary)
            Text("为您解答一切麻醉与医学问题")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Input card
    // ══════════════════════════════════════════════════════════════════

    private var inputCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Placeholder
                if questionText.isEmpty && !isEditorFocused {
                    Text("为您解决一切医学问题...")
                        .font(.body)
                        .foregroundStyle(Color(UIColor.placeholderText))
                        .padding(.top, 10)
                        .padding(.leading, 6)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $questionText)
                    .focused($isEditorFocused)
                    .font(.body)
                    .frame(minHeight: 120, maxHeight: 200)
                    .scrollContentBackground(.hidden)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // ── Send button row ────────────────────────────────────
            HStack {
                Spacer()
                Button(action: sendQuestion) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                            .frame(width: 36, height: 36)
                            .background(Color.purple, in: Circle())
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(canSend ? Color.purple : Color.purple.opacity(0.3))
                    }
                }
                .disabled(!canSend || isLoading)
                .animation(.easeInOut(duration: 0.15), value: isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Recent records
    // ══════════════════════════════════════════════════════════════════

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近提问")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink(destination: QAHistoryView()) {
                    Text("查看全部")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
            }

            VStack(spacing: 8) {
                ForEach(qaHistory.records.prefix(3)) { record in
                    Button(action: { sheetRecord = record }) {
                        RecentQARow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }

            NavigationLink(destination: QAHistoryView()) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("查看全部对话记录")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Color.purple)
                .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: — Logic
    // ══════════════════════════════════════════════════════════════════

    private func sendQuestion() {
        isEditorFocused = false
        let question = questionText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            do {
                let response = try await AIAssistantService.shared.fetchMedicalAnswer(
                    question: question
                )
                let record = QARecord(
                    question: question,
                    answer:   response.answer,
                    category: response.category
                )
                qaHistory.save(record)
                sheetRecord  = record
                questionText = ""
            } catch {
                errorMessage = (error as? URLError)?.code == .timedOut
                    ? "网络开小差了，主任思考被打断，请重试。"
                    : error.localizedDescription
                showError = true
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — RecentQARow
// ══════════════════════════════════════════════════════════════════════

private struct RecentQARow: View {

    let record: QARecord

    var body: some View {
        HStack(spacing: 10) {
            // Category badge or fallback icon
            if let cat = record.category, !cat.isEmpty {
                Text(cat)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.10), in: Capsule())
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Image(systemName: "questionmark.bubble")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 28)
            }

            Text(record.question)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — QAResultSheet
// ══════════════════════════════════════════════════════════════════════

struct QAResultSheet: View {

    let record: QARecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Category badge
                    if let cat = record.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.10), in: Capsule())
                    }

                    // Question
                    Text(record.question)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    Divider()

                    // Answer
                    MarkdownText(source: record.answer, baseFont: .body, baseColor: .primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("AI 回答")
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
    MaLeMeView()
}
