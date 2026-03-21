//
//  ProgressTabTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-21.
//

import XCTest

final class ProgressTabTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Dismiss any leftover "Resume Workout?" alert.
    private func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }
    }

    /// Navigate to the Progress tab.
    private func navigateToProgress() {
        let progressTab = app.buttons["Progress"]
        XCTAssertTrue(progressTab.waitForExistence(timeout: 15), "Progress tab not found")
        progressTab.tap()
        sleep(3)
    }

    // MARK: - Test: Progress Tab Loads Activity Section

    /// Verifies that navigating to the Progress tab shows the Activity section
    /// header along with the streak card, workouts card, and volume card.
    func testProgressTabShowsActivitySection() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' section header not found")

        let streakCard = app.otherElements["progressStreakCard"]
        XCTAssertTrue(streakCard.waitForExistence(timeout: 5), "Streak card not found")

        // Verify streak card content labels
        let currentStreakLabel = app.staticTexts["Current Streak"]
        XCTAssertTrue(currentStreakLabel.exists, "'Current Streak' label not found")

        let longestStreakLabel = app.staticTexts["Longest Streak"]
        XCTAssertTrue(longestStreakLabel.exists, "'Longest Streak' label not found")

        let lastWorkoutLabel = app.staticTexts["Last Workout"]
        XCTAssertTrue(lastWorkoutLabel.exists, "'Last Workout' label not found")
    }

    // MARK: - Test: Workouts Completed Card Visible

    /// Verifies the total workouts card shows "workouts completed" and "this month" info.
    func testProgressTabShowsWorkoutsCard() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let workoutsCard = app.otherElements["progressWorkoutsCard"]
        XCTAssertTrue(workoutsCard.waitForExistence(timeout: 10), "Workouts card not found")

        let completedText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'workouts completed'")).firstMatch
        XCTAssertTrue(completedText.waitForExistence(timeout: 5), "'workouts completed' text not found")

        let thisMonthText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'this month'")).firstMatch
        XCTAssertTrue(thisMonthText.waitForExistence(timeout: 5), "'this month' text not found")
    }

    // MARK: - Test: Volume Lifted Card Visible

    /// Verifies the volume lifted card is present with weekly and all-time data.
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

    /// Verifies the Estimated 1RM section is present on the Progress tab.
    func testProgressTabShowsEstimated1RMSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        // Scroll down to find the 1RM section
        let estimated1RMSection = app.otherElements["progressEstimated1RMSection"]
        if !estimated1RMSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(estimated1RMSection.waitForExistence(timeout: 5), "Estimated 1RM section not found")

        let estimated1RMHeader = app.staticTexts["Estimated 1RM"]
        XCTAssertTrue(estimated1RMHeader.exists, "'Estimated 1RM' header not found")
    }

    // MARK: - Test: Strength Progress Section Visible

    /// Verifies the Strength Progress section is present on the Progress tab.
    func testProgressTabShowsStrengthProgressSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        // Scroll down to find the section
        let strengthSection = app.otherElements["progressStrengthSection"]
        if !strengthSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(strengthSection.waitForExistence(timeout: 5), "Strength Progress section not found")

        let strengthHeader = app.staticTexts["Strength Progress"]
        XCTAssertTrue(strengthHeader.exists, "'Strength Progress' header not found")
    }

    // MARK: - Test: Body Metrics Section Visible

    /// Verifies the Body Metrics section is present on the Progress tab.
    func testProgressTabShowsBodyMetricsSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        // Scroll down to find Body Metrics
        let bodyMetricsSection = app.otherElements["progressBodyMetricsSection"]
        if !bodyMetricsSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
            if !bodyMetricsSection.waitForExistence(timeout: 3) {
                app.swipeUp()
                sleep(1)
            }
        }
        XCTAssertTrue(bodyMetricsSection.waitForExistence(timeout: 5), "Body Metrics section not found")

        let bodyMetricsHeader = app.staticTexts["Body Metrics"]
        XCTAssertTrue(bodyMetricsHeader.exists, "'Body Metrics' header not found")
    }

    // MARK: - Test: Edit Body Metrics Sheet Opens

    /// Taps the edit button on the Body Metrics section and verifies
    /// the Edit Health Metrics sheet appears.
    func testEditBodyMetricsSheetOpens() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        // Scroll down to Body Metrics
        let editButton = app.buttons["editBodyMetricsButton"]
        if !editButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
            if !editButton.waitForExistence(timeout: 3) {
                app.swipeUp()
                sleep(1)
            }
        }
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit Body Metrics button not found")
        editButton.tap()
        sleep(2)

        // Verify the sheet appeared
        let sheetTitle = app.staticTexts["Body Metrics"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Body Metrics sheet title not found")

        let subtitle = app.staticTexts["Update your body measurements"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "Sheet subtitle not found")

        let heightLabel = app.staticTexts["Height"]
        XCTAssertTrue(heightLabel.exists, "'Height' label not found in the sheet")

        let weightLabel = app.staticTexts["Weight"]
        XCTAssertTrue(weightLabel.exists, "'Weight' label not found in the sheet")

        // Verify Save and Cancel buttons exist
        let saveButton = app.staticTexts["Save Changes"]
        XCTAssertTrue(saveButton.exists, "Save Changes button not found on the sheet")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found on the sheet")

        // Dismiss
        cancelButton.tap()
        sleep(1)
    }

    // MARK: - Test: Pull to Refresh on Progress Tab

    /// Verifies that pull-to-refresh works on the Progress tab without crashing.
    func testProgressTabPullToRefresh() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        // Verify content is present before refresh
        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' header not found before refresh")

        // Perform pull-to-refresh
        let firstCell = app.otherElements["progressStreakCard"]
        if firstCell.waitForExistence(timeout: 5) {
            let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 4.0))
            start.press(forDuration: 0.1, thenDragTo: end)
            sleep(3)
        }

        // Verify content still exists after refresh
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' header not found after refresh")
    }

    // MARK: - Test: Navigate to All Strength Progress

    /// If strength data exists, taps "See All" on Strength Progress
    /// and verifies the detail view appears.
    func testNavigateToAllStrengthProgress() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        // Scroll to Strength Progress section
        let strengthSection = app.otherElements["progressStrengthSection"]
        if !strengthSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }

        // Check if "See All" is available (only if user has strength data)
        let seeAllButton = app.buttons["strengthProgressSeeAllButton"]
        guard seeAllButton.waitForExistence(timeout: 5) else {
            // No strength data yet — "See All" won't appear; skip gracefully
            return
        }

        seeAllButton.tap()
        sleep(2)

        // Verify the detail view appeared
        let navTitle = app.navigationBars["Strength Progress"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Strength Progress detail view not found")

        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            sleep(1)
        }
    }

    // MARK: - Test: Navigate to All Estimated 1RM

    /// If 1RM data exists, taps "See All" on Estimated 1RM
    /// and verifies the detail view appears.
    func testNavigateToAllEstimated1RM() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        // Scroll to Estimated 1RM section
        let estimated1RMSection = app.otherElements["progressEstimated1RMSection"]
        if !estimated1RMSection.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }

        // Check if "See All" is available (only if user has 1RM data)
        let seeAllButton = app.buttons["estimated1RMSeeAllButton"]
        guard seeAllButton.waitForExistence(timeout: 5) else {
            // No 1RM data yet — skip gracefully
            return
        }

        seeAllButton.tap()
        sleep(2)

        // Verify the detail view appeared
        let navTitle = app.navigationBars["Estimated 1RM"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Estimated 1RM detail view not found")

        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            sleep(1)
        }
    }
}
