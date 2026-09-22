import Foundation

/// Native re-derivation of `document-home.component.ts`'s
/// `refreshDiagnosticsVm()` - same four health meters (findability,
/// freshness, proposal reuse, capture readiness) computed from the same
/// `/mobile/docs` document list `DocumentListView` already fetches, rather
/// than a new backend aggregate endpoint. Mirrors outreach-ios/network-ios:
/// adapt the web cockpit's math to native, don't port its full
/// BusinessSymptom/evidence framework verbatim.
struct DocsStatusSummary {
    let totalDocumentCount: Int
    let proposalCount: Int
    let draftCount: Int
    let duplicateTitleCount: Int
    let staleDocumentCount: Int
    let responseReadyCount: Int
    let findabilityHealth: Int
    let knowledgeFreshness: Int
    let proposalReuse: Int
    let captureReadiness: Int
    let knowledgeScore: Int
}

@MainActor
final class DocsStatusViewModel: ObservableObject {
    @Published var summary: DocsStatusSummary?
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let apiClient: DocsAPIClient
    private let staleThresholdSeconds: TimeInterval = 60 * 60 * 24 * 90
    private let isoFormatter = ISO8601DateFormatter()

    init(apiClient: DocsAPIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = ""
        do {
            let documents = try await apiClient.fetchDocuments()
            summary = Self.summarize(documents, staleThresholdSeconds: staleThresholdSeconds, isoFormatter: isoFormatter)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private static func summarize(_ documents: [TeamDocument], staleThresholdSeconds: TimeInterval, isoFormatter: ISO8601DateFormatter) -> DocsStatusSummary {
        let total = documents.count
        let docBase = max(total, 1)

        let proposalCount = documents.filter { normalizedType($0) == "proposal" }.count
        let draftCount = documents.filter { normalizedType($0) == "draft" || isDraftStatus($0) }.count

        var titleCounts: [String: Int] = [:]
        for document in documents {
            let normalizedTitle = normalizedTitle(document)
            guard !normalizedTitle.isEmpty else { continue }
            titleCounts[normalizedTitle, default: 0] += 1
        }
        let duplicateTitleCount = titleCounts.values.filter { $0 > 1 }.reduce(0, +)

        let staleThreshold = Date().addingTimeInterval(-staleThresholdSeconds)
        let staleDocumentCount = documents.filter { document in
            guard let timestamp = timestamp(document, isoFormatter: isoFormatter) else { return false }
            return timestamp < staleThreshold
        }.count

        let responseReadyCount = documents.filter { document in
            let type = normalizedType(document)
            return type == "proposal" || type == "document" || type == "draft"
        }.count

        let duplicatePressure = Int((Double(duplicateTitleCount) / Double(docBase) * 100).rounded())
        let stalePressure = Int((Double(staleDocumentCount) / Double(docBase) * 100).rounded())
        let proposalCoverage = Int((Double(proposalCount) / Double(docBase) * 100).rounded())
        let draftPressure = Int((Double(draftCount) / Double(docBase) * 100).rounded())

        let findabilityHealth = max(0, 100 - duplicatePressure)
        let knowledgeFreshness = max(0, 100 - stalePressure)
        let proposalReuse = min(100, proposalCoverage)
        let captureReadiness = max(0, 100 - draftPressure)
        let knowledgeScore = (findabilityHealth + knowledgeFreshness + proposalReuse + captureReadiness) / 4

        return DocsStatusSummary(
            totalDocumentCount: total,
            proposalCount: proposalCount,
            draftCount: draftCount,
            duplicateTitleCount: duplicateTitleCount,
            staleDocumentCount: staleDocumentCount,
            responseReadyCount: responseReadyCount,
            findabilityHealth: findabilityHealth,
            knowledgeFreshness: knowledgeFreshness,
            proposalReuse: proposalReuse,
            captureReadiness: captureReadiness,
            knowledgeScore: knowledgeScore
        )
    }

    private static func normalizedType(_ document: TeamDocument) -> String {
        (document.type ?? "").trimmingCharacters(in: .whitespaces).lowercased()
    }

    private static func isDraftStatus(_ document: TeamDocument) -> Bool {
        (document.status ?? "").trimmingCharacters(in: .whitespaces).lowercased() == "draft"
    }

    private static func normalizedTitle(_ document: TeamDocument) -> String {
        let title = document.title?.isEmpty == false ? document.title! : document.name
        return title.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private static func timestamp(_ document: TeamDocument, isoFormatter: ISO8601DateFormatter) -> Date? {
        guard let raw = document.updatedAt ?? document.createdAt else { return nil }
        return isoFormatter.date(from: raw)
    }
}
