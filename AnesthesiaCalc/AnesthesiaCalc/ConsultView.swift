import SwiftUI
import AnesthesiaCalcCore

// MARK: - ChatMessage

private struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let text: String
    let response: KnowledgeResponse?
    let isDisclaimer: Bool
    let showMillerButton: Bool

    enum Role: Equatable { case user, assistant }

    init(role: Role, text: String, response: KnowledgeResponse? = nil, isDisclaimer: Bool = false, showMillerButton: Bool = false) {
        self.role = role
        self.text = text
        self.response = response
        self.isDisclaimer = isDisclaimer
        self.showMillerButton = showMillerButton
    }
}

// MARK: - ConsultView

struct ConsultView: View {

    let initialQuestion: String?
    var millerQuestion: String? = nil

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isSearching = false
    @FocusState private var isInputFocused: Bool

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var context = ClinicalContext.shared
    private let provider = KnowledgeProvider.shared

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatScrollView
                inputBar
            }
            .navigationTitle("指南咨询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isInputFocused = false }
                }
            }
            .onAppear {
                if messages.isEmpty {
                    showContextCard()
                    if let q = initialQuestion, !q.isEmpty {
                        sendMessage(q)
                    }
                }
            }
        }
    }

    // MARK: Chat scroll

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        messageView(msg)
                    }
                    if isSearching {
                        searchingIndicator
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: Message view (bubble + citations)

    @ViewBuilder
    private func messageView(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == .user

        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .top) {
                if isUser { Spacer(minLength: 60) }
                VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                    // Main text bubble
                    Text(msg.text)
                        .font(.callout)
                        .foregroundColor(isUser ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isUser
                            ? Color.accentColor
                            : Color(UIColor.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14))
                        .textSelection(.enabled)

                    // Guideline citation
                    if let resp = msg.response, let conclusion = resp.conclusion {
                        guidelineCitationCard(conclusion)
                    }

                    // Miller citation
                    if let resp = msg.response, let analysis = resp.deepAnalysis {
                        millerCitationCard(analysis)
                    }

                    // Miller exploration button (optional)
                    if msg.showMillerButton {
                        millerExplorationButton
                    }

                    // Conflict banner
                    if let resp = msg.response, resp.hasConflict {
                        conflictBanner
                    }

                    // Disclaimer
                    if msg.isDisclaimer {
                        disclaimerFooter
                    }
                }
                if !isUser { Spacer(minLength: 60) }
            }
        }
    }

    // MARK: Guideline citation card

    private func guidelineCitationCard(_ entry: KnowledgeEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 9))
                Text("指南依据")
                    .font(.system(size: 9, weight: .bold))
                Spacer()
                Text("\(String(entry.year))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.accentColor, in: Capsule())
            }
            .foregroundColor(.accentColor)

            Text(entry.citation)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(2)

            Text(entry.institution)
                .font(.system(size: 8))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: Miller citation card

    private func millerCitationCard(_ entry: KnowledgeEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 9))
                Text("深度解析")
                    .font(.system(size: 9, weight: .bold))
                Spacer()
                Text("米勒")
                    .font(.system(size: 9).italic())
                    .foregroundColor(.brown)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.brown.opacity(0.12), in: Capsule())
            }
            .foregroundColor(.brown)

            Text(entry.citation)
                .font(.system(size: 9).italic())
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brown.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.brown.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: Miller exploration button

    private var millerExplorationButton: some View {
        Button {
            sendMessage("请从药理学机制角度深度解析上述建议的原理和背景")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 9))
                Text("查看米勒原理解析")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.brown)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brown.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: Conflict banner

    private var conflictBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 9))
            Text("注意：以上来源的结论存在差异，已并列展示。以上方最新指南建议为准。")
                .font(.system(size: 9))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: Disclaimer

    private var disclaimerFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 9))
            Text("本建议仅供临床参考，最终决策由值班医师负责。")
                .font(.system(size: 9))
        }
        .foregroundColor(.secondary.opacity(0.7))
    }

    // MARK: Searching indicator

    private var searchingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("正在检索知识库...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.trailing, 60)
    }

    // MARK: Input bar

    private var inputBar: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(spacing: 8) {
                TextField("输入麻醉学问题...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                    .focused($isInputFocused)
                    .lineLimit(1...4)

                Button(action: { sendMessage(inputText) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(canSend ? .accentColor : .gray.opacity(0.4))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemBackground))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSearching
    }

    // MARK: Context card

    private func showContextCard() {
        if !context.isEmpty {
            let summary = "当前患者：\(context.contextSummary)"
            messages.append(ChatMessage(role: .assistant, text: summary, response: nil, isDisclaimer: false))
        }
    }

    // MARK: Send

    private func sendMessage(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: text))
        inputText = ""
        isSearching = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isSearching = false

            let response = provider.query(text)

            if response.conclusion != nil || response.deepAnalysis != nil {
                // Build smart summary text
                var body = ""
                if let c = response.conclusion {
                    body += "**结论摘要（基于指南）**\n" + c.content
                }
                if let d = response.deepAnalysis {
                    if !body.isEmpty { body += "\n\n" }
                    body += "**深度解析（基于米勒麻醉学）**\n" + d.content
                }
                messages.append(ChatMessage(role: .assistant, text: body, response: response))

                // Show Miller exploration button only if we have guideline but no miller match
                if response.conclusion != nil && response.deepAnalysis == nil {
                    // Add a message with the button
                }
            } else {
                messages.append(ChatMessage(
                    role: .assistant,
                    text: provider.fallbackResponse,
                    response: KnowledgeResponse(
                        conclusion: KnowledgeEntry(
                            keywords: [], title: "", content: "",
                            source: .guideline,
                            citation: provider.fallbackSource,
                            year: 2026,
                            institution: ""
                        ),
                        deepAnalysis: nil,
                        hasConflict: false
                    )
                ))
            }

            // Show Miller button when only guideline matched
            if response.conclusion != nil && response.deepAnalysis == nil {
                messages.append(ChatMessage(
                    role: .assistant,
                    text: "",
                    showMillerButton: true
                ))
            }

            // Disclaimer
            messages.append(ChatMessage(
                role: .assistant,
                text: "本建议仅供临床参考，最终决策由值班医师负责。",
                isDisclaimer: true
            ))
        }
    }
}

// MARK: Preview

#Preview {
    ConsultView(initialQuestion: "为什么肥胖患者顺式阿曲库铵建议按 IBW 计算？")
}
