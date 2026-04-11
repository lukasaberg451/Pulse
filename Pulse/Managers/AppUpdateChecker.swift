import Foundation

struct AppUpdateChecker {

    static let shared = AppUpdateChecker()

    private let bundleId = "com.fyrafemett.Pulse"
    private let appStoreId = "6759346770"
    private let cacheKey = "AppUpdateChecker.lastCheck"
    private let cacheVersionKey = "AppUpdateChecker.latestVersion"
    private let cacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours

    var appStoreURL: URL {
        URL(string: "itms-apps://apps.apple.com/app/id\(appStoreId)")!
    }

    // MARK: - Public

    /// Returns the latest App Store version string when an update is available,
    /// or `nil` when the local version is current (or on any failure).
    /// A `minimumVersion` parameter can be added here later for hard-gate logic.
    func availableUpdate() async -> String? {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

        // Check cache first
        if let cached = cachedVersion() {
            return isNewer(cached, than: currentVersion) ? cached : nil
        }

        guard let latestVersion = await fetchLatestVersion() else { return nil }

        saveCache(version: latestVersion)

        return isNewer(latestVersion, than: currentVersion) ? latestVersion : nil
    }

    // MARK: - Network

    private func fetchLatestVersion() async -> String? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=se") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
            return response.results.first?.version
        } catch {
            debugLog("AppUpdateChecker: failed to fetch version – \(error)")
            return nil
        }
    }

    // MARK: - Cache

    private func cachedVersion() -> String? {
        let defaults = UserDefaults.standard
        guard let lastCheck = defaults.object(forKey: cacheKey) as? Date,
              Date().timeIntervalSince(lastCheck) < cacheTTL,
              let version = defaults.string(forKey: cacheVersionKey) else {
            return nil
        }
        return version
    }

    private func saveCache(version: String) {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: cacheKey)
        defaults.set(version, forKey: cacheVersionKey)
    }

    // MARK: - Version comparison

    private func isNewer(_ remote: String, than local: String) -> Bool {
        remote.compare(local, options: .numeric) == .orderedDescending
    }
}

// MARK: - iTunes Lookup Response

private struct ITunesLookupResponse: Decodable {
    let results: [AppResult]

    struct AppResult: Decodable {
        let version: String
    }
}
