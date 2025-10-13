import AuthenticationServices
import CryptoKit
import Foundation

actor HuggingFaceOAuth {
    private var cachedToken: OAuthToken?
    private var refreshTask: Task<OAuthToken, Error>?
    private var codeVerifier: String?

    private let clientID: String
    private let redirectURI: String

    init(clientID: String, redirectURI: String) {
        self.clientID = clientID
        self.redirectURI = redirectURI
    }

    func getValidToken() async throws -> OAuthToken {
        // Return cached token if valid
        if let token = cachedToken, await token.isValid {
            return token
        }

        // If refresh already in progress, wait for it
        if let task = refreshTask {
            return try await task.value
        }

        // No valid token and no refresh in progress - need fresh authentication
        throw OAuthError.authenticationRequired
    }

    func authenticate() async throws -> String {
        // Generate PKCE values
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        self.codeVerifier = verifier

        // Build authorization URL
        var components = URLComponents(string: "https://huggingface.co/oauth/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid profile email read-repos read-mcp inference-api"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: generateState()),
        ]

        guard let authURL = components.url,
            let scheme = URLComponents(string: redirectURI)?.scheme
        else {
            throw OAuthError.sessionFailedToStart
        }

        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: scheme
                ) { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let url = callbackURL else {
                        continuation.resume(throwing: OAuthError.invalidCallback)
                        return
                    }

                    // Extract code outside of actor context
                    guard
                        let code = URLComponents(string: url.absoluteString)?
                            .queryItems?
                            .first(where: { $0.name == "code" })?
                            .value
                    else {
                        continuation.resume(throwing: OAuthError.invalidCallback)
                        return
                    }

                    continuation.resume(returning: code)
                }

                session.prefersEphemeralWebBrowserSession = false
                session.presentationContextProvider = PresentationContextProvider.shared

                if !session.start() {
                    continuation.resume(throwing: OAuthError.sessionFailedToStart)
                }
            }
        }
    }

    func exchangeCode(_ code: String) async throws -> OAuthToken {
        guard let verifier = codeVerifier else {
            throw OAuthError.missingCodeVerifier
        }

        var request = URLRequest(url: URL(string: "https://huggingface.co/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier,
        ]

        request.httpBody =
            params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw OAuthError.tokenExchangeFailed
        }

        let tokenResponse = try await MainActor.run {
            try JSONDecoder().decode(TokenResponse.self, from: data)
        }
        let token = OAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )

        self.cachedToken = token
        self.codeVerifier = nil

        return token
    }

    func refreshToken(using refreshToken: String) async throws -> OAuthToken {
        // Start refresh task if not already running
        if let task = refreshTask {
            return try await task.value
        }

        let task = Task<OAuthToken, Error> {
            try await performRefresh(refreshToken: refreshToken)
        }
        refreshTask = task

        defer {
            Task { clearRefreshTask() }
        }

        return try await task.value
    }

    private func clearRefreshTask() {
        refreshTask = nil
    }

    private func performRefresh(refreshToken: String) async throws -> OAuthToken {
        var request = URLRequest(url: URL(string: "https://huggingface.co/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ]

        request.httpBody =
            params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw OAuthError.tokenExchangeFailed
        }

        let tokenResponse = try await MainActor.run {
            try JSONDecoder().decode(TokenResponse.self, from: data)
        }
        let token = OAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )

        self.cachedToken = token
        return token
    }

    private func extractCode(from url: URL) -> String? {
        URLComponents(string: url.absoluteString)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateState() -> String {
        UUID().uuidString
    }
}
