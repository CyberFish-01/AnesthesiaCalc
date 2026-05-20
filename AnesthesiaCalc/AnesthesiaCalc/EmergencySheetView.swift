import SwiftUI
import AnesthesiaCalcCore

// MARK: - EmergencySheetView

struct EmergencySheetView: View {

    @ObservedObject private var ctx = ClinicalContext.shared
    @State private var searchText = ""
    @State private var expandedProtocol: String? = nil

    private var protocols: [EmergencyProtocol] {
        guard let p = ctx.patient else { return [] }
        return EmergencyProtocolEngine.generateAll(for: p.actualWeight)
    }

    private var filtered: [EmergencyProtocol] {
        if searchText.isEmpty { return protocols }
        return protocols.filter { p in
            p.name.localizedCaseInsensitiveContains(searchText)
            || p.recognition.joined().localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if protocols.isEmpty {
                    Text("请先在「计算」页输入患者体重")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { proto in
                        Section {
                            protocolContent(proto)
                        } header: {
                            Button {
                                withAnimation { expandedProtocol = (expandedProtocol == proto.id) ? nil : proto.id }
                            } label: {
                                HStack {
                                    Text(proto.name).font(.headline)
                                    Spacer()
                                    Image(systemName: expandedProtocol == proto.id ? "chevron.up" : "chevron.down")
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索预案 (支持拼音)")
            .navigationTitle("紧急预案")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func protocolContent(_ proto: EmergencyProtocol) -> some View {
        if expandedProtocol == proto.id {
            // 识别
            VStack(alignment: .leading, spacing: 4) {
                Label("早期识别", systemImage: "eye.trianglebadge.exclamationmark")
                    .font(.caption.weight(.semibold)).foregroundStyle(.red)
                ForEach(proto.recognition, id: \.self) { r in
                    Text("• \(r)").font(.caption)
                }
            }.padding(.vertical, 4)

            // 立即措施
            VStack(alignment: .leading, spacing: 4) {
                Label("立即措施", systemImage: "exclamationmark.shield.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                ForEach(proto.immediateActions, id: \.self) { a in
                    Text("• \(a)").font(.caption)
                }
            }.padding(.vertical, 4)

            // 用药
            VStack(alignment: .leading, spacing: 6) {
                Label("用药步骤", systemImage: "cross.case.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.green)
                ForEach(Array(proto.drugSteps.enumerated()), id: \.offset) { _, step in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(step.drugName).font(.caption.weight(.semibold))
                            Text(step.route).font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(step.calculatedDose)
                                .font(.caption.monospacedDigit().weight(.medium))
                                .foregroundStyle(.green)
                        }
                        Text(step.rawInstruction).font(.caption2).foregroundStyle(.secondary)
                        if let note = step.note, !note.isEmpty {
                            Text(note).font(.caption2).foregroundStyle(.tertiary).italic()
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }.padding(.vertical, 4)

            // 升级
            VStack(alignment: .leading, spacing: 4) {
                Label("升级措施", systemImage: "arrow.up.forward.circle")
                    .font(.caption.weight(.semibold)).foregroundStyle(.purple)
                ForEach(proto.escalation, id: \.self) { e in
                    Text("• \(e)").font(.caption)
                }
            }.padding(.vertical, 4)
        }
    }
}
