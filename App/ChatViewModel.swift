import Foundation
import SwiftData
import Observation
import AnyLanguageModel

@Observable
@MainActor
final class ChatViewModel {
    private(set) var isGenerating = false
    private(set) var errorMessage: String?

    private let modelContext: ModelContext
    private var session: LanguageModelSession?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func sendMessage(to chat: Chat, content: String) async {
        guard !content.isEmpty else { return }

        let userMessage = Message(content: content, isUser: true)
        userMessage.chat = chat
        chat.messages.append(userMessage)
        chat.updatedAt = Date()

        if chat.title == "New Chat" {
            chat.title = String(content.prefix(50))
        }

        modelContext.insert(userMessage)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save message: \(error.localizedDescription)"
            return
        }

        await generateResponse(for: chat)
    }

    private func generateResponse(for chat: Chat) async {
        isGenerating = true
        errorMessage = nil

        do {
            let languageModel = chat.model.makeLanguageModel()
            let session = LanguageModelSession(model: languageModel)
            self.session = session

            let prompt = chat.messages
                .map { message in
                    "\(message.isUser ? "User" : "Assistant"): \(message.content)"
                }
                .joined(separator: "\n\n")

            let response = try await session.respond(to: prompt)

            let assistantMessage = Message(content: response.content, isUser: false)
            assistantMessage.chat = chat
            chat.messages.append(assistantMessage)
            chat.updatedAt = Date()

            modelContext.insert(assistantMessage)
            try modelContext.save()
        } catch {
            errorMessage = "Failed to generate response: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    func createNewChat(model: Model = .system) -> Chat {
        let chat = Chat(model: model)
        modelContext.insert(chat)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to create chat: \(error.localizedDescription)"
        }

        return chat
    }

    func deleteChat(_ chat: Chat) {
        modelContext.delete(chat)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete chat: \(error.localizedDescription)"
        }
    }
}

extension Model {
    func makeLanguageModel() -> any LanguageModel {
        switch self {
        case .system:
            return SystemLanguageModel()
        case .mlx(let modelId):
            return MLXLanguageModel(modelId: modelId)
        case .ollama(let model):
            return OllamaLanguageModel(model: model)
        case .openAI(let model):
            guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
                fatalError("OPENAI_API_KEY not set")
            }
            return OpenAILanguageModel(apiKey: apiKey, model: model)
        case .anthropic(let model):
            guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
                fatalError("ANTHROPIC_API_KEY not set")
            }
            return AnthropicLanguageModel(apiKey: apiKey, model: model)
        }
    }
}
