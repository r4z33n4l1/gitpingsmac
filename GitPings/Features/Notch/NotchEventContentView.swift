import SwiftUI

/// Compact notch/fallback event content. AppKit owns the panel; SwiftUI owns rendering (ADR-001).
public struct NotchEventContentView: View {
    public var events: [TransitionEvent]
    public var overflowCount: Int
    public var mode: NotchPresentationMode
    public var reduceMotion: Bool
    public var onHover: (Bool) -> Void
    public var onClick: (TransitionEvent) -> Void

    public init(
        events: [TransitionEvent],
        overflowCount: Int = 0,
        mode: NotchPresentationMode,
        reduceMotion: Bool = false,
        onHover: @escaping (Bool) -> Void = { _ in },
        onClick: @escaping (TransitionEvent) -> Void = { _ in }
    ) {
        self.events = events
        self.overflowCount = overflowCount
        self.mode = mode
        self.reduceMotion = reduceMotion
        self.onHover = onHover
        self.onClick = onClick
    }

    public var body: some View {
        Group {
            if let primary = events.first {
                primaryRow(primary)
            } else {
                EmptyView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(capsuleBackground)
        .onHover(perform: onHover)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
    }

    private func primaryRow(_ event: TransitionEvent) -> some View {
        Button {
            onClick(event)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: NotchEventPresentation.symbolName(for: event))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NotchEventPresentation.tint(for: event))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(NotchEventPresentation.compactIdentityLine(for: event))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if !queueSummary.isEmpty {
                            Text(queueSummary)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.08), in: Capsule())
                        }
                    }
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(NotchEventPresentation.transitionLine(for: event))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchEventPresentation.tint(for: event))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var queueSummary: String {
        let visibleExtras = max(0, events.count - 1)
        let remaining = visibleExtras + overflowCount
        if remaining <= 0 { return "" }
        if overflowCount > 0 {
            return "+\(remaining) more"
        }
        return "\(events.count) queued"
    }

    private var accessibilitySummary: String {
        guard let primary = events.first else { return "GitPings notification" }
        var parts = [
            NotchEventPresentation.identityLine(for: primary),
            NotchEventPresentation.transitionLine(for: primary),
        ]
        if !queueSummary.isEmpty {
            parts.append(queueSummary)
        }
        parts.append(mode == .notchAttached ? "notch notification" : "menu bar fallback notification")
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var capsuleBackground: some View {
        let shape = RoundedRectangle(cornerRadius: mode == .notchAttached ? 24 : 20, style: .continuous)
        if mode == .notchAttached {
            shape
                .fill(.black)
                .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
        }
    }
}

/// Copy and symbol mapping for compact notch events (ADR-004 examples).
public enum NotchEventPresentation {
    public static func identityLine(for event: TransitionEvent) -> String {
        "\(event.repositoryNameWithOwner) #\(event.number)"
    }

    public static func transitionLine(for event: TransitionEvent) -> String {
        switch event.kind {
        case .ciChanged:
            return ciPhrase(event.newValue)
        case .mergeChanged:
            return mergePhrase(event.newValue)
        case .closedOrMerged:
            if event.newValue == PullRequestLifecycleState.merged.rawValue {
                return "Merged"
            }
            if event.newValue == PullRequestLifecycleState.closed.rawValue {
                return "Closed"
            }
            return "Lifecycle \(event.newValue)"
        }
    }

    public static func compactIdentityLine(for event: TransitionEvent) -> String {
        let repository = event.repositoryNameWithOwner.split(separator: "/").last
            .map(String.init) ?? event.repositoryNameWithOwner
        return "\(repository) · #\(event.number)"
    }

    public static func tint(for event: TransitionEvent) -> Color {
        switch event.kind {
        case .ciChanged:
            switch event.newValue {
            case CIState.passing.rawValue: return .green
            case CIState.failing.rawValue: return .red
            case CIState.pending.rawValue: return .orange
            default: return .secondary
            }
        case .mergeChanged:
            switch event.newValue {
            case MergeState.mergeable.rawValue: return .green
            case MergeState.conflicting.rawValue: return .red
            case MergeState.blocked.rawValue: return .orange
            default: return .secondary
            }
        case .closedOrMerged:
            return event.newValue == PullRequestLifecycleState.merged.rawValue ? .purple : .secondary
        }
    }

    public static func symbolName(for event: TransitionEvent) -> String {
        switch event.kind {
        case .ciChanged:
            switch event.newValue {
            case CIState.passing.rawValue: return "checkmark.circle.fill"
            case CIState.failing.rawValue: return "xmark.octagon.fill"
            case CIState.pending.rawValue: return "arrow.triangle.2.circlepath"
            default: return "questionmark.circle"
            }
        case .mergeChanged:
            switch event.newValue {
            case MergeState.mergeable.rawValue: return "arrow.triangle.merge"
            case MergeState.conflicting.rawValue: return "exclamationmark.triangle.fill"
            case MergeState.blocked.rawValue: return "slash.circle"
            default: return "arrow.triangle.branch"
            }
        case .closedOrMerged:
            return event.newValue == PullRequestLifecycleState.merged.rawValue
                ? "checkmark.seal.fill"
                : "envelope.badge.trash"
        }
    }

    private static func ciPhrase(_ value: String) -> String {
        switch value {
        case CIState.passing.rawValue: return "CI passed"
        case CIState.failing.rawValue: return "CI failed"
        case CIState.pending.rawValue: return "CI pending"
        case CIState.noChecks.rawValue: return "No CI checks"
        default: return "CI \(value)"
        }
    }

    private static func mergePhrase(_ value: String) -> String {
        switch value {
        case MergeState.mergeable.rawValue: return "Mergeable"
        case MergeState.conflicting.rawValue: return "Merge conflict"
        case MergeState.blocked.rawValue: return "Merge blocked"
        case MergeState.checking.rawValue: return "Checking merge"
        default: return "Merge \(value)"
        }
    }
}
