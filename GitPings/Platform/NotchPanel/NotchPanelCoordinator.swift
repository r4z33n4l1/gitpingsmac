import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
import QuartzCore
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
        holdDuration: TimeInterval = 6
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
    private var eventQueue = NotchEventQueue()
    private var dismissalTask: Task<Void, Never>?
    private var presentationGeneration = 0
    private var countdownStartedAt: TimeInterval = 0
    private var remainingHoldDuration: TimeInterval = 0

    #if canImport(AppKit)
    private var panel: NSPanel?
    private var hosting: EdgeToEdgeNotchHostingView?
    // Notification tokens are only installed/removed as part of this coordinator's
    // lifecycle. Marking the references unsafe-nonisolated lets Swift 6's
    // nonisolated deinitializer release them without sending the AppKit objects.
    nonisolated(unsafe) private var screenParameterObserver: NSObjectProtocol?
    nonisolated(unsafe) private var lockObserver: NSObjectProtocol?
    nonisolated(unsafe) private var unlockObserver: NSObjectProtocol?
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
            // Apple documents screens[0] as the screen containing the menu bar.
            // NSScreen.main follows keyboard focus and may be a different display,
            // which would incorrectly select the detached fallback layout.
            NSScreen.screens.first.map { ScreenGeometry.metrics(from: $0) }
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

        eventQueue.enqueue(events, excluding: currentEvents)
        guard currentEvents.isEmpty else { return }
        await presentNextQueuedGroup()
    }

    private func presentNextQueuedGroup() async {
        guard let nextEvents = eventQueue.popFirst() else { return }
        currentEvents = nextEvents
        await presentCurrentGroup()
    }

    private func presentCurrentGroup() async {
        guard let metrics = metricsProvider() else {
            currentEvents = []
            await presentNextQueuedGroup()
            return
        }
        guard let layout = ScreenGeometry.layout(
            for: metrics,
            fallbackEnabled: options.fallbackEnabled
        ) else {
            currentEvents = []
            await presentNextQueuedGroup()
            return
        }
        presentationGeneration += 1
        dismissalTask?.cancel()
        remainingHoldDuration = options.holdDuration

        #if canImport(AppKit)
        let appWasActive = NSApp.isActive
        ensurePanel()
        guard let panel, let hosting else { return }
        let onHover = callbacks.onHoverChanged
        let onClick = callbacks.onEventClicked

        let content = NotchEventContentView(
            events: currentEvents,
            overflowCount: eventQueue.count,
            mode: layout.mode,
            notchStemWidth: layout.reservedTopCenter?.width ?? 0,
            notchStemHeight: layout.reservedTopCenter?.height ?? 0,
            presentationID: presentationGeneration,
            reduceMotion: options.reduceMotion,
            onHover: { [weak self] hovering in
                onHover?(hovering)
                self?.handleHover(hovering)
            },
            onClick: { [weak self] event in
                onClick?(event)
                Task { @MainActor in
                    await self?.dismiss()
                }
            }
        )
        hosting.rootView = content
        let wasVisible = panel.isVisible
        panel.hasShadow = layout.mode == .fallbackPill
        // Keep the AppKit shell fixed at its maximum bounds. SwiftUI animates
        // the black surface inside this transparent panel so the top edge never
        // drifts away from the physical camera housing.
        panel.setFrame(layout.expandedFrame, display: true)
        if !wasVisible {
            panel.alphaValue = options.reduceMotion ? 0 : 1
            // Nonactivating show — do not steal keyboard focus (NOTCH-4).
            panel.orderFrontRegardless()
            animatePresentation(of: panel)
        } else {
            panel.alphaValue = 1
        }
        panel.resignKey()
        scheduleDismiss(after: remainingHoldDuration)

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
        #endif
    }

    public func dismiss() async {
        presentationGeneration += 1
        let generation = presentationGeneration
        dismissalTask?.cancel()
        dismissalTask = nil
        #if canImport(AppKit)
        if let panel, panel.isVisible {
            let duration = options.reduceMotion ? 0.14 : 0.24
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.allowsImplicitAnimation = true
                panel.animator().alphaValue = 0
            }
            guard generation == presentationGeneration else { return }
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
        #endif
        currentEvents = []
        callbacks.onDismissalCompleted?()
        if !eventQueue.isEmpty, !isScreenLocked,
           !(options.suppressWhenFullScreen && isTargetFullScreen)
        {
            try? await Task.sleep(for: .milliseconds(120))
            await presentNextQueuedGroup()
        }
    }

    private func scheduleDismiss(after delay: TimeInterval) {
        dismissalTask?.cancel()
        guard delay > 0 else { return }
        let generation = presentationGeneration
        countdownStartedAt = ProcessInfo.processInfo.systemUptime
        dismissalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard let self, generation == self.presentationGeneration else { return }
            await self.dismiss()
        }
    }

    private func handleHover(_ hovering: Bool) {
        guard !currentEvents.isEmpty else { return }
        if hovering {
            let elapsed = max(0, ProcessInfo.processInfo.systemUptime - countdownStartedAt)
            remainingHoldDuration = max(0.25, remainingHoldDuration - elapsed)
            dismissalTask?.cancel()
            dismissalTask = nil
        } else {
            // A short grace period keeps small pointer slips from closing the alert.
            scheduleDismiss(after: remainingHoldDuration + 0.25)
        }
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
                self?.eventQueue.removeAll()
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
        panel.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1
        )
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.animationBehavior = .none

        let hosting = EdgeToEdgeNotchHostingView(
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

    private func animatePresentation(of panel: NSPanel) {
        guard options.reduceMotion else {
            panel.alphaValue = 1
            return
        }
        let duration = 0.14
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func recomputeFrameIfVisible() async {
        guard let panel, panel.isVisible, !currentEvents.isEmpty else { return }
        await presentCurrentGroup()
    }
    #endif
}

#if canImport(AppKit)
/// The panel is already positioned against the physical top obstruction.
/// Returning zero here prevents NSHostingView from applying NSScreen's notch
/// safe area a second time and creating a visible gap below the menu bar.
private final class EdgeToEdgeNotchHostingView: NSHostingView<NotchEventContentView> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
#endif
