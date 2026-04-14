import Foundation
import Supabase

enum AppUpdateStatus: Equatable {
    /// Current version is below minimum — user must update.
    case forceUpdate(latestVersion: String)
    /// Current version is supported but outdated — user can dismiss.
    case softUpdate(latestVersion: String)
    /// App is up to date (or check failed).
    case upToDate
}

struct AppUpdateChecker {

    static let shared = AppUpdateChecker()

    private let appStoreId = "6759346770"
    private let softSheetShownKey = "AppUpdateChecker.lastSoftSheetShown"
    private let cooldown: TimeInterval = 24 * 60 * 60 // 24 hours

    var appStoreURL: URL {
        URL(string: "itms-apps://apps.apple.com/app/id\(appStoreId)")!
    }

    // MARK: - Public

    /// Checks Supabase remote config and returns the appropriate update status.
    func checkUpdate() async -> AppUpdateStatus {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

        guard let config = await fetchRemoteConfig() else { return .upToDate }

        if isNewer(config.minimumSupportedVersion, than: currentVersion) {
            return .forceUpdate(latestVersion: config.latestVersion)
        }

        if isNewer(config.latestVersion, than: currentVersion) {
            return .softUpdate(latestVersion: config.latestVersion)
        }

        return .upToDate
    }

    /// Whether the soft-update sheet was already shown in the last 24 hours.
    var wasSoftSheetShownToday: Bool {
        guard let lastShown = UserDefaults.standard.object(forKey: softSheetShownKey) as? Date else {
            return false
        }
        return Date().timeIntervalSince(lastShown) < cooldown
    }

    /// Call when the soft-update sheet is presented to the user.
    func recordSoftSheetShown() {
        UserDefaults.standard.set(Date(), forKey: softSheetShownKey)
    }

    // MARK: - Supabase

    private struct RemoteConfig: Decodable {
        let minimumSupportedVersion: String
        let latestVersion: String

        enum CodingKeys: String, CodingKey {
            case minimumSupportedVersion = "minimum_supported_version"
            case latestVersion = "latest_version"
        }
    }

    private func fetchRemoteConfig() async -> RemoteConfig? {
        do {
            let response: RemoteConfig = try await SupabaseManager.shared.client
                .from("app_config")
                .select("minimum_supported_version, latest_version")
                .single()
                .execute()
                .value
            return response
        } catch {
            debugLog("AppUpdateChecker: failed to fetch remote config – \(error)")
            return nil
        }
    }

    // MARK: - Version comparison

    /// Returns true when `remote` is strictly greater than `local`.
    private func isNewer(_ remote: String, than local: String) -> Bool {
        remote.compare(local, options: .numeric) == .orderedDescending
    }
}
