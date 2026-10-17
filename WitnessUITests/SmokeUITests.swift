import XCTest

final class SmokeUITests: XCTestCase {
    func testLaunchScreenshot() {
        let app = XCUIApplication()
        app.launch()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "smoke-launch"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
