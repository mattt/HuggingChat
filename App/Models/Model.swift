enum Model: Hashable, Codable, Sendable {
    case system
    case mlx(String)
    case ollama(String)
    case openAI(String)
    case anthropic(String)
}
