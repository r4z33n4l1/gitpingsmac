import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pinned PRs")
                    .font(.headline)
                Spacer()
                if model.isRefreshing {
                    ProgressView().controlSize(.small)
                }
            }

            if model.pinnedPullRequests.isEmpty {
                Text("No pins yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.pinnedPullRequests) { pr in
                    Button {
                        model.openPullRequest(id: pr.id)
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: rowSymbol(for: pr))
                                .foregroundStyle(rowColor(for: pr))
                                .font(.title3)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("#\(pr.number) · \(pr.title)")
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text(pr.repositoryNameWithOwner)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(statusText(for: pr))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(rowColor(for: pr))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 3)
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
                Button("Refresh") { model.refresh() }
                    .disabled(model.isRefreshing || model.signedInAccount == nil)
                Button("Open Dashboard") {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }
                SettingsLink {
                    Text("Settings")
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
        .task { model.start() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("GitPings pinned pull requests")
    }

    private func rowSymbol(for pr: PullRequestSummary) -> String {
        if pr.lifecycleState == .merged { return "checkmark.seal.fill" }
        if pr.lifecycleState == .closed { return "xmark.circle" }
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
        if pr.lifecycleState == .merged { return .purple }
        if pr.lifecycleState == .closed { return .secondary }
        if pr.ciState == .failing || pr.mergeState == .conflicting { return .red }
        if pr.ciState == .passing && pr.mergeState == .mergeable { return .green }
        return .secondary
    }

    private func statusText(for pr: PullRequestSummary) -> String {
        if pr.lifecycleState == .merged { return "Merged" }
        if pr.lifecycleState == .closed { return "Closed" }
        if pr.ciState == .failing { return "CI failing · needs attention" }
        if pr.mergeState == .conflicting { return "Merge conflicts · needs attention" }
        if pr.ciState == .passing && pr.mergeState == .mergeable { return "CI passing · ready to merge" }
        if pr.ciState == .pending || pr.mergeState == .checking { return "Checks in progress" }
        if pr.mergeState == .blocked { return "Merge blocked" }
        if pr.ciState == .noChecks { return "No CI checks · \(pr.mergeState.rawValue)" }
        return "CI \(pr.ciState.rawValue) · merge \(pr.mergeState.rawValue)"
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
