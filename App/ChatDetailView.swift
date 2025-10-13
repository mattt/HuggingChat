import SwiftData
import SwiftUI

struct NewChatDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let viewModel: ChatViewModel
    @Binding var selectedItem: ChatSelection?

    @State private var inputText = ""
    @State private var selectedModel: Model = .system

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("HuggingChat")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            Spacer()

            Divider()

            InputBarView(
                text: $inputText,
                isGenerating: false,
                model: $selectedModel,
                modelContext: modelContext
            ) {
                sendMessage()
            }
        }
        .navigationTitle("New Chat")
    }

    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        inputText = ""

        // Create a new chat with the selected model
        let chat = viewModel.createNewChat(model: selectedModel)

        // Switch to the new chat
        selectedItem = .existing(chat)

        // Send the message
        Task {
            await viewModel.sendMessage(to: chat, content: message)
        }
    }
}

struct ChatDetailView: View {
    @Environment(\.modelContext) private var modelContext
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

    private func scrollToBottom() {
        guard let lastMessage = chat.messages.last else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
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

private struct InputBarView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Binding var text: String
    let isGenerating: Bool
    @Binding var model: Model
    var chat: Chat?
    let modelContext: ModelContext
    var viewModel: ChatViewModel?
    let onSend: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            TextField("Send a message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(1 ... 10)
                .frame(minWidth: 300)
                .disabled(isGenerating)
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
                .onKeyPress { press in
                    if press.key == .return {
                        if press.modifiers.isEmpty {
                            if !isGenerating && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSend()
                                return .handled
                            }
                        } else if press.modifiers == [.shift] {
                            _text.wrappedValue.append("\n")
                            return .handled
                        }
                    }
                    return .ignored
                }
                .glassEffectTransition(.materialize)

            HStack(spacing: 8) {
                Spacer()

                Menu {
                    Button {
                        if let chat {
                            chat.updateModel(.system)
                            try? modelContext.save()
                        } else {
                            model = .system
                        }
                    } label: {
                        Image(systemName: "apple.logo")
                        Text("Apple Intelligence")
                        Text("System Foundation Model")
                        if model == .system {
                            Image(systemName: "checkmark")
                        }
                    }

                    if authManager.isAuthenticated {
                        Divider()
                        
                        Text("HuggingFace Inference")
                        
                        ForEach(huggingFaceModels, id: \.id) { model in
                            Button {
                                if let chat {
                                    chat.updateModel(.huggingFace(model.id))
                                    try? modelContext.save()
                                } else {
                                    self.model = .huggingFace(model.id)
                                }
                            } label: {
                                Image(systemName: "bolt.fill")
                                Text(model.name)
                                Text(model.id)
                                let isSelected =
                                    if case .huggingFace(let selectedId) = self.model {
                                        selectedId == model.id
                                    } else {
                                        false
                                    }
                                if isSelected {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(model.shortName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    if isGenerating, let viewModel {
                        viewModel.stopGenerating()
                    } else {
                        onSend()
                    }
                } label: {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(
                    !isGenerating && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding()
    }

    private var huggingFaceModels: [(id: String, name: String)] {
        [
            (id: "meta-llama/Llama-3.3-70B-Instruct", name: "Llama 3.3 70B"),
            (id: "meta-llama/Llama-3.1-8B-Instruct", name: "Llama 3.1 8B"),
            (id: "Qwen/Qwen2.5-72B-Instruct", name: "Qwen 2.5 72B"),
            (id: "mistralai/Mistral-7B-Instruct-v0.3", name: "Mistral 7B"),
            (id: "google/gemma-2-9b-it", name: "Gemma 2 9B"),
        ]
    }
}

private struct TypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "ellipsis")
                .symbolEffect(.variableColor.iterative.reversing, options: .repeat(.continuous))
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minWidth: 100)

            Spacer()
        }
    }
}


private extension Model {
    var displayName: String {
        switch self {
        case .system:
            return "Apple Intelligence"
        case .mlx(let modelId):
            return modelId
        case .huggingFace(let model):
            return "HuggingFace: \(model)"
        }
    }

    var shortName: String {
        switch self {
        case .system:
            return "Apple Intelligence"
        case .mlx:
            return "MLX"
        case .huggingFace(let model):
            // Extract the model name after the last slash for brevity
            return model.split(separator: "/").last.map(String.init) ?? model
        }
    }
}
