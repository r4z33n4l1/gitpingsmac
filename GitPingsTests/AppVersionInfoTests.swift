import XCTest
@testable import GitPings

final class AppVersionInfoTests: XCTestCase {
    func testReadsVersionAndBuildFromBundleMetadata() {
        let info = AppVersionInfo(infoDictionary: [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "45",
        ])

        XCTAssertEqual(info.version, "1.2.3")
        XCTAssertEqual(info.build, "45")
    }

    func testUsesDevelopmentFallbackForMissingMetadata() {
        let info = AppVersionInfo(infoDictionary: nil)

        XCTAssertEqual(info.version, "Development")
        XCTAssertEqual(info.build, "Development")
    }
}
