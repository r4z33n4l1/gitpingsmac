import Foundation

/// Channel and event toggles for `NotificationRouter` (NOTIFY-1..5).
public struct NotificationPreferences: Hashable, Sendable, Codable {
    public var masterEnabled: Bool
    public var ciEnabled: Bool
    public var mergeEnabled: Bool
    public var closedOrMergedEnabled: Bool
    public var notchEnabled: Bool
    public var systemEnabled: Bool
    public var soundEnabled: Bool

    public init(
        masterEnabled: Bool = true,
        ciEnabled: Bool = true,
        mergeEnabled: Bool = true,
        closedOrMergedEnabled: Bool = true,
        notchEnabled: Bool = true,
        systemEnabled: Bool = false,
        soundEnabled: Bool = false
    ) {
        self.masterEnabled = masterEnabled
        self.ciEnabled = ciEnabled
        self.mergeEnabled = mergeEnabled
        self.closedOrMergedEnabled = closedOrMergedEnabled
        self.notchEnabled = notchEnabled
        self.systemEnabled = systemEnabled
        self.soundEnabled = soundEnabled
    }

    public static let mvpTesting = NotificationPreferences()

    public init(settings: AppSettingsDraft) {
        masterEnabled = settings.notificationsMasterEnabled
        ciEnabled = settings.notifyCI
        mergeEnabled = settings.notifyMerge
        closedOrMergedEnabled = settings.notifyClosedOrMerged
        notchEnabled = settings.channelNotch
        systemEnabled = settings.channelSystem
        soundEnabled = settings.channelSound
    }

    public func allows(kind: TransitionEventKind) -> Bool {
        guard masterEnabled else { return false }
        switch kind {
        case .ciChanged: return ciEnabled
        case .mergeChanged: return mergeEnabled
        case .closedOrMerged: return closedOrMergedEnabled
        }
    }

    public func allows(channel: NotificationChannel) -> Bool {
        guard masterEnabled else { return false }
        switch channel {
        case .notch: return notchEnabled
        case .system: return systemEnabled
        case .sound: return soundEnabled
        }
    }
}

/// Delivery intent produced by the router (presentation layers consume this).
public struct NotificationDelivery: Hashable, Sendable {
    public var channel: NotificationChannel
    public var events: [TransitionEvent]
    public var isTest: Bool

    public init(channel: NotificationChannel, events: [TransitionEvent], isTest: Bool) {
        self.channel = channel
        self.events = events
        self.isTest = isTest
    }
}
