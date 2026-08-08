import XCTest

final class NemuChartUITests: XCTestCase {
    func testPrimaryFlowHasAccessibleLabels() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launch()

        let onboarding = app.navigationBars["はじめまして"]
        XCTAssertTrue(onboarding.waitForExistence(timeout: 5) || waitForHome(in: app, timeout: 5))

        completeOnboarding(in: app)
        dismissWeeklyGoalPromptIfNeeded(in: app)

        XCTAssertTrue(app.images["ねむちゃーと"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["記録する"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["時間帯にかかわらず記録する"].exists)
        XCTAssertTrue(app.buttons["7日間の分析を見る"].waitForExistence(timeout: 5))
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

    func testSettingsShowsMVPReleaseBoundariesAndSafetyCopy() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launch()
        completeOnboarding(in: app)
        dismissWeeklyGoalPromptIfNeeded(in: app)

        openSettings(in: app)

        XCTAssertTrue(scrollToElement(app.buttons["premiumFeaturesLink"], in: app))
        XCTAssertTrue(app.staticTexts["mvpFutureFeaturesDescription"].exists)
        app.buttons["premiumFeaturesLink"].tap()
        XCTAssertTrue(app.navigationBars["追加機能"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["premiumPurchaseButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["premiumRestoreButton"].exists)
        app.navigationBars["追加機能"].buttons.firstMatch.tap()

        XCTAssertTrue(scrollToElement(app.staticTexts["medicalDisclaimerPrimary"], in: app))
        XCTAssertTrue(scrollToElement(app.staticTexts["medicalDisclaimerSecondary"], in: app))
    }

    func testRecordReviewSaveAndResultFlowIsReachable() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launch()
        completeOnboarding(in: app)
        dismissWeeklyGoalPromptIfNeeded(in: app)

        XCTAssertTrue(app.buttons["記録する"].waitForExistence(timeout: 3))
        app.buttons["記録する"].tap()
        XCTAssertTrue(app.buttons["今日"].waitForExistence(timeout: 3))
        app.buttons["今日"].tap()

        XCTAssertTrue(app.navigationBars["睡眠を記録"].waitForExistence(timeout: 3))
        XCTAssertTrue(scrollToElement(app.buttons["reviewSleepRecord"], in: app))
        app.buttons["reviewSleepRecord"].tap()

        XCTAssertTrue(app.navigationBars["入力内容の確認"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["saveSleepRecord"].waitForExistence(timeout: 3))
        app.buttons["saveSleepRecord"].tap()

        XCTAssertTrue(app.navigationBars["今日の結果"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["dailyScoreSummary"].waitForExistence(timeout: 3) || app.staticTexts["100点中"].exists)
    }

    func testSleepRecordFormKeepsMVPInputFieldsSimpleAndDateAware() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launch()
        completeOnboarding(in: app)
        dismissWeeklyGoalPromptIfNeeded(in: app)

        XCTAssertTrue(app.buttons["記録する"].waitForExistence(timeout: 3))
        app.buttons["記録する"].tap()
        XCTAssertTrue(app.buttons["今日"].waitForExistence(timeout: 3))
        app.buttons["今日"].tap()

        XCTAssertTrue(app.navigationBars["睡眠を記録"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["必須項目"].exists)
        XCTAssertFalse(app.staticTexts["必須項目（3項目）"].exists)
        XCTAssertTrue(app.datePickers["wakeDateTimePicker"].exists)
        XCTAssertTrue(app.datePickers["sleepDateTimePicker"].exists)
        XCTAssertFalse(app.staticTexts["二度寝"].exists)
        XCTAssertFalse(app.switches["スマートフォン終了時刻を記録"].exists)

        XCTAssertTrue(scrollToElement(app.datePickers["smartphoneEndDateTimePicker"], in: app))
    }

    func testHomeRendersWithAccessibilityTextSizeAndDarkMode() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleInterfaceStyle", "Dark"
        ]
        app.launch()
        completeOnboarding(in: app)
        dismissWeeklyGoalPromptIfNeeded(in: app)

        XCTAssertTrue(app.buttons["記録する"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["7日間の分析を見る"].exists)
        XCTAssertTrue(app.buttons["homeSettingsButton"].exists)
    }

    func testMajorFlowsRemainReachableWithAccessibilityStressSettings() {
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleInterfaceStyle", "Dark",
            "-UIAccessibilityReduceMotionEnabled", "YES"
        ]
        app.launch()
        completeOnboarding(in: app)
        dismissWeeklyGoalPromptIfNeeded(in: app)

        XCTAssertTrue(app.buttons["記録する"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["7日間の分析を見る"].exists)
        XCTAssertTrue(app.buttons["homeSettingsButton"].exists)

        app.buttons["7日間の分析を見る"].tap()
        XCTAssertTrue(app.navigationBars["7日間の振り返り"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0 / 7日記録"].exists)
        app.navigationBars["7日間の振り返り"].buttons.firstMatch.tap()

        openSettings(in: app)
        XCTAssertTrue(scrollToElement(app.buttons["premiumFeaturesLink"], in: app))
        XCTAssertTrue(scrollToElement(app.staticTexts["medicalDisclaimerPrimary"], in: app))
        app.navigationBars["設定"].buttons.firstMatch.tap()

        XCTAssertTrue(app.buttons["記録する"].waitForExistence(timeout: 5))
        app.buttons["記録する"].tap()
        XCTAssertTrue(app.buttons["今日"].waitForExistence(timeout: 3))
        app.buttons["今日"].tap()
        XCTAssertTrue(app.navigationBars["睡眠を記録"].waitForExistence(timeout: 3))
        XCTAssertTrue(scrollToElement(app.buttons["reviewSleepRecord"], in: app))
    }

    func testHomeRemainsUsableWhenLandscapeOrientationIsRequested() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["NEMUCHART_UI_TESTING"] = "1"
        app.launch()
        completeOnboarding(in: app)
        dismissWeeklyGoalPromptIfNeeded(in: app)

        XCUIDevice.shared.orientation = .landscapeLeft

        let appFrame = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(appFrame.height, appFrame.width)
        XCTAssertTrue(app.buttons["記録する"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["7日間の分析を見る"].waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .portrait
    }

    private func completeOnboarding(in app: XCUIApplication) {
        guard app.navigationBars["はじめまして"].waitForExistence(timeout: 3) else { return }
        tapOnboardingPrimaryButton(in: app)
        if !app.buttons["この内容で始める"].waitForExistence(timeout: 6) {
            app.swipeLeft()
        }
        XCTAssertTrue(app.buttons["この内容で始める"].waitForExistence(timeout: 6))
        tapOnboardingPrimaryButton(in: app)
        if !waitForHomeOrWeeklyGoal(in: app, timeout: 5), app.buttons["onboardingPrimaryButton"].exists {
            tapOnboardingPrimaryButton(in: app)
        }
        XCTAssertTrue(waitForHomeOrWeeklyGoal(in: app, timeout: 20))
    }

    private func tapOnboardingPrimaryButton(in app: XCUIApplication) {
        let button = app.buttons["onboardingPrimaryButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        if !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.tap()
    }

    private func dismissWeeklyGoalPromptIfNeeded(in app: XCUIApplication) {
        if app.navigationBars["週間目標"].waitForExistence(timeout: 5) {
            app.buttons["閉じる"].tap()
        }
        XCTAssertTrue(waitForHome(in: app, timeout: 10))
    }

    private func openSettings(in app: XCUIApplication) {
        let settingsButton = app.buttons["homeSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        for _ in 0..<3 {
            if settingsButton.isHittable {
                settingsButton.tap()
            } else {
                app.buttons["設定"].firstMatch.tap()
            }
            if app.navigationBars["設定"].waitForExistence(timeout: 2) { return }
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.07)).tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 3))
    }

    private func waitForHome(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        app.buttons["7日間の分析を見る"].waitForExistence(timeout: timeout)
    }

    private func waitForHomeOrWeeklyGoal(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.buttons["7日間の分析を見る"].exists { return true }
            if app.navigationBars["週間目標"].exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if element.waitForExistence(timeout: 1) { return true }
        let scrollable = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.scrollViews.firstMatch
        for _ in 0..<8 {
            if scrollable.exists {
                scrollable.swipeUp()
            } else {
                app.swipeUp()
            }
            if element.waitForExistence(timeout: 1) { return true }
        }
        return false
    }
}
