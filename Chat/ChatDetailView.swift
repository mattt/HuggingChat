import SwiftData
import SwiftUI

struct ChatDetailView: View {
    let chat: Chat
    let viewModel: ChatViewModel

    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chat.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }

                        if viewModel.isGenerating {
                            TypingIndicatorView()
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom()
                }
                .onChange(of: chat.messages.count) { _, _ in
                    scrollToBottom()
                }
            }

            Divider()

            InputBarView(
                text: $inputText,
                isGenerating: viewModel.isGenerating,
                selectedModel: chat.model
            ) {
                sendMessage()
            }
        }
        .navigationTitle(chat.title)
        .navigationSubtitle(chat.model.displayName)
    }

    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        inputText = ""

        Task {
            await viewModel.sendMessage(to: chat, content: message)
        }
    }

    private func scrollToBottom() {
        guard let lastMessage = chat.messages.last else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                Image(systemName: "brain")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            } else {
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

            if message.isUser {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            } else {
                Spacer()
            }
        }
    }
}

struct InputBarView: View {
    @Binding var text: String
    let isGenerating: Bool
    let selectedModel: Model
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Send a message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(1 ... 10)
                .onSubmit(onSend)
                .disabled(isGenerating)

            HStack(spacing: 8) {
                Menu {
                    Text(selectedModel.displayName)
                } label: {
                    Text(selectedModel.shortName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(
                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating
                )
            }
        }
        .padding()
    }
}

struct TypingIndicatorView: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            HStack(spacing: 4) {
                ForEach(0 ..< 3) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .opacity(dotCount == index ? 1.0 : 0.3)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear {
                startAnimation()
            }

            Spacer()
        }
    }

    private func startAnimation() {
        Task {
            while true {
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run {
                    dotCount = (dotCount + 1) % 3
                }
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Select a chat or create a new one")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Model {
    var displayName: String {
        switch self {
        case .system:
            return "Apple Intelligence"
        case .mlx(let modelId):
            return modelId
        case .ollama(let model):
            return "Ollama: \(model)"
        case .openAI(let model):
            return "OpenAI: \(model)"
        case .anthropic(let model):
            return "Anthropic: \(model)"
        }
    }

    var shortName: String {
        switch self {
        case .system:
            return "System"
        case .mlx:
            return "MLX"
        case .ollama(let model):
            return model
        case .openAI(let model):
            return model
        case .anthropic(let model):
            return model
        }
    }
}
