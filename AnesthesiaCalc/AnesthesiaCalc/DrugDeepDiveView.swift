import SwiftUI
import AnesthesiaCalcCore

// MARK: - DrugDeepDiveView

struct DrugDeepDiveView: View {

    let drug: AnesthesiaDrug

    @Environment(\.dismiss) private var dismiss

    private var data: DrugDeepDiveData? { DrugDeepDiveStore.data(for: drug) }
    private var displayName: String {
        let name = drug.name
        if let r = name.range(of: " (") { return String(name[..<r.lowerBound]) }
        if let r = name.range(of: "（") { return String(name[..<r.lowerBound]) }
        return name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let d = data {
                        categoryTag(d.category)
                        pkpdSection(d)
                        Divider()
                        redLineSection(d)
                    } else {
                        unavailableView
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(displayName)
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - Category tag

    private func categoryTag(_ category: String) -> some View {
        Text(category)
            .font(.caption.weight(.medium))
            .foregroundColor(.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.08), in: Capsule())
    }

    // MARK: - Section 1: 药理机制 (PK/PD)

    private func pkpdSection(_ d: DrugDeepDiveData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                icon: "text.book.closed.fill",
                title: "药理机制 (PK/PD)",
                source: "米勒麻醉学 第九版",
                color: .brown
            )

            VStack(alignment: .leading, spacing: 6) {
                ForEach(d.pkpd, id: \.self) { point in
                    bulletRow(point, color: .brown)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Section 2: 临床指南红线

    private func redLineSection(_ d: DrugDeepDiveData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                icon: "exclamationmark.shield.fill",
                title: "临床指南红线",
                source: "最新麻醉学指南",
                color: .red
            )

            VStack(alignment: .leading, spacing: 6) {
                ForEach(d.redLines, id: \.self) { point in
                    bulletRow(point, color: .red)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Unavailable fallback

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.page.badge.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.5))
            Text("\(displayName) 的纵深数据暂未收录")
                .font(.callout)
                .foregroundColor(.secondary)
            Text("数据将持续更新，敬请关注")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Shared components

    private func sectionHeader(icon: String, title: String, source: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
            Spacer()
            Text(source)
                .font(.caption2)
                .foregroundColor(color.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.1), in: Capsule())
        }
    }

    private func bulletRow(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(.callout)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
