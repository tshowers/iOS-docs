import Foundation

/// The Q&A answer (a Knowledge Base "response flow") the pre-sign-in wizard
/// builds. Persisted in UserDefaults so a quit mid-wizard resumes, and
/// offered after sign-in for review and Save (FirstAnswerSaveView ->
/// `POST /mobile/docs/knowledge-base`, knowledgeBaseMobileRoutes.js) - only
/// once the user reached the sign-in step, so "Already have an account?
/// Sign in" never offers a half-built one.
struct FirstAnswerDraft: Codable, Equatable {
    var starter: StarterQuestion = .pricing
    var question = StarterQuestion.pricing.question
    var answer = StarterQuestion.pricing.answer
    var isReadyToSubmit = false

    private static let storageKey = "docs.firstAnswerDraft"

    static func load() -> FirstAnswerDraft {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let draft = try? JSONDecoder().decode(FirstAnswerDraft.self, from: data) else {
            return FirstAnswerDraft()
        }
        return draft
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    mutating func choose(_ starter: StarterQuestion) {
        self.starter = starter
        question = starter.question
        answer = starter.answer
    }

    var trimmedQuestion: String { question.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedAnswer: String { answer.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isComplete: Bool { !trimmedQuestion.isEmpty && !trimmedAnswer.isEmpty }

    /// Search keywords from the question's meaningful words, so TODD and
    /// Maya can find the answer later without the user typing tags.
    var keywords: [String] {
        let stopWords: Set<String> = ["what", "do", "you", "your", "how", "does", "it", "the", "a", "an", "is", "are",
                                      "i", "to", "of", "and", "or", "for", "we", "can", "with", "long", "take", "makes"]
        let words = trimmedQuestion.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
        var seen = Set<String>()
        return (words + [starter.category.lowercased()]).filter { seen.insert($0).inserted }
    }

    /// Built in the wizard and waiting for the user to review and save it
    /// after sign-in.
    var isPendingSave: Bool { isReadyToSubmit && isComplete }

    var createPayload: KnowledgeBaseCreatePayload {
        KnowledgeBaseCreatePayload(
            title: trimmedQuestion,
            question: trimmedQuestion,
            response: trimmedAnswer,
            answers: [KnowledgeBaseAnswer(answer: trimmedAnswer, source: "")],
            category: starter.category,
            keywords: keywords
        )
    }
}

/// The questions customers ask most - one is preselected, each with a
/// ready-to-use starter answer to edit instead of a blank box.
enum StarterQuestion: String, Codable, CaseIterable, Identifiable {
    case pricing, timing, gettingStarted, different, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pricing: return "What do you charge?"
        case .timing: return "How long does it take?"
        case .gettingStarted: return "How do I get started?"
        case .different: return "What makes you different?"
        case .other: return "Other"
        }
    }

    var question: String { self == .other ? "" : label }

    var category: String {
        switch self {
        case .pricing: return "Pricing"
        case .timing, .gettingStarted: return "Process"
        case .different: return "Product"
        case .other: return "General"
        }
    }

    var answer: String {
        switch self {
        case .pricing:
            return "Pricing depends on what you need. After a quick call I'll send a clear quote, with no surprises later."
        case .timing:
            return "Most projects take a few weeks from kickoff to delivery. Once we've talked through the details, I'll give you a firm timeline."
        case .gettingStarted:
            return "Getting started is simple: book a quick call, we talk through what you need, and I send a proposal within a couple of days."
        case .different:
            return "Clients choose us because we're responsive, we explain things plainly, and we stand behind our work."
        case .other:
            return ""
        }
    }
}
