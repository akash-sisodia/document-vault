import Combine
import Foundation
import SwiftUI

@MainActor
final class DocumentTagStore: ObservableObject {
    static let shared = DocumentTagStore()

    static let defaultTags = [
        "Passport",
        "National ID",
        "Driver License",
        "Visa",
        "Birth Certificate",
        "Insurance",
        "Other",
    ]
    private static let storageKey = "DocumentTagCatalog"

    @Published private(set) var tags: [String]

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.storageKey), !saved.isEmpty {
            tags = Self.normalized(saved)
        } else {
            tags = Self.defaultTags
            persist()
        }
    }

    var filterChips: [String] {
        ["All"] + tags
    }

    func addTag(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return false
        }
        tags.append(trimmed)
        persist()
        return true
    }

    func renameTag(from oldName: String, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let index = tags.firstIndex(of: oldName) else { return false }
        if tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame && $0 != oldName }) {
            return false
        }
        tags[index] = trimmed
        persist()
        return true
    }

    func deleteTag(_ name: String) {
        tags.removeAll { $0 == name }
        persist()
    }

    func ensureLegacyTagsVisible(from assigned: [String]) {
        var changed = false
        for value in assigned {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                tags.append(trimmed)
                changed = true
            }
        }
        if changed { persist() }
    }

    private func persist() {
        UserDefaults.standard.set(tags, forKey: Self.storageKey)
    }

    private static func normalized(_ values: [String]) -> [String] {
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !result.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                result.append(trimmed)
            }
        }
        return result.isEmpty ? defaultTags : result
    }
}

enum DocumentAppearance {
    static func tagColor(_ tag: String) -> Color {
        switch tag {
        case "Passport": return .blue
        case "National ID": return .indigo
        case "Driver License": return .green
        case "Visa": return .purple
        case "Birth Certificate": return .teal
        case "Insurance": return .orange
        case "": return .gray
        default: return .orange
        }
    }

    static func privacyColor(_ privacy: String) -> Color {
        privacy == PrivacyCategory.privateItem.rawValue ? .purple : .blue
    }

    static func displayTag(_ tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untagged" : trimmed
    }
}
