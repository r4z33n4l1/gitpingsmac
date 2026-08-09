import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pinned pull requests")
                .font(.headline)

            if model.pinnedPullRequests.isEmpty {
                Text("No pins yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.pinnedPullRequests) { pr in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(pr.repositoryNameWithOwner) #\(pr.number)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(pr.title)
                                .lineLimit(1)
                            Text("CI \(pr.ciState.rawValue) · Merge \(pr.mergeState.rawValue)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(pr.repositoryNameWithOwner) pull request \(pr.number), \(pr.title), CI \(pr.ciState.rawValue), merge \(pr.mergeState.rawValue)"
                    )
                }
            }

            Divider()

            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh") {}
                    .disabled(true)
                Button("Open Dashboard") {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
    }
}

struct MenuBarStatusLabel: View {
    let severity: MenuBarSeverity

    var body: some View {
        Image(systemName: symbolName)
            .accessibilityLabel("GitPings status \(severity.rawValue)")
    }

    private var symbolName: String {
        switch severity {
        case .attention: "exclamationmark.triangle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .healthy: "checkmark.circle"
        case .neutral: "dot.radiowaves.up.forward"
        }
    }
}
