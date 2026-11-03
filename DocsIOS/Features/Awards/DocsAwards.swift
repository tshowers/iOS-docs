import Foundation
import TODDAwardsKit

/// Docs' awards on the shared, account-synced TODDAwardsKit - the same set
/// on iPhone and iPad, each award celebrated once (the server decides
/// what's new). Most are checked against the real counts that
/// `/getting-started/docs` returns, so they can't drift from the data.
enum DocsAwards {
    static let ladder: [Award] = [
        Award(id: "first-answer", title: "The Expert", copy: "You wrote down how you answer. Now you never have to type it twice.", symbol: "text.bubble.fill"),
        Award(id: "committer", title: "The Committer", copy: "You didn't just write it \u{2014} you kept it.", symbol: "checkmark.seal.fill"),
        Award(id: "introduction", title: "The Introduction", copy: "Your profile is complete. Your documents know who wrote them.", symbol: "person.text.rectangle.fill"),
        Award(id: "librarian", title: "The Librarian", copy: "Your first document is in the library.", symbol: "books.vertical.fill"),
        Award(id: "editor", title: "The Editor", copy: "Draft, change, save. That's how good writing happens.", symbol: "pencil.line"),
        Award(id: "maya-mentor", title: "Maya's Mentor", copy: "Maya can answer like you now. You taught her that.", symbol: "graduationcap.fill"),
        Award(id: "all-set", title: "The Regular", copy: "Getting Started, finished. You know your way around.", symbol: "star.circle.fill"),
        Award(id: "archivist", title: "The Archivist", copy: "Ten documents. Nothing gets lost with you around.", symbol: "archivebox.fill"),
        Award(id: "encyclopedia", title: "The Encyclopedia", copy: "Ten answers ready to go. Ask you anything.", symbol: "book.fill"),
        Award(id: "institution", title: "The Institution", copy: "Fifty documents. You're the one everyone asks.", symbol: "building.columns.fill", hidden: true),
    ]

    @MainActor
    static func makeService(authService: AuthService) -> AwardsService {
        AwardsService(
            appName: "Docs",
            ladder: ladder,
            api: AwardsAPI(
                baseURL: AppConfig.fromBundle().apiBaseURL,
                product: "docs",
                idToken: { @MainActor [weak authService] in
                    guard let authService else { throw AuthServiceError.notSignedIn }
                    return try await authService.freshIdToken()
                }
            )
        )
    }
}

/// Docs' record points - each checked at the moment it could become true.
extension AwardsService {
    /// The wizard's answer is built (before sign-in, so it's celebrated
    /// here and synced silently later).
    func recordFirstAnswerWritten() {
        unlock("first-answer")
    }

    func recordSignedUp() {
        unlock("committer")
    }

    func recordDocumentSaved() {
        unlock("editor")
    }

    /// Checked when the library loads and when Getting Started closes.
    func recordProgress(_ progress: DocsProgress) {
        if progress.steps.first(where: { $0.id == "profile" })?.done == true { unlock("introduction") }
        if progress.allDone { unlock("all-set") }
        guard let counts = progress.counts else { return }
        if counts.answers >= 1 { unlock("first-answer") }
        if counts.answers >= 10 { unlock("encyclopedia") }
        if counts.documents >= 1 { unlock("librarian") }
        if counts.documents >= 10 { unlock("archivist") }
        if counts.documents >= 50 { unlock("institution") }
        if counts.mayaAnswers >= 1 { unlock("maya-mentor") }
    }
}

/// `GET /getting-started/docs`'s payload, read here only for the award
/// counts - the checklist page itself is TODDProfileKit's GettingStartedView.
struct DocsProgress: Decodable {
    struct Step: Decodable {
        let id: String
        let done: Bool
    }

    struct Counts: Decodable {
        let answers: Int
        let documents: Int
        let mayaAnswers: Int
    }

    let steps: [Step]
    let allDone: Bool
    let counts: Counts?
}

struct DocsProgressEnvelope: Decodable {
    let data: DocsProgress
}
