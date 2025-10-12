import SwiftData
import SwiftUI

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
    let chat: Chat
    let modelContext: ModelContext
    let viewModel: ChatViewModel
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
                Menu {
                    Button {
                        chat.updateModel(.system)
                        try? modelContext.save()
                    } label: {
                        if chat.model == .system {
                            Label("Apple Intelligence", systemImage: "checkmark")
                        } else {
                            Text("Apple Intelligence")
                        }
                    }

                    if authManager.isAuthenticated {
                        Divider()

                        ForEach(huggingFaceModels, id: \.0) { modelId, displayName in
                            Button {
                                chat.updateModel(.huggingFace(modelId))
                                try? modelContext.save()
                            } label: {
                                let isSelected =
                                    if case .huggingFace(let selectedId) = chat.model {
                                        selectedId == modelId
                                    } else {
                                        false
                                    }
                                if isSelected {
                                    Label(displayName, systemImage: "checkmark")
                                } else {
                                    Text(displayName)
                                }
                            }
                        }
                    }
                } label: {
                    Text(chat.model.shortName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Button {
                    if isGenerating {
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

    private var huggingFaceModels: [(String, String)] {
        [
            ("meta-llama/Llama-3.3-70B-Instruct", "Llama 3.3 70B"),
            ("meta-llama/Llama-3.1-8B-Instruct", "Llama 3.1 8B"),
            ("Qwen/Qwen2.5-72B-Instruct", "Qwen 2.5 72B"),
            ("mistralai/Mistral-7B-Instruct-v0.3", "Mistral 7B"),
            ("google/gemma-2-9b-it", "Gemma 2 9B"),
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

struct EmptyStateView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 24) {
            if authManager.isAuthenticated {
                // Authenticated state
                VStack(spacing: 16) {
                    if let user = authManager.currentUser {
                        if let pictureURL = user.picture,
                            let url = URL(string: pictureURL)
                        {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        }

                        Text(user.preferredUsername ?? user.name ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let email = user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Sign Out") {
                        Task {
                            await authManager.signOut()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Unauthenticated state
                VStack(spacing: 20) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)

                    Text("Sign in with Hugging Face")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Button {
                        isSigningIn = true
                        Task {
                            await authManager.signIn()
                            isSigningIn = false
                        }
                    } label: {
                        if isSigningIn {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSigningIn)
                    .controlSize(.large)

                    if let error = authManager.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            return "System"
        case .mlx:
            return "MLX"
        case .huggingFace(let model):
            // Extract the model name after the last slash for brevity
            return model.split(separator: "/").last.map(String.init) ?? model
        }
    }
}
