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
        .navigationTitle(chat.title ?? "New Chat")
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

private struct MessageBubbleView: View {
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

private struct InputBarView: View {
    @Binding var text: String
    let isGenerating: Bool
    let selectedModel: Model
    let onSend: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Send a message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(1 ... 10)
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

private struct TypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            Image(systemName: "ellipsis")
                .symbolEffect(.variableColor.iterative.reversing, options: .repeat(.continuous))
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

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
