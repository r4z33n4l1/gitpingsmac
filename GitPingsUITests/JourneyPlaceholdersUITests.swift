import XCTest

/// UI journey placeholders for Wave 1 / Gate 0 (MENUBAR / LIFECYCLE / NOTCH / AUTH recovery).
/// These encode the acceptance path; they skip until a macOS Tahoe host can drive the real bundle.
final class JourneyPlaceholdersUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// First run: launch → device-flow account surface → repository selection → filters → pins.
    func testFirstRunJourney_placeholder() throws {
        throw XCTSkip("""
        First-run journey (REQUIREMENTS §8):
        1. Launch GitPings — MenuBarExtra visible; no dashboard unless opened (LIFECYCLE-1/3).
        2. Settings → Account shows signed-out or device-flow pending (AUTH).
        3. After auth, select repositories and confirm default PR filters.
        4. Dashboard lists tracked PRs; pin up to five.
        Blocked without macOS Tahoe host + auth UI wiring.
        """)
    }

    /// Pin and monitor: five pins → menu-bar severity → notch/fallback transition without focus theft.
    func testPinAndMonitorJourney_placeholder() throws {
        throw XCTSkip("""
        Pin-and-monitor journey (REQUIREMENTS §8):
        1. Pin five PRs; sixth requires explicit replacement (PIN).
        2. Menu bar popover shows compact CI/merge text + symbols (MENUBAR-3/8).
        3. Injected transition presents notch or fallback pill without activating the app (NOTCH-4).
        4. Hover pauses dismissal; click opens GitHub (NOTCH-7).
        Blocked without notched/notchless hardware matrix (Gate 0 ADR-004).
        """)
    }

    /// Recover authorization: needsReauthorization → reauth → monitoring resumes without historical spam.
    func testRecoverAuthorizationJourney_placeholder() throws {
        throw XCTSkip("""
        Recover-authorization journey (REQUIREMENTS §8):
        1. Fixture/auth fault surfaces needsReauthorization in Settings Account.
        2. Reauthorize completes device flow again.
        3. Refresh resumes; baseline rules avoid duplicate historical notifications (CHANGE-2).
        Blocked without macOS host + live GitHub App credentials.
        """)
    }
}
