import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
                selectedChat = viewModel.createNewChat()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Chat.self, inMemory: true)
}
