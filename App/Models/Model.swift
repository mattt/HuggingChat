enum Model: Hashable, Codable, Sendable {
    case system
    case mlx(String)
    case huggingFace(String)
}

extension Model {
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
            return "Apple Intelligence"
        case .mlx:
            return "MLX"
        case .huggingFace(let model):
            // Extract the model name after the last slash for brevity
            return model.split(separator: "/").last.map(String.init) ?? model
        }
    }
}
