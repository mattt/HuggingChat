import SwiftUI
import SwiftData

enum ChatSelection: Hashable {
    case newChat
    case existing(Chat)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationManager.self) private var authManager
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @State private var selectedItem: ChatSelection? = .newChat
    @State private var viewModel: ChatViewModel?

    var body: some View {
        NavigationSplitView {
            if let viewModel {
                ChatListView(selectedItem: $selectedItem, viewModel: viewModel)
            }
        } detail: {
            if let viewModel {
                if case let .existing(chat) = selectedItem {
                    ChatDetailView(chat: chat, viewModel: viewModel)
                } else {
                    NewChatDetailView(viewModel: viewModel, selectedItem: $selectedItem)
                }
            } else {
                EmptyView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(modelContext: modelContext, authManager: authManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChat)) { _ in
            selectedItem = .newChat
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Chat.self, inMemory: true)
}
