//
//  QAHistoryView.swift
//  AnesthesiaCalc
//

import SwiftUI

// ══════════════════════════════════════════════════════════════════════
// MARK: — QAHistoryView
// ══════════════════════════════════════════════════════════════════════

struct QAHistoryView: View {

    @StateObject private var qaHistory = QAHistoryManager.shared
    @State private var searchText: String = ""

    // ── Filtered records ──────────────────────────────────────────────

    private var filteredRecords: [QARecord] {
        guard !searchText.isEmpty else { return qaHistory.records }
        return qaHistory.records.filter { record in
            record.question.localizedCaseInsensitiveContains(searchText) ||
            record.answer.localizedCaseInsensitiveContains(searchText) ||
            (record.category ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    // ── Body ──────────────────────────────────────────────────────────

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Group {
                if qaHistory.records.isEmpty {
                    emptyState
                } else if filteredRecords.isEmpty {
                    noResultsState
                } else {
                    recordList
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("对话记录")
        .navigationBarTitleDisplayMode(.large)
    }

    // ── Search bar ────────────────────────────────────────────────────

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)
            TextField("搜索问题或分类...", text: $searchText)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // ── Empty state ───────────────────────────────────────────────────

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 52, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("暂无对话记录")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("在「麻了么」页面提问后，\n记录将自动保存到这里。")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // ── No results state ──────────────────────────────────────────────

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("未找到匹配记录")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("请尝试修改搜索关键词")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // ── Record list ───────────────────────────────────────────────────

    private var recordList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredRecords) { record in
                    QARecordCard(record: record)
                        .contextMenu {
                            Button(role: .destructive) {
                                if let i = qaHistory.records.firstIndex(where: { $0.id == record.id }) {
                                    qaHistory.delete(atOffsets: IndexSet(integer: i))
                                }
                            } label: {
                                Label("删除记录", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — QARecordCard
// ══════════════════════════════════════════════════════════════════════

struct QARecordCard: View {

    let record: QARecord
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header: always visible, tap to expand/collapse ────────
            VStack(alignment: .leading, spacing: 6) {

                // Date + category badge + chevron
                HStack(spacing: 6) {
                    Text(record.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let cat = record.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.10), in: Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                // Question — bold, up to 3 lines
                Text(record.question)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            // ── Answer: shown when expanded ───────────────────────────
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)

                Text(record.answer)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — Preview
// ══════════════════════════════════════════════════════════════════════

#Preview {
    NavigationStack {
        QAHistoryView()
    }
}

#Preview("Card Sample") {
    QARecordCard(record: QARecord(
        question: "七氟烷诱导时小儿的MAC值是多少？",
        answer:   "小儿七氟烷的MAC值随年龄而变化。新生儿约为3.3%，6个月时达峰约3.2%，随后随年龄增长而下降。1-3岁约为2.5%，5-12岁约为2.2%。\n\n使用时需注意：小儿对吸入麻醉药的摄取较成人快，诱导通常采用8%浓度快速诱导，维持期根据BIS/AAI等监测指标调整至1-1.5 MAC。",
        category: "剂量计算"
    ))
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
