import Foundation

struct OAuthToken: Sendable, Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    var isValid: Bool {
        Date() < expiresAt.addingTimeInterval(-300)  // 5 min buffer
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

struct TokenResponse: Sendable, Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct UserInfo: Sendable, Codable {
    let sub: String
    let name: String?
    let preferredUsername: String?
    let email: String?
    let picture: String?

    enum CodingKeys: String, CodingKey {
        case sub, name, email, picture
        case preferredUsername = "preferred_username"
    }
}

enum OAuthError: LocalizedError, Sendable {
    case authenticationRequired
    case invalidCallback
    case sessionFailedToStart
    case missingCodeVerifier
    case tokenExchangeFailed
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired: return "Authentication required"
        case .invalidCallback: return "Invalid callback"
        case .sessionFailedToStart: return "Session failed to start"
        case .missingCodeVerifier: return "Missing code verifier"
        case .tokenExchangeFailed: return "Token exchange failed"
        case .keychainError(let status): return "Keychain error: \(status)"
        }
    }
}
