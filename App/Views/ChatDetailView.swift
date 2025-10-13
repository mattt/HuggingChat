import SwiftData
import SwiftUI

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
                List {
                    ForEach(chat.messages, id: \.id) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .onAppear {
                                // Save the last visible message
                                saveScrollPosition(messageId: message.id)
                            }
                    }

                    if viewModel.isGenerating {
                        TypingIndicatorView()
                            .id("typing-indicator")
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .onChange(of: chat.id, initial: true) { _, _ in
                    scrollProxy = proxy
                    // Scroll immediately when chat changes
                    if let target = initialScrollTarget {
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
                .onChange(of: chat.messages.count) { oldCount, newCount in
                    // When new messages are added, scroll to reveal them with animation
                    if newCount > oldCount {
                        scrollToBottomAnimated()
                    }
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
        guard let lastMessage = chat.messages.last else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func scrollToTypingIndicatorAnimated() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo("typing-indicator", anchor: .bottom)
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
                .symbolEffect(.variableColor.iterative.reversing, options: .repeat(.continuous))
                .font(.title)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minWidth: 100)

            Spacer()
        }
    }
}
