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
                    Button {
                        NSWorkspace.shared.open(pr.url)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: rowSymbol(for: pr))
                                .foregroundStyle(rowColor(for: pr))
                                .accessibilityHidden(true)

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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(pr.repositoryNameWithOwner) pull request \(pr.number), \(pr.title), CI \(pr.ciState.rawValue), merge \(pr.mergeState.rawValue)"
                    )
                    .accessibilityHint("Opens the pull request on GitHub")
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("GitPings pinned pull requests")
    }

    private func rowSymbol(for pr: PullRequestSummary) -> String {
        if pr.ciState == .failing || pr.mergeState == .conflicting {
            return "exclamationmark.triangle.fill"
        }
        if pr.ciState == .pending || pr.ciState == .unknown
            || pr.mergeState == .checking || pr.mergeState == .unknown || pr.mergeState == .blocked
        {
            return "arrow.triangle.2.circlepath"
        }
        if pr.ciState == .passing && pr.mergeState == .mergeable {
            return "checkmark.circle.fill"
        }
        return "circle"
    }

    private func rowColor(for pr: PullRequestSummary) -> Color {
        if pr.ciState == .failing || pr.mergeState == .conflicting { return .red }
        if pr.ciState == .passing && pr.mergeState == .mergeable { return .green }
        return .secondary
    }
}

struct MenuBarStatusLabel: View {
    let severity: MenuBarSeverity

    var body: some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel("GitPings")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Opens the pinned pull request menu")
    }

    private var symbolName: String {
        switch severity {
        case .attention: "exclamationmark.triangle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .healthy: "checkmark.circle"
        case .neutral: "dot.radiowaves.up.forward"
        }
    }

    /// MENUBAR-8: severity is announced in words, not color alone.
    private var accessibilityValue: String {
        switch severity {
        case .attention: "Attention required"
        case .inProgress: "Checks in progress"
        case .healthy: "All pinned pull requests healthy"
        case .neutral: "No pinned pull requests"
        }
    }
}
