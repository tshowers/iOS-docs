import Foundation

@MainActor
final class DocumentListViewModel: ObservableObject {
    @Published private(set) var documents: [TeamDocument] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: DocsAPIClient

    init(apiClient: DocsAPIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            documents = try await apiClient.fetchDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ document: TeamDocument) async {
        do {
            try await apiClient.deleteDocument(id: document.id)
            documents.removeAll { $0.id == document.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upsert(_ document: TeamDocument) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
        } else {
            documents.insert(document, at: 0)
        }
    }
}
