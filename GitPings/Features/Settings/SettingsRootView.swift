import SwiftUI

struct SettingsRootView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
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

            Form {
                Section("PR Filters") {
                    Toggle("All open PRs", isOn: $model.filters.includeAllOpen)
                    Toggle("Authored by me", isOn: $model.filters.includeAuthoredByMe)
                    Toggle("Assigned to me", isOn: $model.filters.includeAssignedToMe)
                    Toggle("Review requested from me", isOn: $model.filters.includeReviewRequestedFromMe)
                }
            }
            .tabItem { Label("PR Filters", systemImage: "line.3.horizontal.decrease.circle") }

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
        .frame(width: 520, height: 360)
    }
}
