import XCTest

final class NemuChartUITests: XCTestCase {
    func testPrimaryFlowHasAccessibleLabels() {
        let app = XCUIApplication()
        app.launch()

        let onboarding = app.navigationBars["はじめまして"]
        let home = app.navigationBars["NemuChart"]
        XCTAssertTrue(onboarding.waitForExistence(timeout: 5) || home.waitForExistence(timeout: 5))

        if onboarding.exists {
            let next = app.buttons["onboardingPrimaryButton"]
            XCTAssertTrue(next.exists)
            next.tap()
            XCTAssertTrue(app.staticTexts["必須設定（3項目）"].waitForExistence(timeout: 2))
            next.tap()
            XCTAssertTrue(home.waitForExistence(timeout: 3))
        }

        let record = app.buttons["時間帯にかかわらず記録する"]
        XCTAssertTrue(record.exists)
        record.tap()
        XCTAssertTrue(app.navigationBars["睡眠を記録"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["reviewSleepRecord"].exists)
    }
}
