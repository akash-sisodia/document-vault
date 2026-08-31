import Foundation
import SwiftData

enum PrivacyCategory: String, CaseIterable, Identifiable {
    case local = "Local"
    case privateItem = "Private"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .local: return "folder.fill"
        case .privateItem: return "lock.fill"
        }
    }
}

@Model
final class Profile {
    var id: UUID
    var name: String
    var relation: String
    var dateOfBirth: Date?
    var notes: String?
    var photoData: Data?

    @Relationship(deleteRule: .cascade, inverse: \VaultDocument.profile)
    var documents: [VaultDocument] = []

    init(
        id: UUID = UUID(),
        name: String,
        relation: String = "Self",
        dateOfBirth: Date? = nil,
        notes: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.relation = relation
        self.dateOfBirth = dateOfBirth
        self.notes = notes
        self.photoData = photoData
    }
}

@Model
final class VaultDocument {
    var id: UUID
    var title: String
    var date: Date
    var privacyCategory: String
    var tag: String
    var rawOCRText: String
    var issuer: String?
    var notes: String?
    var photosData: [Data] = []
    var isAIProcessed: Bool = false
    var structuredDataJSON: String?

    var profile: Profile?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date = Date(),
        privacyCategory: String = PrivacyCategory.local.rawValue,
        tag: String = "",
        rawOCRText: String = "",
        issuer: String? = nil,
        notes: String? = nil,
        photosData: [Data] = [],
        isAIProcessed: Bool = false,
        structuredDataJSON: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.privacyCategory = privacyCategory
        self.tag = tag
        self.rawOCRText = rawOCRText
        self.issuer = issuer
        self.notes = notes
        self.photosData = photosData
        self.isAIProcessed = isAIProcessed
        self.structuredDataJSON = structuredDataJSON
    }

    var structuredData: [String: String] {
        get {
            guard let data = structuredDataJSON?.data(using: .utf8) else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue), let json = String(data: data, encoding: .utf8) {
                structuredDataJSON = json
            }
        }
    }
}
