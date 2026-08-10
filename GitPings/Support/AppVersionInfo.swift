import Foundation

struct AppVersionInfo: Equatable, Sendable {
    let version: String
    let build: String

    init(infoDictionary: [String: Any]?) {
        version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "Development"
        build = infoDictionary?["CFBundleVersion"] as? String ?? "Development"
    }

    static var current: AppVersionInfo {
        AppVersionInfo(infoDictionary: Bundle.main.infoDictionary)
    }
}
