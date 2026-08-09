import XCTest

final class GitPingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Wave 0 smoke: launch the menu-bar app process. Richer UI coverage lands after Gate 0.
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10) || app.state == .runningBackground)
    }
}
