import SwiftUI

@main
struct GitPingsApp: App {
    @State private var container = AppDependencyContainer.bootstrap()

    private var dashboardLaunchBehavior: SceneLaunchBehavior {
        ProcessInfo.processInfo.environment["GITPINGS_VERIFY_UI"] == "1" ? .presented : .suppressed
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(model: container.appModel)
        } label: {
            MenuBarStatusLabel(severity: container.appModel.menuBarSeverity)
        }
        .menuBarExtraStyle(.window)

        Window("GitPings", id: "dashboard") {
            DashboardRootView(model: container.appModel)
                .environment(container.appModel)
                .task { container.appModel.start() }
        }
        .defaultSize(width: 960, height: 640)
        .defaultLaunchBehavior(dashboardLaunchBehavior)
        .commands {
            OpenDashboardCommands()
        }

        Settings {
            SettingsRootView(model: container.appModel)
                .environment(container.appModel)
        }
    }
}

private struct OpenDashboardCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open GitPings Dashboard") {
                openWindow(id: "dashboard")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
