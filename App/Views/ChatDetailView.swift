import SwiftData
import SwiftUI

fileprivate let bottomSentinelID = "bottom-sentinel"

struct ChatDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let chat: Chat
    let viewModel: ChatViewModel

    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?

    private let initialScrollTarget: UUID?

    private var scrollPositionKey: String {
        "scrollPosition_\(chat.id)"
    }

    init(chat: Chat, viewModel: ChatViewModel) {
        self.chat = chat
        self.viewModel = viewModel

        // Calculate initial scroll target
        let key = "scrollPosition_\(chat.id)"
        if let savedPositionString = UserDefaults.standard.string(forKey: key),
            let savedPositionId = UUID(uuidString: savedPositionString),
            chat.messages.contains(where: { $0.id == savedPositionId })
        {
            self.initialScrollTarget = savedPositionId
        } else {
            self.initialScrollTarget = chat.messages.last?.id
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ConversationView(
                    messages: chat.messages,
                    isGenerating: viewModel.isGenerating,
                    onMessageAppear: { id in
                        // Save the last visible message
                        saveScrollPosition(messageId: id)
                    }
                )
                .onChange(of: chat.id, initial: true) { _, _ in
                    scrollProxy = proxy
                    // Scroll immediately when chat changes
                    if let target = initialScrollTarget {
                        proxy.scrollTo(target, anchor: .bottom)
                    } else {
                        proxy.scrollTo(bottomSentinelID, anchor: .bottom)
                    }
                }
                .onChange(of: chat.messages.count) { oldCount, newCount in
                    // When new messages are added, scroll to reveal them with animation
                    if newCount > oldCount {
                        scrollToBottomAnimated()
                    }
                }
                .onChange(of: chat.messages.last?.content) {
                    print("ON CHANGE LAST MESSAGE")
                    scrollToBottomAnimated()
                }
                .onChange(of: viewModel.isGenerating) { wasGenerating, isGenerating in
                    // When generation starts, scroll to show the typing indicator
                    if isGenerating && !wasGenerating {
                        scrollToTypingIndicatorAnimated()
                    }
                }
            }

            Divider()

            MessageComposerView(
                text: $inputText,
                isGenerating: viewModel.isGenerating,
                model: .constant(chat.model),
                chat: chat,
                modelContext: modelContext,
                viewModel: viewModel
            ) {
                sendMessage()
            }
        }
        .navigationTitle(chat.title ?? "New Chat")
    }

    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        inputText = ""

        Task {
            await viewModel.sendMessage(to: chat, content: message)
        }
    }

    private func scrollToBottomAnimated() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(bottomSentinelID, anchor: .bottom)
            }
        }
    }

    private func scrollToTypingIndicatorAnimated() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(bottomSentinelID, anchor: .bottom)
            }
        }
    }

    private func saveScrollPosition(messageId: UUID) {
        UserDefaults.standard.set(messageId.uuidString, forKey: scrollPositionKey)
    }
}

private struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer()
            }

            Text(message.content)
                .textSelection(.enabled)
                .padding(12)
                .background(
                    message.isUser
                        ? Color.accentColor.opacity(0.1)
                        : Color.primary.opacity(0.05)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minWidth: 100)

            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct TypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "ellipsis")
                .symbolEffect(.variableColor)
                .font(.title)
                .foregroundStyle(.secondary)
                .padding()

            Spacer()
        }
    }
}

struct PresentedMessage: Identifiable, Hashable {
    let id: UUID
    let content: String
    let isUser: Bool
}

struct ConversationView: View {
    let messages: [Message]
    let isGenerating: Bool
    var onMessageAppear: (UUID) -> Void = { _ in }

    var body: some View {
        List {
            ForEach(messages, id: \.id) { message in
                MessageBubbleView(message: message)
                    .onAppear { onMessageAppear(message.id) }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if isGenerating {
                TypingIndicatorView()
                    .id("typing-indicator")
                    .listRowSeparator(.hidden)
                //                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Persistent bottom sentinel to ensure reliable scrolling to end
            Color.clear
                .frame(height: 1)
                .id(bottomSentinelID)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

#if DEBUG
    #Preview {
        let messages: [Message] = [
            .init(content: "Hello!", isUser: true),
            .init(content: "Hi there — how can I help you today?", isUser: false),
            .init(content: "Tell me a quick joke.", isUser: true),
        ]

        ConversationView(messages: messages, isGenerating: true)
            .frame(width: 800, height: 500)
    }
#endif
