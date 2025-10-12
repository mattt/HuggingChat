import Foundation
import SwiftData

@Model
final class Chat {
    @Attribute(.unique) var id: UUID
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    private var modelType: String
    private var modelIdentifier: String?
    
    @Transient
    var model: Model {
        get {
            switch modelType {
            case "system":
                return .system
            case "mlx":
                return .mlx(modelIdentifier ?? "")
            case "huggingFace":
                return .huggingFace(modelIdentifier ?? "")
            default:
                return .system
            }
        }
        set {
            switch newValue {
            case .system:
                modelType = "system"
                modelIdentifier = nil
            case .mlx(let id):
                modelType = "mlx"
                modelIdentifier = id
            case .huggingFace(let id):
                modelType = "huggingFace"
                modelIdentifier = id
            }
        }
    }

    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message] = []

    init(title: String? = nil, model: Model = .system) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelType = "system"
        self.modelIdentifier = nil
        self.model = model
    }
    
    func updateModel(_ newModel: Model) {
        self.model = newModel
        self.updatedAt = Date()
    }
}
