//
//  CaseHistoryView.swift
//  AnesthesiaCalc
//

import SwiftUI

// ══════════════════════════════════════════════════════════════════════
// MARK: — CaseHistoryView
// ══════════════════════════════════════════════════════════════════════

struct CaseHistoryView: View {

    @StateObject private var history = HistoryManager.shared

    @State private var searchText: String = ""
    @State private var selectedDate: Date? = nil
    @State private var showDatePicker: Bool = false

    // ── Filtered data source ──────────────────────────────────────────

    var filteredRecords: [CaseRecord] {
        var result = history.records

        if let filterDate = selectedDate {
            result = result.filter {
                Calendar.current.isDate($0.date, inSameDayAs: filterDate)
            }
        }

        if !searchText.isEmpty {
            result = result.filter { record in
                record.patientName.localizedCaseInsensitiveContains(searchText) ||
                record.hospitalNumber.localizedCaseInsensitiveContains(searchText) ||
                record.surgery.localizedCaseInsensitiveContains(searchText) ||
                record.conditions.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        return result.sorted { $0.date > $1.date }
    }

    // ── Body ──────────────────────────────────────────────────────────

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Group {
                if history.records.isEmpty {
                    emptyState
                } else if filteredRecords.isEmpty {
                    noResultsState
                } else {
                    recordList
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("历史病例")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    if selectedDate != nil {
                        Button(action: { selectedDate = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                    Button(action: { showDatePicker = true }) {
                        Image(systemName: selectedDate == nil ? "calendar" : "calendar.badge.clock")
                            .foregroundStyle(selectedDate == nil ? Color.primary : Color.accentColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker(
                    "选择日期",
                    selection: Binding(
                        get: { selectedDate ?? Date() },
                        set: { selectedDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("选择筛选日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") { showDatePicker = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // ── Search bar ────────────────────────────────────────────────────

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)
            TextField("搜索姓名 / 住院号 / 手术...", text: $searchText)
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

    // ── Empty state (no records at all) ───────────────────────────────

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 52, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("暂无历史病例")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("使用「AI 决策」页面生成麻醉计划后，\n记录将自动保存到这里。")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // ── No results state (records exist, filter matches nothing) ──────

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
            Text("请尝试修改搜索关键词或清除日期筛选")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // ── Record list ───────────────────────────────────────────────────

    private var recordList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredRecords) { record in
                    CaseRecordCard(record: record)
                        .contextMenu {
                            Button(role: .destructive) {
                                if let i = history.records.firstIndex(where: { $0.id == record.id }) {
                                    history.delete(at: IndexSet(integer: i))
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
// MARK: — CaseRecordCard
// ══════════════════════════════════════════════════════════════════════

/// Shared card component — used in both CaseHistoryView and DecisionResultSheet.
/// Pass `initiallyExpanded: true` when the plan should be visible immediately
/// (e.g. the result sheet right after generation).
struct CaseRecordCard: View {

    let record: CaseRecord
    @State private var isExpanded: Bool

    init(record: CaseRecord, initiallyExpanded: Bool = false) {
        self.record = record
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header: always visible, tap to expand / collapse ──────
            VStack(alignment: .leading, spacing: 6) {

                // Row 1: patient info + date + chevron
                HStack {
                    let idText = record.hospitalNumber.isEmpty ? "" : " | \(record.hospitalNumber)"

                    Text("患者：\(record.patientName) | \(record.age)\(idText)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .layoutPriority(1)

                    Spacer()

                    HStack(spacing: 6) {
                        Text(record.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }

                // Row 2: surgery name
                Text(record.surgery.isEmpty ? "未知手术" : record.surgery)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                // Row 3: condition tags (always visible)
                if !record.conditions.isEmpty {
                    conditionTags
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            // ── Detail: anesthesia plan, shown when expanded ──────────
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)

                Text(record.anesthesiaPlan.isEmpty ? "暂无计划" : record.anesthesiaPlan)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // ── Condition tags ────────────────────────────────────────────────

    private var conditionTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(record.conditions, id: \.self) { condition in
                    Text(condition)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.10), in: Capsule())
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — Preview
// ══════════════════════════════════════════════════════════════════════

#Preview {
    NavigationStack {
        CaseHistoryView()
    }
}

#Preview("Card Sample — Collapsed") {
    CaseRecordCard(record: CaseRecord(
        patientName:    "张三",
        hospitalNumber: "12345678",
        age:            "65岁",
        surgery:        "腹腔镜胆囊切除术",
        conditions:     ["高血压", "糖尿病", "困难气道"],
        anesthesiaPlan: "建议采用全身麻醉，气管内插管维持气道。\n诱导：丙泊酚 1.5 mg/kg + 芬太尼 1 mcg/kg + 罗库溴铵 0.6 mg/kg IBW。\n维持：丙泊酚 TCI + 瑞芬太尼 0.1–0.3 mcg/kg/min。\n注意：术前需对困难气道做好备案，准备视频喉镜。\n术后镇痛：帕瑞昔布 40 mg iv q12h 联合曲马多按需给药。"
    ))
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Card Sample — Expanded") {
    CaseRecordCard(
        record: CaseRecord(
            patientName:    "张三",
            hospitalNumber: "12345678",
            age:            "65岁",
            surgery:        "腹腔镜胆囊切除术",
            conditions:     ["高血压", "糖尿病", "困难气道"],
            anesthesiaPlan: "建议采用全身麻醉，气管内插管维持气道。\n诱导：丙泊酚 1.5 mg/kg + 芬太尼 1 mcg/kg + 罗库溴铵 0.6 mg/kg IBW。\n维持：丙泊酚 TCI + 瑞芬太尼 0.1–0.3 mcg/kg/min。\n注意：术前需对困难气道做好备案，准备视频喉镜。\n术后镇痛：帕瑞昔布 40 mg iv q12h 联合曲马多按需给药。"
        ),
        initiallyExpanded: true
    )
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
