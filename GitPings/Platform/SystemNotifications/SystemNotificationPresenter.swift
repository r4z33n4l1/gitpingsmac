import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// Optional Notification Center channel. Authorization is requested in context only (NOTIFY-6).
public actor SystemNotificationPresenter: SystemNotificationPresenting {
    private var authorizationGranted: Bool?
    private let centerProvider: @Sendable () -> any NotificationCenterProxying

    public init(center: (any NotificationCenterProxying)? = nil) {
        if let center {
            self.centerProvider = { center }
        } else {
            self.centerProvider = { SystemUNUserNotificationCenterProxy() }
        }
    }

    public func requestAuthorizationIfNeeded() async -> Bool {
        if let authorizationGranted { return authorizationGranted }
        let granted = await centerProvider().requestAlertAuthorization()
        authorizationGranted = granted
        return granted
    }

    public func present(event: TransitionEvent) async {
        // Permission is not requested at launch; callers should invoke
        // `requestAuthorizationIfNeeded` when the user enables the system channel.
        guard authorizationGranted == true || await requestAuthorizationIfNeeded() else {
            return
        }

        let title = "\(event.repositoryNameWithOwner) #\(event.number)"
        let body = NotchEventPresentation.transitionLine(for: event)
        // NOTIFY-8: repository name, PR number/title, and transition only — no source/diff content.
        let bodyWithTitle: String
        if event.title.isEmpty {
            bodyWithTitle = body
        } else {
            bodyWithTitle = "\(event.title) — \(body)"
        }

        await centerProvider().deliver(
            identifier: event.id.uuidString,
            title: title,
            body: bodyWithTitle,
            userInfo: [
                "pullRequestID": event.pullRequestID.rawValue,
                "number": String(event.number),
            ]
        )
    }

    /// Spike helper: reset cached permission so Settings toggles can re-request in context.
    public func resetAuthorizationCacheForTesting() {
        authorizationGranted = nil
    }
}

/// Thin seam over `UNUserNotificationCenter` for tests and Linux-safe compilation of actor logic.
public protocol NotificationCenterProxying: Sendable {
    func requestAlertAuthorization() async -> Bool
    func deliver(identifier: String, title: String, body: String, userInfo: [String: String]) async
}

#if canImport(UserNotifications)
public struct SystemUNUserNotificationCenterProxy: NotificationCenterProxying {
    public init() {}

    public func requestAlertAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    public func deliver(
        identifier: String,
        title: String,
        body: String,
        userInfo: [String: String]
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
#else
public struct SystemUNUserNotificationCenterProxy: NotificationCenterProxying {
    public init() {}
    public func requestAlertAuthorization() async -> Bool { false }
    public func deliver(
        identifier: String,
        title: String,
        body: String,
        userInfo: [String: String]
    ) async {
        _ = identifier
        _ = title
        _ = body
        _ = userInfo
    }
}
#endif
