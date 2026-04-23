//
//  ProgressTabTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-21.
//

import XCTest

final class ProgressTabTests: UITestBaseCase {

    // MARK: - Helpers

    private func navigateToProgress() {
        let progressTab = app.buttons["Progress"]
        assertExists(progressTab, timeout: 15, "Progress tab not found")
        progressTab.tap()
        _ = app.staticTexts["Activity"].waitForExistence(timeout: 10)
    }

    // MARK: - Test: Progress Tab Loads Activity Section

    func testProgressTabShowsActivitySection() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' section header not found")

        let streakCard = app.otherElements["progressStreakCard"]
        XCTAssertTrue(streakCard.waitForExistence(timeout: 5), "Streak card not found")

        let currentStreakLabel = app.staticTexts["Current Streak"]
        XCTAssertTrue(currentStreakLabel.exists, "'Current Streak' label not found")

        let longestStreakLabel = app.staticTexts["Longest Streak"]
        XCTAssertTrue(longestStreakLabel.exists, "'Longest Streak' label not found")

        let lastWorkoutLabel = app.staticTexts["Last Workout"]
        XCTAssertTrue(lastWorkoutLabel.exists, "'Last Workout' label not found")
    }

    // MARK: - Test: Workouts Completed Card Visible

    func testProgressTabShowsWorkoutsCard() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let workoutsCard = app.otherElements["progressWorkoutsCard"]
        XCTAssertTrue(workoutsCard.waitForExistence(timeout: 10), "Workouts card not found")

        let completedText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'workouts completed'")).firstMatch
        XCTAssertTrue(completedText.waitForExistence(timeout: 5), "'workouts completed' text not found")

        let thisMonthText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'this month'")).firstMatch
        XCTAssertTrue(thisMonthText.waitForExistence(timeout: 5), "'this month' text not found")
    }

    // MARK: - Test: Volume Lifted Card Visible

    func testProgressTabShowsVolumeCard() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let volumeCard = app.otherElements["progressVolumeCard"]
        XCTAssertTrue(volumeCard.waitForExistence(timeout: 10), "Volume card not found")

        let volumeLabel = app.staticTexts["Volume Lifted"]
        XCTAssertTrue(volumeLabel.exists, "'Volume Lifted' label not found")

        let allTimeText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'All time'")).firstMatch
        XCTAssertTrue(allTimeText.waitForExistence(timeout: 5), "'All time' volume text not found")
    }

    // MARK: - Test: Estimated 1RM Section Visible

    func testProgressTabShowsEstimated1RMSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let estimated1RMSection = app.otherElements["progressEstimated1RMSection"]
        if !estimated1RMSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(estimated1RMSection.waitForExistence(timeout: 5), "Estimated 1RM section not found")

        let estimated1RMHeader = app.staticTexts["Estimated 1RM"]
        XCTAssertTrue(estimated1RMHeader.exists, "'Estimated 1RM' header not found")
    }

    // MARK: - Test: Strength Progress Section Visible

    func testProgressTabShowsStrengthProgressSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let strengthSection = app.otherElements["progressStrengthSection"]
        if !strengthSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(strengthSection.waitForExistence(timeout: 5), "Strength Progress section not found")

        let strengthHeader = app.staticTexts["Weight Progress"]
        XCTAssertTrue(strengthHeader.exists, "'Weight Progress' header not found")
    }

    // MARK: - Test: Body Metrics Section Visible

    func testProgressTabShowsBodyMetricsSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let bodyMetricsSection = app.otherElements["progressBodyMetricsSection"]
        if !bodyMetricsSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
            if !bodyMetricsSection.waitForExistence(timeout: 3) {
                app.swipeUp()
                waitForAnimation()
            }
        }
        XCTAssertTrue(bodyMetricsSection.waitForExistence(timeout: 5), "Body Metrics section not found")

        let bodyMetricsHeader = app.staticTexts["Body Metrics"]
        XCTAssertTrue(bodyMetricsHeader.exists, "'Body Metrics' header not found")
    }

    // MARK: - Test: Edit Body Metrics Sheet Opens

    func testEditBodyMetricsSheetOpens() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let bodyMetricsSection = app.otherElements["progressBodyMetricsSection"]
        if !bodyMetricsSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
            if !bodyMetricsSection.waitForExistence(timeout: 3) {
                app.swipeUp()
                waitForAnimation()
            }
        }
        assertExists(bodyMetricsSection, timeout: 5, "Body Metrics section not found")

        let heightButton = app.buttons["bodyMetricsHeightButton"]
        if !heightButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        assertExists(heightButton, timeout: 5, "Height metric button not found")
        heightButton.tap()

        let sheetTitle = app.staticTexts["Height"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Height sheet title not found")

        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        } else {
            let doneButton = app.buttons["Done"]
            if doneButton.exists { doneButton.tap() }
        }
    }

    // MARK: - Test: Pull to Refresh on Progress Tab

    func testProgressTabPullToRefresh() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' header not found before refresh")

        let firstCell = app.otherElements["progressStreakCard"]
        if firstCell.waitForExistence(timeout: 5) {
            let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 4.0))
            start.press(forDuration: 0.1, thenDragTo: end)
            _ = activityHeader.waitForExistence(timeout: 10)
        }

        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' header not found after refresh")
    }

    // MARK: - Test: Navigate to All Strength Progress

    func testNavigateToAllStrengthProgress() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let strengthSection = app.otherElements["progressStrengthSection"]
        if !strengthSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }

        let seeAllButton = app.buttons["strengthProgressSeeAllButton"]
        guard seeAllButton.waitForExistence(timeout: 5) else { return }

        seeAllButton.tap()

        let navTitle = app.navigationBars["Weight Progress"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Weight Progress detail view not found")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
        }
    }

    // MARK: - Test: Navigate to All Estimated 1RM

    func testNavigateToAllEstimated1RM() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let estimated1RMSection = app.otherElements["progressEstimated1RMSection"]
        if !estimated1RMSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }

        let seeAllButton = app.buttons["estimated1RMSeeAllButton"]
        guard seeAllButton.waitForExistence(timeout: 5) else { return }

        seeAllButton.tap()

        let navTitle = app.navigationBars["Estimated 1RM"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Estimated 1RM detail view not found")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
        }
    }
}
