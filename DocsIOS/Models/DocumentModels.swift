import Foundation

/// Mirrors the normalized document shape returned by the docs mobile API.
struct TeamDocument: Codable, Identifiable {
    let id: String
    var name: String
    var title: String?
    var src: String?
    var topic: String?
    var author: String?
    var htmlContent: String?
    var uploadDate: String?
    var updatedAt: String?
    var dueDate: String?
    var contactId: String?
    var storagePath: String?
    var mimeType: String?
    var sizeBytes: Int?
    var summary: String?
    var description: String?
    var lastPostedAt: String?
    var lastPostedPlatforms: [String]
    var eligibleForSocial: Bool
    var type: String?
    var status: String?
    var createdAt: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled document"
        title = try container.decodeIfPresent(String.self, forKey: .title)
        src = try container.decodeIfPresent(String.self, forKey: .src)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        htmlContent = try container.decodeIfPresent(String.self, forKey: .htmlContent)
        uploadDate = try container.decodeIfPresent(String.self, forKey: .uploadDate)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        contactId = try container.decodeIfPresent(String.self, forKey: .contactId)
        storagePath = try container.decodeIfPresent(String.self, forKey: .storagePath)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        sizeBytes = try container.decodeIfPresent(Int.self, forKey: .sizeBytes)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        lastPostedAt = try container.decodeIfPresent(String.self, forKey: .lastPostedAt)
        lastPostedPlatforms = try container.decodeIfPresent([String].self, forKey: .lastPostedPlatforms) ?? []
        eligibleForSocial = try container.decodeIfPresent(Bool.self, forKey: .eligibleForSocial) ?? false
        type = try container.decodeIfPresent(String.self, forKey: .type)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    init(id: String, name: String, title: String? = nil, src: String? = nil, topic: String? = nil, author: String? = nil, htmlContent: String? = nil, uploadDate: String? = nil, updatedAt: String? = nil, dueDate: String? = nil, contactId: String? = nil, storagePath: String? = nil, mimeType: String? = nil, sizeBytes: Int? = nil, summary: String? = nil, description: String? = nil, lastPostedAt: String? = nil, lastPostedPlatforms: [String] = [], eligibleForSocial: Bool = false, type: String? = nil, status: String? = nil, createdAt: String? = nil) {
        self.id = id
        self.name = name
        self.title = title
        self.src = src
        self.topic = topic
        self.author = author
        self.htmlContent = htmlContent
        self.uploadDate = uploadDate
        self.updatedAt = updatedAt
        self.dueDate = dueDate
        self.contactId = contactId
        self.storagePath = storagePath
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.summary = summary
        self.description = description
        self.lastPostedAt = lastPostedAt
        self.lastPostedPlatforms = lastPostedPlatforms
        self.eligibleForSocial = eligibleForSocial
        self.type = type
        self.status = status
        self.createdAt = createdAt
    }
}

struct DocumentListEnvelope: Codable {
    let success: Bool
    let documents: [TeamDocument]
}

struct DocumentEnvelope: Codable {
    let success: Bool
    let document: TeamDocument
}

/// Only the fields the mobile editor sets. `type`/`recordKind` are always
/// "draft" here - this app only creates text documents, not file uploads.
struct DocumentPayload: Encodable {
    var name: String
    var title: String?
    var htmlContent: String?
    var type = "draft"
    var recordKind = "draft"
}
