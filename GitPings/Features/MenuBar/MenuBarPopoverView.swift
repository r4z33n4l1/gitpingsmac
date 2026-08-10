import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var selectedSection: MenuBarSection = .pinned

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pull Requests")
                    .font(.headline)
                Spacer()
                if model.isRefreshing {
                    ProgressView().controlSize(.small)
                }
            }

            Picker("Pull request list", selection: $selectedSection) {
                ForEach(MenuBarSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if displayedPullRequests.isEmpty {
                Text(selectedSection.emptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(displayedPullRequests) { pr in
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
                                Text(MenuBarPRStatusFormatter.text(for: pr))
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
        .accessibilityLabel("GitPings pull requests")
    }

    private var displayedPullRequests: [PullRequestSummary] {
        switch selectedSection {
        case .pinned:
            model.pinnedPullRequests
        case .recent:
            MenuBarPRCollection.recent(from: model.pullRequests)
        }
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

}

enum MenuBarSection: String, CaseIterable, Identifiable {
    case pinned
    case recent

    var id: Self { self }

    var title: String {
        switch self {
        case .pinned: "Pinned"
        case .recent: "Recent"
        }
    }

    var emptyMessage: String {
        switch self {
        case .pinned: "No pins yet"
        case .recent: "No recent open PRs"
        }
    }
}

enum MenuBarPRCollection {
    static let recentLimit = 5

    static func recent(from pullRequests: [PullRequestSummary]) -> [PullRequestSummary] {
        Array(
            pullRequests
                .filter { $0.lifecycleState == .open }
                .sorted { lhs, rhs in
                    if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                    if lhs.repositoryNameWithOwner != rhs.repositoryNameWithOwner {
                        return lhs.repositoryNameWithOwner < rhs.repositoryNameWithOwner
                    }
                    return lhs.number > rhs.number
                }
                .prefix(recentLimit)
        )
    }
}

enum MenuBarPRStatusFormatter {
    static func text(for pr: PullRequestSummary) -> String {
        if pr.lifecycleState == .merged { return "Merged" }
        if pr.lifecycleState == .closed { return "Closed" }
        return "\(ciText(pr.ciState)) · \(mergeText(pr.mergeState))"
    }

    private static func ciText(_ state: CIState) -> String {
        switch state {
        case .passing: "CI passing"
        case .pending: "CI pending"
        case .failing: "CI failing"
        case .noChecks: "No CI checks"
        case .unknown: "CI unknown"
        }
    }

    private static func mergeText(_ state: MergeState) -> String {
        switch state {
        case .mergeable: "Mergeable"
        case .blocked: "Merge blocked"
        case .conflicting: "Merge conflicts"
        case .checking: "Checking mergeability"
        case .unknown: "Merge status unknown"
        }
    }
}

struct MenuBarStatusLabel: View {
    let severity: MenuBarSeverity

    var body: some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel("GitPings")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Opens the pull request menu")
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
