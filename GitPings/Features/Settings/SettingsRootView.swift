import AppKit
import SwiftUI

struct SettingsRootView: View {
    @Bindable var model: AppModel

    // Local spike preferences — not yet persisted via PreferencesStore / AppModel (integrator wiring).
    @State private var notificationsMasterEnabled = true
    @State private var notifyCI = true
    @State private var notifyMergeability = true
    @State private var notifyClosedOrMerged = true
    @State private var channelNotch = true
    @State private var channelSound = false
    @State private var channelSystem = false
    @State private var fallbackPillEnabled = true
    @State private var suppressFullScreen = true
    @State private var launchAtLogin = false
    @State private var systemPermissionNote = "Permission is requested only when System Notifications is turned on."

    var body: some View {
        TabView {
            accountTab
            filtersTab
            notificationsTab
            refreshTab
            appearanceTab
            generalTab
        }
        .frame(width: 520, height: 420)
    }

    private var accountTab: some View {
        Form {
            Section("Account") {
                switch model.authState {
                case .signedOut:
                    Text("Signed out")
                case .deviceFlowPending(let userCode, _):
                    Text("Device flow pending")
                    Text("User code: \(userCode)")
                case .signedIn(let account):
                    Text("Signed in as \(account.login)")
                case .needsReauthorization(let reason):
                    Text("Reauthorize required: \(reason)")
                }
            }
        }
        .tabItem { Label("Account", systemImage: "person.crop.circle") }
    }

    private var filtersTab: some View {
        Form {
            Section("PR Filters") {
                Toggle("All open PRs", isOn: $model.filters.includeAllOpen)
                Toggle("Authored by me", isOn: $model.filters.includeAuthoredByMe)
                Toggle("Assigned to me", isOn: $model.filters.includeAssignedToMe)
                Toggle("Review requested from me", isOn: $model.filters.includeReviewRequestedFromMe)
            }
        }
        .tabItem { Label("PR Filters", systemImage: "line.3.horizontal.decrease.circle") }
    }

    private var notificationsTab: some View {
        Form {
            Section("Master") {
                Toggle("Enable notifications", isOn: $notificationsMasterEnabled)
            }
            Section("Events") {
                Toggle("CI transitions", isOn: $notifyCI)
                    .disabled(!notificationsMasterEnabled)
                Toggle("Mergeability transitions", isOn: $notifyMergeability)
                    .disabled(!notificationsMasterEnabled)
                Toggle("Closed / merged", isOn: $notifyClosedOrMerged)
                    .disabled(!notificationsMasterEnabled)
            }
            Section("Delivery channels") {
                Toggle("Notch UI", isOn: $channelNotch)
                    .disabled(!notificationsMasterEnabled)
                Toggle("Sound", isOn: $channelSound)
                    .disabled(!notificationsMasterEnabled)
                Toggle("System Notifications", isOn: $channelSystem)
                    .disabled(!notificationsMasterEnabled)
                    .onChange(of: channelSystem) { _, enabled in
                        if enabled {
                            systemPermissionNote =
                                "In-context permission request will run via SystemNotificationPresenter (NOTIFY-6)."
                        } else {
                            systemPermissionNote =
                                "Permission is requested only when System Notifications is turned on."
                        }
                    }
                Text(systemPermissionNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Test") {
                Button("Send test notification…") {}
                    .disabled(true)
                Text("Wired after NotificationRouting lands (NOTIFY-9).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tabItem { Label("Notifications", systemImage: "bell") }
    }

    private var refreshTab: some View {
        Form {
            Section("Refresh") {
                LabeledContent("Target interval", value: "60 seconds")
                LabeledContent(
                    "Last success",
                    value: model.lastSuccessfulRefreshAt?.formatted() ?? "Never"
                )
            }
        }
        .tabItem { Label("Refresh", systemImage: "arrow.clockwise") }
    }

    private var appearanceTab: some View {
        Form {
            Section("Notch") {
                Toggle("Notch notifications", isOn: $channelNotch)
                Toggle("Fallback pill on notchless displays", isOn: $fallbackPillEnabled)
                Toggle("Suppress over full-screen apps", isOn: $suppressFullScreen)
            }
            Section("Accessibility") {
                LabeledContent("Reduce Motion") {
                    Text(reduceMotionStatus)
                        .foregroundStyle(.secondary)
                }
                Text("When Reduce Motion is on, the panel fades instead of expanding.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tabItem { Label("Appearance", systemImage: "paintbrush") }
    }

    private var generalTab: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                Text("Managed with SMAppService via LaunchAtLoginManager (SETTINGS-3). Quiet launch without dashboard is LIFECYCLE-3.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tabItem { Label("General", systemImage: "gearshape") }
    }

    /// SETTINGS-5: mirror system Reduce Motion; animation path reads the live flag at present time.
    private var reduceMotionStatus: String {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? "On" : "Off"
    }
}
