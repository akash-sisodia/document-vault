import Foundation
import Combine
import UIKit

struct AppStoreResponse: Codable {
    let resultCount: Int
    let results: [AppStoreResult]
}

struct AppStoreResult: Codable {
    let version: String
    let releaseNotes: String?
    let trackId: Int?
    let bundleId: String?
    let trackViewUrl: String?
}

enum UpdateStatus: Equatable {
    case noUpdateAvailable
    case updateAvailable(version: String, releaseNotes: String?)
    case error(String)
}

@MainActor
final class InAppUpdateManager: ObservableObject {

    static let shared = InAppUpdateManager()

    @Published private(set) var updateStatus: UpdateStatus = .noUpdateAvailable
    @Published var showUpdateAlert = false
    @Published private(set) var currentVersion: String

    private var appStoreID: String { AppConstants.appStoreId }
    private let userDefaults = UserDefaults.standard
    private let skipUpdateKey = "skipUpdateVersion"
    private let remindLaterKey = "remindLaterDate"
    private let remindLaterIntervalDays = 2
    private var inFlightUpdateCheck: Task<Void, Never>?

    private init() {
        currentVersion = AppConstants.appVersion
    }

    var appStoreURL: URL { AppConstants.appStoreURL }

    var availableStoreVersion: String? {
        guard case .updateAvailable(let version, _) = updateStatus else { return nil }
        return version
    }

    func hasUpdateAvailable() -> Bool {
        if case .updateAvailable = updateStatus { return true }
        return false
    }

    func checkForUpdates(force: Bool = false) async {
        guard !appStoreID.isEmpty else {
            updateStatus = .noUpdateAvailable
            showUpdateAlert = false
            return
        }

        if let inFlightUpdateCheck {
            await inFlightUpdateCheck.value
        } else {
            let task = Task { await self.performUpdateCheck() }
            inFlightUpdateCheck = task
            await task.value
            inFlightUpdateCheck = nil
        }

        guard hasUpdateAvailable() else {
            showUpdateAlert = false
            return
        }

        if !force {
            if hasSkippedCurrentUpdate() || isWithinRemindLaterWindow() {
                showUpdateAlert = false
                return
            }
        }

        showUpdateAlert = true
    }

    func performUpdate() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)") else {
            UIApplication.shared.open(appStoreURL)
            showUpdateAlert = false
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.open(appStoreURL)
        }
        showUpdateAlert = false
    }

    func skipUpdate(version: String) {
        userDefaults.set(version, forKey: skipUpdateKey)
        showUpdateAlert = false
    }

    func remindLater() {
        guard let remindDate = Calendar.current.date(
            byAdding: .day,
            value: remindLaterIntervalDays,
            to: Date()
        ) else {
            showUpdateAlert = false
            return
        }
        userDefaults.set(remindDate, forKey: remindLaterKey)
        showUpdateAlert = false
    }

    private func performUpdateCheck() async {
        let installed = currentVersion
        do {
            let storeResult = try await fetchAppStoreVersion()
            if isUpdateAvailable(currentVersion: installed, appStoreVersion: storeResult.version) {
                updateStatus = .updateAvailable(
                    version: storeResult.version,
                    releaseNotes: storeResult.releaseNotes
                )
            } else {
                updateStatus = .noUpdateAvailable
                if let skipped = userDefaults.string(forKey: skipUpdateKey),
                   skipped != storeResult.version {
                    userDefaults.removeObject(forKey: skipUpdateKey)
                }
            }
        } catch {
            if case .updateAvailable(let version, let notes) = updateStatus {
                updateStatus = .updateAvailable(version: version, releaseNotes: notes)
            } else {
                updateStatus = .error(error.localizedDescription)
            }
        }
    }

    private func fetchAppStoreVersion() async throws -> AppStoreResult {
        let country = Locale.current.region?.identifier.lowercased() ?? "us"
        let urlString = "https://itunes.apple.com/lookup?id=\(appStoreID)&country=\(country)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(AppStoreResponse.self, from: data)
        guard let first = decoded.results.first else {
            throw NSError(
                domain: "InAppUpdateManager",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No app found in App Store"]
            )
        }
        return first
    }

    private func isUpdateAvailable(currentVersion: String, appStoreVersion: String) -> Bool {
        let current = currentVersion.split(separator: ".").compactMap { Int($0) }
        let store = appStoreVersion.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(current.count, store.count)
        for index in 0..<maxCount {
            let c = index < current.count ? current[index] : 0
            let s = index < store.count ? store[index] : 0
            if s > c { return true }
            if s < c { return false }
        }
        return false
    }

    private func hasSkippedCurrentUpdate() -> Bool {
        guard case .updateAvailable(let availableVersion, _) = updateStatus else { return false }
        guard let skippedVersion = userDefaults.string(forKey: skipUpdateKey) else { return false }
        return skippedVersion == availableVersion
    }

    private func isWithinRemindLaterWindow() -> Bool {
        guard let remindDate = userDefaults.object(forKey: remindLaterKey) as? Date else {
            return false
        }
        return Date() < remindDate
    }
}
