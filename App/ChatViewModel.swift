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
    private let authManager: AuthenticationManager?
    private var currentTask: Task<Void, Never>?

    init(modelContext: ModelContext, authManager: AuthenticationManager? = nil) {
        self.modelContext = modelContext
        self.authManager = authManager
    }

    func stopGenerating() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    func sendMessage(to chat: Chat, content: String) async {
        guard !content.isEmpty else { return }

        let userMessage = Message(content: content, isUser: true)
        userMessage.chat = chat
        chat.messages.append(userMessage)
        chat.updatedAt = Date()

        modelContext.insert(userMessage)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save message: \(error.localizedDescription)"
            return
        }

        currentTask = Task {
            await generateResponse(for: chat)
        }
        await currentTask?.value
        currentTask = nil
    }

    private func generateResponse(for chat: Chat) async {
        isGenerating = true
        errorMessage = nil

        do {
            let languageModel = try await chat.model.makeLanguageModel(authManager: authManager)

            guard !Task.isCancelled else {
                isGenerating = false
                return
            }

            let session = LanguageModelSession(model: languageModel)
            self.session = session

            let prompt = chat.messages
                .map { message in
                    "\(message.isUser ? "User" : "Assistant"): \(message.content)"
                }
                .joined(separator: "\n\n")

            let response = try await session.respond(to: prompt)

            guard !Task.isCancelled else {
                isGenerating = false
                return
            }

            let assistantMessage = Message(content: response.content, isUser: false)
            assistantMessage.chat = chat
            chat.messages.append(assistantMessage)
            chat.updatedAt = Date()

            modelContext.insert(assistantMessage)
            try modelContext.save()

            if chat.title == nil {
                await generateTitle(for: chat)
            }
        } catch is CancellationError {
            print("Response generation cancelled")
        } catch {
            print("Error generating response: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to generate response: \(error.localizedDescription)"
            }
        }

        isGenerating = false
    }

    private func generateTitle(for chat: Chat) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let systemModel = SystemLanguageModel()
                    let session = LanguageModelSession(model: systemModel)

                    let conversationText = chat.messages
                        .map { "\($0.isUser ? "User" : "Assistant"): \($0.content)" }
                        .joined(separator: "\n")

                    let titlePrompt = """
                        Generate a short, concise title (5 words or less) for this conversation:

                        \(conversationText)

                        Return only the title, nothing else.
                        """

                    let response = try await session.respond(to: titlePrompt)

                    let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

                    await MainActor.run {
                        chat.title = title
                        try? self.modelContext.save()
                    }
                } catch {
                    print("Failed to generate title: \(error.localizedDescription)")
                    //                    await MainActor.run {
                    //                        self.errorMessage = "Failed to generate title: \(error.localizedDescription)"
                    //                    }
                }
            }
        }
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
    func makeLanguageModel(authManager: AuthenticationManager?) async throws -> any LanguageModel {
        switch self {
        case .system:
            return SystemLanguageModel()
        case .mlx(let modelId):
            return MLXLanguageModel(modelId: modelId)
        case .huggingFace(let model):
            guard let authManager = authManager else {
                throw ModelError.authenticationRequired
            }
            let token = try await authManager.getValidToken()
            return OpenAILanguageModel(
                baseURL: URL(string: "https://router.huggingface.co/v1")!,
                apiKey: token,
                model: model
            )
        }
    }
}

enum ModelError: LocalizedError {
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication required to use HuggingFace models. Please sign in."
        }
    }
}
