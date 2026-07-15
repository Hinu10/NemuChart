import XCTest

final class NemuChartUITests: XCTestCase {
    func testPrimaryFlowHasAccessibleLabels() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
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

    func testFreshInstallShowsDataShortageWithoutFakeValues() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launch()
        completeOnboarding(in: app)

        app.buttons["7日間の分析を見る"].tap()
        XCTAssertTrue(app.navigationBars["7日間の振り返り"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0 / 7日記録"].exists)
        XCTAssertTrue(app.staticTexts["分析信頼度：準備中"].exists)
    }

    private func completeOnboarding(in app: XCUIApplication) {
        guard app.navigationBars["はじめまして"].waitForExistence(timeout: 3) else { return }
        let next = app.buttons["onboardingPrimaryButton"]
        next.tap()
        next.tap()
        XCTAssertTrue(app.navigationBars["NemuChart"].waitForExistence(timeout: 3))
    }
}
