import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationManager.self) private var authManager
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @State private var selectedChat: Chat?
    @State private var viewModel: ChatViewModel?

    var body: some View {
        NavigationSplitView {
            if let viewModel {
                ChatListView(selectedChat: $selectedChat, viewModel: viewModel)
            }
        } detail: {
            if let selectedChat, let viewModel {
                ChatDetailView(chat: selectedChat, viewModel: viewModel)
            } else {
                EmptyStateView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(modelContext: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChat)) { _ in
            if let viewModel {
                if let emptyChat = chats.first(where: { $0.messages.isEmpty }) {
                    selectedChat = emptyChat
                } else {
                    selectedChat = viewModel.createNewChat()
                }
            }
        }
        .sheet(isPresented: .constant(!authManager.isAuthenticated)) {
            SignInSheet()
                .interactiveDismissDisabled()
        }
    }
}

struct SignInSheet: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "face.smiling")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Welcome to HuggingChat")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Sign in with your Hugging Face account to get started")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 16) {
                Button {
                    isSigningIn = true
                    Task {
                        await authManager.signIn()
                        isSigningIn = false
                    }
                } label: {
                    HStack {
                        if isSigningIn {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Text("Sign in with Hugging Face")
                        }
                    }
                    .frame(maxWidth: 300)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSigningIn)

                if let error = authManager.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .frame(maxWidth: 300)
                }
            }
            .padding(.bottom, 40)
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Chat.self, inMemory: true)
}
