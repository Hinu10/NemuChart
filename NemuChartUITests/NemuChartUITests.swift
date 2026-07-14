import XCTest

final class NemuChartUITests: XCTestCase {
    func testLaunchShowsAppName() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["NemuChart"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["睡眠リズムを、毎朝少しずつ記録します。"].exists)
    }
}

