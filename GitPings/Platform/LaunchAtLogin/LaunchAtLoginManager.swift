import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

/// Launch-at-login wrapper around Service Management (`SMAppService`) concepts (SETTINGS-3).
/// Quiet login behavior (no dashboard) remains App composition / LIFECYCLE-3 integrator work.
public actor LaunchAtLoginManager: LaunchAtLoginManaging {
    private var cachedEnabled: Bool?
    private let service: any LaunchAtLoginServiceProxying

    public init(service: (any LaunchAtLoginServiceProxying)? = nil) {
        self.service = service ?? SMAppServiceLaunchAtLoginProxy()
    }

    public var isEnabled: Bool {
        get async {
            if let cachedEnabled { return cachedEnabled }
            return service.isEnabled
        }
    }

    public func setEnabled(_ enabled: Bool) async throws {
        try service.setEnabled(enabled)
        cachedEnabled = enabled
    }
}

public protocol LaunchAtLoginServiceProxying: Sendable {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

#if canImport(ServiceManagement)
/// Conceptual bridge to `SMAppService.mainApp` register / unregister.
public struct SMAppServiceLaunchAtLoginProxy: LaunchAtLoginServiceProxying {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
#else
/// Host stub when ServiceManagement is unavailable (e.g. Linux Cloud Agent).
public struct SMAppServiceLaunchAtLoginProxy: LaunchAtLoginServiceProxying {
    public init() {}

    public var isEnabled: Bool { false }

    public func setEnabled(_ enabled: Bool) throws {
        _ = enabled
        throw GitPingsError.unsupportedConfiguration("SMAppService unavailable on this host")
    }
}
#endif
