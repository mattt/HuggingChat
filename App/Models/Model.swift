enum Model: Hashable, Codable, Sendable {
    case system
    case mlx(String)
    case huggingFace(String)
}
