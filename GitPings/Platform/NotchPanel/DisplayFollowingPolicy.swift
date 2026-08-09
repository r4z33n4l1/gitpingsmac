import Foundation

/// Candidate display-following rules for the notch/fallback panel (ADR-004).
/// Final selection is **blocked** until notched MacBook + external-display matrix evidence.
public enum DisplayFollowingPolicy: String, Sendable, CaseIterable {
    /// Prefer the screen associated with the last GitPings menu-bar / UI interaction.
    case interactionScreen
    /// Prefer the screen hosting the frontmost app’s key window.
    case keyWindowScreen
    /// Prefer a built-in notched screen when `ScreenGeometry.hasTopObstruction` is true.
    case preferNotchedScreen
    /// Prefer the screen currently under the mouse pointer.
    case pointerScreen

    /// Interim recommendation until Gate 0 hardware evidence: interaction → key window → notched → main.
    public static let interimRecommendation: [DisplayFollowingPolicy] = [
        .interactionScreen,
        .keyWindowScreen,
        .preferNotchedScreen,
    ]
}
