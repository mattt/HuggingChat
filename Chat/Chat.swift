import Foundation
import SwiftData

@Model
final class Chat {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var model: Model

    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message] = []

    init(title: String = "New Chat", model: Model = .system) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.model = model
    }
}

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date

    var chat: Chat?

    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}
