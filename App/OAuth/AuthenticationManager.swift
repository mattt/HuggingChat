import SwiftUI
import Observation
import AuthenticationServices

@Observable
@MainActor
class AuthenticationManager {
    var isAuthenticated = false
    var currentUser: UserInfo?
    var authToken: OAuthToken?
    var errorMessage: String?

    private let oauthActor: HuggingFaceOAuth
    private let accountIdentifier = "default"

    init(clientID: String, redirectURI: String) {
        self.oauthActor = HuggingFaceOAuth(clientID: clientID, redirectURI: redirectURI)

        // Try to load existing token
        Task {
            await loadStoredToken()
        }
    }

    func signIn() async {
        do {
            // Start OAuth flow
            let code = try await oauthActor.authenticate()

            // Exchange code for token
            let token = try await oauthActor.exchangeCode(code)

            // Store in keychain
            try KeychainStorage.store(token, account: accountIdentifier)

            // Update UI state
            self.authToken = token
            self.isAuthenticated = true

            // Fetch user info
            await fetchUserInfo(token: token)

        } catch let error as ASWebAuthenticationSessionError {
            if error.code == .canceledLogin {
                // User cancelled - don't show error
                return
            }
            self.errorMessage = "Authentication failed: \(error.localizedDescription)"
        } catch {
            self.errorMessage = "Authentication failed: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        do {
            try KeychainStorage.delete(account: accountIdentifier)
        } catch {
            print("Keychain deletion error: \(error)")
        }

        self.isAuthenticated = false
        self.currentUser = nil
        self.authToken = nil
    }

    func getValidToken() async throws -> String {
        if let token = authToken, token.isValid {
            return token.accessToken
        }

        // Token expired, try refresh
        guard let token = authToken,
            let refreshToken = token.refreshToken
        else {
            throw OAuthError.authenticationRequired
        }

        do {
            let newToken = try await oauthActor.refreshToken(using: refreshToken)
            try KeychainStorage.store(newToken, account: accountIdentifier)
            self.authToken = newToken
            return newToken.accessToken
        } catch {
            // Refresh failed, require re-authentication
            self.isAuthenticated = false
            throw OAuthError.authenticationRequired
        }
    }

    private func loadStoredToken() async {
        do {
            guard let token = try KeychainStorage.retrieve(account: accountIdentifier),
                token.isValid
            else {
                return
            }

            self.authToken = token
            self.isAuthenticated = true
            await fetchUserInfo(token: token)

        } catch {
            print("Failed to load stored token: \(error)")
            // Clear invalid token from keychain
            try? KeychainStorage.delete(account: accountIdentifier)
        }
    }

    private func fetchUserInfo(token: OAuthToken) async {
        var request = URLRequest(url: URL(string: "https://huggingface.co/oauth/userinfo")!)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            self.currentUser = try JSONDecoder().decode(UserInfo.self, from: data)
        } catch {
            print("Failed to fetch user info: \(error)")
        }
    }
}
