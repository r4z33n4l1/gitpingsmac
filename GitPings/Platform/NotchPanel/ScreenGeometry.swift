import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#endif

/// Injectable top-of-screen metrics so geometry can be unit-tested without NSScreen hardware.
public struct ScreenTopMetrics: Equatable, Sendable {
    public var screenID: String
    public var frame: CGRect
    public var visibleFrame: CGRect
    /// Mirrors `NSScreen.safeAreaInsets` top/left/bottom/right in points.
    public var safeAreaInsetsTop: CGFloat
    public var safeAreaInsetsLeft: CGFloat
    public var safeAreaInsetsBottom: CGFloat
    public var safeAreaInsetsRight: CGFloat
    /// Mirrors public `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`.
    public var auxiliaryTopLeftArea: CGRect?
    public var auxiliaryTopRightArea: CGRect?

    public init(
        screenID: String = "injected",
        frame: CGRect,
        visibleFrame: CGRect,
        safeAreaInsetsTop: CGFloat = 0,
        safeAreaInsetsLeft: CGFloat = 0,
        safeAreaInsetsBottom: CGFloat = 0,
        safeAreaInsetsRight: CGFloat = 0,
        auxiliaryTopLeftArea: CGRect? = nil,
        auxiliaryTopRightArea: CGRect? = nil
    ) {
        self.screenID = screenID
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaInsetsTop = safeAreaInsetsTop
        self.safeAreaInsetsLeft = safeAreaInsetsLeft
        self.safeAreaInsetsBottom = safeAreaInsetsBottom
        self.safeAreaInsetsRight = safeAreaInsetsRight
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
    }
}

public enum NotchPresentationMode: String, Equatable, Sendable {
    case notchAttached
    case fallbackPill
}

public struct NotchPanelLayout: Equatable, Sendable {
    public var mode: NotchPresentationMode
    public var collapsedFrame: CGRect
    public var expandedFrame: CGRect
    /// Region that must remain visually clear of content (camera / housing).
    public var reservedTopCenter: CGRect?

    public init(
        mode: NotchPresentationMode,
        collapsedFrame: CGRect,
        expandedFrame: CGRect,
        reservedTopCenter: CGRect? = nil
    ) {
        self.mode = mode
        self.collapsedFrame = collapsedFrame
        self.expandedFrame = expandedFrame
        self.reservedTopCenter = reservedTopCenter
    }
}

/// Pure geometry helpers using public NSScreen concept names (safe area / auxiliary top areas).
public enum ScreenGeometry {
    public static let defaultCollapsedSize = CGSize(width: 200, height: 28)
    public static let defaultExpandedSize = CGSize(width: 368, height: 78)
    public static let fallbackTopPadding: CGFloat = 8
    public static let notchCollapsedHeight: CGFloat = 2

    public static func hasTopObstruction(_ metrics: ScreenTopMetrics) -> Bool {
        if metrics.safeAreaInsetsTop > 0 {
            return true
        }
        guard
            let left = metrics.auxiliaryTopLeftArea,
            let right = metrics.auxiliaryTopRightArea
        else {
            return false
        }
        return left.maxX < right.minX
    }

    public static func presentationMode(for metrics: ScreenTopMetrics) -> NotchPresentationMode {
        hasTopObstruction(metrics) ? .notchAttached : .fallbackPill
    }

    /// Gap between auxiliary top areas, or a synthetic band from the top safe-area inset.
    public static func reservedTopCenterBand(in metrics: ScreenTopMetrics) -> CGRect? {
        if let left = metrics.auxiliaryTopLeftArea, let right = metrics.auxiliaryTopRightArea,
           left.maxX < right.minX
        {
            let minY = min(left.minY, right.minY)
            let maxY = max(left.maxY, right.maxY)
            return CGRect(
                x: left.maxX,
                y: minY,
                width: right.minX - left.maxX,
                height: max(maxY - minY, metrics.safeAreaInsetsTop)
            )
        }

        guard metrics.safeAreaInsetsTop > 0 else { return nil }
        let bandHeight = metrics.safeAreaInsetsTop
        let bandWidth = min(metrics.frame.width * 0.22, 220)
        return CGRect(
            x: metrics.frame.midX - bandWidth / 2,
            y: metrics.frame.maxY - bandHeight,
            width: bandWidth,
            height: bandHeight
        )
    }

    public static func layout(
        for metrics: ScreenTopMetrics,
        collapsedSize: CGSize = defaultCollapsedSize,
        expandedSize: CGSize = defaultExpandedSize,
        fallbackEnabled: Bool = true
    ) -> NotchPanelLayout? {
        let mode = presentationMode(for: metrics)
        if mode == .fallbackPill, !fallbackEnabled {
            return nil
        }

        switch mode {
        case .notchAttached:
            let reserved = reservedTopCenterBand(in: metrics)
            let centerX = reserved?.midX ?? metrics.frame.midX
            // Expand downward from the bottom of the reserved housing band (NOTCH-10).
            let anchorY = reserved?.minY ?? (metrics.frame.maxY - metrics.safeAreaInsetsTop)
            // Keep the resting panel almost entirely behind the camera housing.
            // The visible two-point seam then grows downward with the content,
            // producing the supported illusion that the notch itself expands.
            let restingWidth = min(
                expandedSize.width,
                max(collapsedSize.width, reserved?.width ?? collapsedSize.width)
            )
            let collapsed = CGRect(
                x: centerX - restingWidth / 2,
                y: anchorY - notchCollapsedHeight,
                width: restingWidth,
                height: notchCollapsedHeight
            )
            let expanded = CGRect(
                x: centerX - expandedSize.width / 2,
                y: anchorY - expandedSize.height,
                width: expandedSize.width,
                height: expandedSize.height
            )
            return NotchPanelLayout(
                mode: .notchAttached,
                collapsedFrame: collapsed,
                expandedFrame: expanded,
                reservedTopCenter: reserved
            )

        case .fallbackPill:
            let top = metrics.visibleFrame.maxY - fallbackTopPadding
            let collapsed = CGRect(
                x: metrics.frame.midX - collapsedSize.width / 2,
                y: top - collapsedSize.height,
                width: collapsedSize.width,
                height: collapsedSize.height
            )
            let expanded = CGRect(
                x: metrics.frame.midX - expandedSize.width / 2,
                y: top - expandedSize.height,
                width: expandedSize.width,
                height: expandedSize.height
            )
            return NotchPanelLayout(
                mode: .fallbackPill,
                collapsedFrame: collapsed,
                expandedFrame: expanded,
                reservedTopCenter: nil
            )
        }
    }

    #if canImport(AppKit)
    @MainActor
    public static func metrics(from screen: NSScreen) -> ScreenTopMetrics {
        let insets = screen.safeAreaInsets
        return ScreenTopMetrics(
            screenID: String(describing: ObjectIdentifier(screen)),
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaInsetsTop: insets.top,
            safeAreaInsetsLeft: insets.left,
            safeAreaInsetsBottom: insets.bottom,
            safeAreaInsetsRight: insets.right,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea
        )
    }
    #endif
}
