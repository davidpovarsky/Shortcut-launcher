import XCTest
@testable import DavLauncher

final class LauncherProfileTests: XCTestCase {
    func testAutomationTokenIsRendered() {
        let notification = LauncherNotification(
            body: "Run automation",
            automationToken: "DAV:TEST",
            includesAutomationToken: true
        )
        XCTAssertEqual(notification.renderedBody, "Run automation [DAV:TEST]")
    }

    func testAutomationTokenCanBeHidden() {
        let notification = LauncherNotification(
            body: "Run automation",
            automationToken: "DAV:TEST",
            includesAutomationToken: false
        )
        XCTAssertEqual(notification.renderedBody, "Run automation")
    }

    func testStatePersistsUntilExplicitlyChanged() {
        var profile = LauncherProfile.sampleReading()
        profile.setState(.active)
        XCTAssertEqual(profile.resolvedState(), .active)

        profile.setState(.success)
        XCTAssertEqual(profile.resolvedState(), .success)

        profile.setState(.idle)
        XCTAssertEqual(profile.resolvedState(), .idle)
    }

    func testAppearanceUsesPerStateConfiguration() {
        let profile = LauncherProfile.sampleLights()
        XCTAssertEqual(profile.appearance.style(for: .idle).symbolName, "lightbulb")
        XCTAssertEqual(profile.appearance.style(for: .active).symbolName, "lightbulb.fill")
        XCTAssertEqual(profile.appearance.style(for: .active).tint, .yellow)
    }
}
