import SwiftUI

@main
struct GitPingsApp: App {
    @State private var container = AppDependencyContainer.bootstrap()

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
        }
        .defaultSize(width: 960, height: 640)

        Settings {
            SettingsRootView(model: container.appModel)
                .environment(container.appModel)
        }
    }
}
