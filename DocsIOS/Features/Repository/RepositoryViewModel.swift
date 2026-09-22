import Foundation

/// Native adaptation of `repository.component.ts`'s search/filter logic -
/// same substring match across question/answers/recommendations/resources,
/// computed client-side over the list `DocsAPIClient.fetchKnowledgeBase()`
/// already fetched in full (no server-side search endpoint, matching how
/// web filters its own already-subscribed Firestore snapshot).
@MainActor
final class RepositoryViewModel: ObservableObject {
    @Published var entries: [KnowledgeBaseEntry] = []
    @Published var searchText = "" {
        didSet { applyFilter() }
    }
    @Published var filteredEntries: [KnowledgeBaseEntry] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let apiClient: DocsAPIClient

    init(apiClient: DocsAPIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = ""
        do {
            entries = try await apiClient.fetchKnowledgeBase()
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func delete(_ entry: KnowledgeBaseEntry) async {
        do {
            try await apiClient.deleteKnowledgeBaseEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func citation(for answer: KnowledgeBaseAnswer) -> String {
        let domain = Self.domain(from: answer.source)
        let accessed = Self.isoDateOnlyFormatter.string(from: Date())
        return "\(answer.answer) Source: \(domain). \(answer.source) (accessed \(accessed))."
    }

    private func applyFilter() {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else {
            filteredEntries = entries
            return
        }

        filteredEntries = entries.filter { entry in
            if entry.question.lowercased().contains(query) { return true }
            if entry.answers.contains(where: { $0.answer.lowercased().contains(query) || $0.source.lowercased().contains(query) }) { return true }
            if entry.recommendations.contains(where: { $0.text.lowercased().contains(query) || ($0.type ?? "").lowercased().contains(query) }) { return true }
            if entry.resources.contains(where: { $0.link.lowercased().contains(query) }) { return true }
            return false
        }
    }

    private static let isoDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func domain(from urlString: String) -> String {
        guard let host = URL(string: urlString)?.host else { return urlString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
