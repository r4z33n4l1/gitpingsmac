import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
import SwiftUI
#endif

/// Callback surface from AppKit panel → app/router. Intentionally tiny (ADR-001).
public struct NotchPanelCallbacks: Sendable {
    public var onEventClicked: (@Sendable (TransitionEvent) -> Void)?
    public var onHoverChanged: (@Sendable (Bool) -> Void)?
    public var onDismissalCompleted: (@Sendable () -> Void)?
    public var onFocusTelemetry: (@Sendable (NotchPanelFocusTelemetry) -> Void)?

    public init(
        onEventClicked: (@Sendable (TransitionEvent) -> Void)? = nil,
        onHoverChanged: (@Sendable (Bool) -> Void)? = nil,
        onDismissalCompleted: (@Sendable () -> Void)? = nil,
        onFocusTelemetry: (@Sendable (NotchPanelFocusTelemetry) -> Void)? = nil
    ) {
        self.onEventClicked = onEventClicked
        self.onHoverChanged = onHoverChanged
        self.onDismissalCompleted = onDismissalCompleted
        self.onFocusTelemetry = onFocusTelemetry
    }
}

public struct NotchPanelFocusTelemetry: Equatable, Sendable {
    public var screenID: String
    public var mode: NotchPresentationMode
    public var panelFrame: CGRect
    public var appWasActiveBeforePresent: Bool
    public var appIsActiveAfterPresent: Bool
    public var panelIsKeyWindow: Bool

    public init(
        screenID: String,
        mode: NotchPresentationMode,
        panelFrame: CGRect,
        appWasActiveBeforePresent: Bool,
        appIsActiveAfterPresent: Bool,
        panelIsKeyWindow: Bool
    ) {
        self.screenID = screenID
        self.mode = mode
        self.panelFrame = panelFrame
        self.appWasActiveBeforePresent = appWasActiveBeforePresent
        self.appIsActiveAfterPresent = appIsActiveAfterPresent
        self.panelIsKeyWindow = panelIsKeyWindow
    }
}

public struct NotchPanelPresentationOptions: Equatable, Sendable {
    public var fallbackEnabled: Bool
    public var suppressWhenFullScreen: Bool
    public var reduceMotion: Bool
    public var holdDuration: TimeInterval

    public init(
        fallbackEnabled: Bool = true,
        suppressWhenFullScreen: Bool = true,
        reduceMotion: Bool = false,
        holdDuration: TimeInterval = 4
    ) {
        self.fallbackEnabled = fallbackEnabled
        self.suppressWhenFullScreen = suppressWhenFullScreen
        self.reduceMotion = reduceMotion
        self.holdDuration = holdDuration
    }
}

/// Narrow AppKit bridge for the transient notch/fallback panel (ADR-001 / ADR-004).
/// SwiftUI owns content; this type owns only panel lifecycle, frame, and hover/dismiss callbacks.
@MainActor
public final class NotchPanelCoordinator: NotchPresenting {
    private var callbacks: NotchPanelCallbacks
    private var options: NotchPanelPresentationOptions
    private var metricsProvider: @MainActor () -> ScreenTopMetrics?
    private var isScreenLocked: Bool = false
    private var isTargetFullScreen: Bool = false
    private var currentEvents: [TransitionEvent] = []

    #if canImport(AppKit)
    private var panel: NSPanel?
    private var hosting: NSHostingView<NotchEventContentView>?
    private var screenParameterObserver: NSObjectProtocol?
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?
    #endif

    public init(
        options: NotchPanelPresentationOptions = NotchPanelPresentationOptions(),
        callbacks: NotchPanelCallbacks = NotchPanelCallbacks(),
        metricsProvider: (@MainActor () -> ScreenTopMetrics?)? = nil
    ) {
        self.options = options
        self.callbacks = callbacks
        #if canImport(AppKit)
        self.metricsProvider = metricsProvider ?? {
            NSScreen.main.map { ScreenGeometry.metrics(from: $0) }
        }
        #else
        self.metricsProvider = metricsProvider ?? { nil }
        #endif
        installSuppressionObservers()
    }

    deinit {
        #if canImport(AppKit)
        if let screenParameterObserver {
            NotificationCenter.default.removeObserver(screenParameterObserver)
        }
        if let lockObserver {
            DistributedNotificationCenter.default().removeObserver(lockObserver)
        }
        if let unlockObserver {
            DistributedNotificationCenter.default().removeObserver(unlockObserver)
        }
        #endif
    }

    public func updateOptions(_ options: NotchPanelPresentationOptions) {
        self.options = options
    }

    public func updateCallbacks(_ callbacks: NotchPanelCallbacks) {
        self.callbacks = callbacks
    }

    /// Test / spike seam for lock and full-screen suppression (NOTCH-11).
    public func setSuppressionStateForTesting(screenLocked: Bool, fullScreen: Bool) {
        isScreenLocked = screenLocked
        isTargetFullScreen = fullScreen
    }

    public func present(events: [TransitionEvent]) async {
        guard !events.isEmpty else { return }
        guard !isScreenLocked else { return }
        if options.suppressWhenFullScreen, isTargetFullScreen { return }

        currentEvents = Array(events.prefix(3))
        let overflow = max(0, events.count - currentEvents.count)

        guard let metrics = metricsProvider() else { return }
        guard let layout = ScreenGeometry.layout(
            for: metrics,
            fallbackEnabled: options.fallbackEnabled
        ) else {
            return
        }

        #if canImport(AppKit)
        let appWasActive = NSApp.isActive
        ensurePanel()
        guard let panel, let hosting else { return }

        let content = NotchEventContentView(
            events: currentEvents,
            overflowCount: overflow,
            mode: layout.mode,
            reduceMotion: options.reduceMotion,
            onHover: { [weak self] hovering in
                self?.callbacks.onHoverChanged?(hovering)
            },
            onClick: { [weak self] event in
                self?.callbacks.onEventClicked?(event)
            }
        )
        hosting.rootView = content
        panel.setFrame(layout.expandedFrame, display: true)
        // Nonactivating show — do not steal keyboard focus (NOTCH-4).
        panel.orderFrontRegardless()
        panel.resignKey()

        let telemetry = NotchPanelFocusTelemetry(
            screenID: metrics.screenID,
            mode: layout.mode,
            panelFrame: panel.frame,
            appWasActiveBeforePresent: appWasActive,
            appIsActiveAfterPresent: NSApp.isActive,
            panelIsKeyWindow: panel.isKeyWindow
        )
        callbacks.onFocusTelemetry?(telemetry)
        #else
        _ = layout
        _ = overflow
        #endif
    }

    public func dismiss() async {
        #if canImport(AppKit)
        panel?.orderOut(nil)
        #endif
        currentEvents = []
        callbacks.onDismissalCompleted?()
    }

    private func installSuppressionObservers() {
        #if canImport(AppKit)
        screenParameterObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.recomputeFrameIfVisible()
            }
        }

        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = true
                await self?.dismiss()
            }
        }

        unlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = false
            }
        }
        #endif
    }

    #if canImport(AppKit)
    private func ensurePanel() {
        if panel != nil { return }

        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.animationBehavior = .utilityWindow

        let hosting = NSHostingView(
            rootView: NotchEventContentView(
                events: [],
                overflowCount: 0,
                mode: .fallbackPill,
                reduceMotion: options.reduceMotion,
                onHover: { _ in },
                onClick: { _ in }
            )
        )
        panel.contentView = hosting

        self.panel = panel
        self.hosting = hosting
    }

    private func recomputeFrameIfVisible() async {
        guard let panel, panel.isVisible, !currentEvents.isEmpty else { return }
        await present(events: currentEvents)
    }
    #endif
}
