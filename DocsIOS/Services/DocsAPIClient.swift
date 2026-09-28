import Foundation

enum DocsAPIError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in to load your documents."
        case .invalidResponse:
            return "The server response could not be understood."
        case .httpError(let code):
            return "The server returned HTTP \(code)."
        }
    }
}

/// Talks to `todd-backend`'s /api/mobile/docs/* endpoints
/// (docsMobileRoutes.js) - a verified-token surface reusing
/// docs.controller.js's existing business logic, same pattern as
/// network-ios's NetworkAPIClient / moves-ios's MovesAPIClient.
final class DocsAPIClient {
    private let config: AppConfig
    private let authService: AuthService
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(config: AppConfig, authService: AuthService) {
        self.config = config
        self.authService = authService
    }

    func fetchDocuments() async throws -> [TeamDocument] {
        let url = config.apiBaseURL.appending(path: "mobile/docs")
        let data = try await authorizedRequest(method: "GET", url: url)
        return try decoder.decode(DocumentListEnvelope.self, from: data).documents
    }

    @discardableResult
    func createDocument(_ payload: DocumentPayload) async throws -> TeamDocument {
        let url = config.apiBaseURL.appending(path: "mobile/docs")
        let data = try await authorizedRequest(method: "POST", url: url, body: try encoder.encode(payload))
        return try decoder.decode(DocumentEnvelope.self, from: data).document
    }

    @discardableResult
    func updateDocument(id: String, payload: DocumentPayload) async throws -> TeamDocument {
        let url = config.apiBaseURL.appending(path: "mobile/docs/\(id)")
        let data = try await authorizedRequest(method: "PUT", url: url, body: try encoder.encode(payload))
        return try decoder.decode(DocumentEnvelope.self, from: data).document
    }

    func deleteDocument(id: String) async throws {
        let url = config.apiBaseURL.appending(path: "mobile/docs/\(id)")
        _ = try await authorizedRequest(method: "DELETE", url: url)
    }

    func fetchKnowledgeBase() async throws -> [KnowledgeBaseEntry] {
        let url = config.apiBaseURL.appending(path: "mobile/docs/knowledge-base")
        let data = try await authorizedRequest(method: "GET", url: url)
        return try decoder.decode(KnowledgeBaseListEnvelope.self, from: data).items
    }

    func createKnowledgeBaseEntry(_ payload: KnowledgeBaseCreatePayload) async throws {
        let url = config.apiBaseURL.appending(path: "mobile/docs/knowledge-base")
        _ = try await authorizedRequest(method: "POST", url: url, body: try encoder.encode(payload))
    }

    func deleteKnowledgeBaseEntry(id: String) async throws {
        let url = config.apiBaseURL.appending(path: "mobile/docs/knowledge-base/\(id)")
        _ = try await authorizedRequest(method: "DELETE", url: url)
    }

    func fetchProgress() async throws -> DocsProgress {
        let url = config.apiBaseURL.appending(path: "getting-started/docs")
        let data = try await authorizedRequest(method: "GET", url: url)
        return try decoder.decode(DocsProgressEnvelope.self, from: data).data
    }

    func linkAppStorePurchase(appAccountToken: String) async throws {
        let payload = AppStoreLinkRequest(appAccountToken: appAccountToken, productKey: "docs")
        let url = config.apiBaseURL.appending(path: "app-store/link")
        _ = try await authorizedRequest(method: "POST", url: url, body: try encoder.encode(payload))
    }

    /// Sends a StoreKit transaction's signed JWS right after a purchase or
    /// restore; the backend verifies Apple's signature and returns the fresh
    /// entitlement - an immediate unlock that doesn't depend on Apple's
    /// server notification arriving (TestFlight renews about daily).
    func submitAppStoreTransaction(signedTransaction: String) async throws -> AppStoreEntitlement {
        let url = config.apiBaseURL.appending(path: "app-store/transactions/docs")
        let body = try encoder.encode(AppStoreTransactionRequest(signedTransaction: signedTransaction))
        let data = try await authorizedRequest(method: "POST", url: url, body: body)
        return try decoder.decode(AppStoreEntitlementEnvelope.self, from: data).entitlement
    }

    func fetchAppStoreEntitlement() async throws -> AppStoreEntitlement {
        let url = config.apiBaseURL.appending(path: "app-store/entitlement/docs")
        let data = try await authorizedRequest(method: "GET", url: url)
        return try decoder.decode(AppStoreEntitlementEnvelope.self, from: data).entitlement
    }

    // MARK: - Request building

    private func authorizedRequest(method: String, url: URL, body: Data? = nil) async throws -> Data {
        let idToken = try await authService.freshIdToken()

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocsAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DocsAPIError.httpError(httpResponse.statusCode)
        }

        return data
    }
}
