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

            MessageComposerView(
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
