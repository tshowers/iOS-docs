import Foundation

/// Mirrors `knowledge-base/kb.service.js`'s response-flow record shape,
/// same data `repository.component.ts` reads from Firestore directly on
/// web - native goes through `/mobile/docs/knowledge-base`
/// (knowledgeBaseMobileRoutes.js) instead, same verified-REST pattern as
/// every other mobile surface in this app.
struct KnowledgeBaseAnswer: Codable, Identifiable {
    var id: String { source + answer }
    let answer: String
    let source: String

    init(answer: String, source: String) {
        self.answer = answer
        self.source = source
    }
}

/// Body for `POST /mobile/docs/knowledge-base` (kb.service.js
/// buildCreatePayload) - the same response-flow shape the web builder saves.
struct KnowledgeBaseCreatePayload: Encodable {
    let title: String
    let question: String
    let response: String
    let answers: [KnowledgeBaseAnswer]
    let category: String
    let keywords: [String]
}

struct KnowledgeBaseRecommendation: Codable, Identifiable {
    var id: String { link + text }
    let text: String
    let link: String
    let type: String?
}

struct KnowledgeBaseResource: Codable, Identifiable {
    var id: String { link }
    let link: String
}

struct KnowledgeBaseEntry: Codable, Identifiable {
    let id: String
    let question: String
    let category: String?
    let answers: [KnowledgeBaseAnswer]
    let recommendations: [KnowledgeBaseRecommendation]
    let resources: [KnowledgeBaseResource]
    let keywords: [String]?
    let updatedAt: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category)
        answers = try container.decodeIfPresent([KnowledgeBaseAnswer].self, forKey: .answers) ?? []
        recommendations = try container.decodeIfPresent([KnowledgeBaseRecommendation].self, forKey: .recommendations) ?? []
        resources = try container.decodeIfPresent([KnowledgeBaseResource].self, forKey: .resources) ?? []
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct KnowledgeBaseListEnvelope: Codable {
    let success: Bool
    let items: [KnowledgeBaseEntry]
}
