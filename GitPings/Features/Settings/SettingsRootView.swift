import AppKit
import SwiftUI

struct SettingsRootView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            accountTab
            filtersTab
            notificationsTab
            refreshTab
            appearanceTab
        }
        .frame(width: 540, height: 430)
        .padding(.top, 8)
    }

    private var accountTab: some View {
        Form {
            Section("GitHub account") {
                switch model.authState {
                case .signedOut:
                    LabeledContent("Status", value: "Signed out")
                    Button("Sign in with GitHub") { model.beginSignIn() }
                        .buttonStyle(.borderedProminent)
                case .deviceFlowPending(let userCode, let url):
                    LabeledContent("Code") {
                        Text(userCode).font(.system(.body, design: .monospaced, weight: .bold))
                            .textSelection(.enabled)
                    }
                    Link("Open GitHub Device Login", destination: url)
                    Button("Cancel", role: .cancel) { model.cancelSignIn() }
                case .signedIn(let account):
                    LabeledContent("Signed in as", value: "@\(account.login)")
                    Button("Sign Out", role: .destructive) { model.signOut() }
                case .needsReauthorization(let reason):
                    Text(reason).foregroundStyle(.red)
                    Button("Sign in again") { model.beginSignIn() }
                }
            }

            Section("OAuth configuration") {
                if model.hasBundledOAuthConfiguration {
                    LabeledContent("GitHub App", value: "GitNotary")
                    Link(
                        "Install or update repository access",
                        destination: GitNotaryConfiguration.installationURL
                    )
                } else {
                    TextField("GitHub OAuth client ID", text: $model.oauthClientID)
                        .textFieldStyle(.roundedBorder)
                }
                Text("GitPings uses GitHub device flow directly. No client secret, callback server, hosted database, or GitHub CLI token is required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link(
                    "Setup guide",
                    destination: URL(string: "https://github.com/r4z33n4l1/gitpingsmac/blob/main/docs/DISTRIBUTION.md#recipient-setup")!
                )
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Account", systemImage: "person.crop.circle") }
    }

    private var filtersTab: some View {
        Form {
            Section("Which open PRs should appear?") {
                Toggle("All open PRs", isOn: $model.filters.includeAllOpen)
                Toggle("Authored by me", isOn: $model.filters.includeAuthoredByMe)
                    .disabled(model.filters.includeAllOpen)
                Toggle("Assigned to me", isOn: $model.filters.includeAssignedToMe)
                    .disabled(model.filters.includeAllOpen)
                Toggle("Review requested from me", isOn: $model.filters.includeReviewRequestedFromMe)
                    .disabled(model.filters.includeAllOpen)
            }
            Text("Enabled filters use OR semantics. Changes establish a fresh baseline so old state is never reported as a new alert.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .onChange(of: model.filters) { _, _ in model.filtersChanged() }
        .tabItem { Label("PR Filters", systemImage: "line.3.horizontal.decrease.circle") }
    }

    private var notificationsTab: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable status-change notifications", isOn: $model.notificationsEnabled)
                Toggle(
                    "New PRs authored by me",
                    isOn: $model.newAuthoredPullRequestNotificationsEnabled
                )
                .disabled(!model.notificationsEnabled)
                Toggle("Show around the notch", isOn: $model.notchNotificationsEnabled)
                    .disabled(!model.notificationsEnabled)
                Toggle("System notifications", isOn: $model.systemNotificationsEnabled)
                    .disabled(!model.notificationsEnabled)
                Toggle("Play a sound", isOn: $model.soundEnabled)
                    .disabled(!model.notificationsEnabled)
            }
            Text("New-PR alerts watch authored pull requests across selected repositories, even when the dashboard's Authored by me filter is off. Existing PRs establish a silent baseline.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Section("Test") {
                Button("Test Notch Notification") { model.sendTestNotchNotification() }
                Text("Previews the notch directly without changing notification preferences, PR history, or menu-bar status.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Notifications", systemImage: "bell") }
    }

    private var refreshTab: some View {
        Form {
            Section("Polling") {
                LabeledContent("Interval", value: "Every 60 seconds")
                LabeledContent("Last successful refresh") {
                    Text(model.lastSuccessfulRefreshAt?.formatted() ?? "Never")
                }
                Button("Refresh Now") { model.refresh() }
                    .disabled(model.isRefreshing || model.signedInAccount == nil)
            }
            Text("GitPings also refreshes when repository selection or PR filters change.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .tabItem { Label("Refresh", systemImage: "arrow.clockwise") }
    }

    private var appearanceTab: some View {
        Form {
            Section("Notch behavior") {
                LabeledContent("Display mode", value: "Notch-attached with fallback pill")
                LabeledContent("Reduce Motion") {
                    Text(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? "On" : "Off")
                }
            }
            Text("On Macs without a camera housing, the same notification appears as a compact centered pill below the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Section("About GitPings") {
                LabeledContent("Version", value: AppVersionInfo.current.version)
                LabeledContent("Build", value: AppVersionInfo.current.build)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Appearance", systemImage: "paintbrush") }
    }
}
