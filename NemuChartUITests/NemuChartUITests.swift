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

        XCTAssertTrue(app.images["NemuChart"].exists)
        XCTAssertFalse(app.buttons["時間帯にかかわらず記録する"].exists)
        XCTAssertTrue(app.buttons["7日間の分析を見る"].exists)
    }

    func testFreshInstallShowsDataShortageWithoutFakeValues() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launch()
        completeOnboarding(in: app)
        dismissWeeklyGoalPromptIfNeeded(in: app)

        let weeklyAnalysisButton = app.buttons["7日間の分析を見る"]
        for _ in 0..<3 where !weeklyAnalysisButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(weeklyAnalysisButton.isHittable)
        weeklyAnalysisButton.tap()
        XCTAssertTrue(app.navigationBars["7日間の振り返り"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0 / 7日記録"].exists)
        XCTAssertTrue(app.staticTexts["分析信頼度：準備中"].exists)
    }

    private func completeOnboarding(in app: XCUIApplication) {
        guard app.navigationBars["はじめまして"].waitForExistence(timeout: 3) else { return }
        let next = app.buttons["onboardingPrimaryButton"]
        next.tap()
        next.tap()
        let home = app.navigationBars["NemuChart"]
        let weeklyGoal = app.navigationBars["週間目標"]
        XCTAssertTrue(home.waitForExistence(timeout: 3) || weeklyGoal.waitForExistence(timeout: 3))
    }

    private func dismissWeeklyGoalPromptIfNeeded(in app: XCUIApplication) {
        guard app.navigationBars["週間目標"].waitForExistence(timeout: 3) else { return }
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.navigationBars["NemuChart"].waitForExistence(timeout: 3))
    }
}
