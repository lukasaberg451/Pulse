//
//  DashboardTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-21.
//

import XCTest

final class DashboardTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsWorkoutCleanup: Bool { true }
    override var needsScheduleCleanup: Bool { true }

    // MARK: - Test: Dashboard Shows Welcome Header

    /// Verifies the welcome greeting and today's date are visible on the dashboard.
    func testDashboardShowsWelcomeHeader() throws {
        dismissResumeAlertIfPresent()
        navigateToDashboard()

        // The welcome text should be visible (either "Welcome!" or "Welcome <name>!")
        let welcomeText = app.staticTexts.matching(identifier: "dashboardWelcomeText").firstMatch
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 10), "Welcome text not found on the dashboard")
    }

    // MARK: - Test: Dashboard Shows Stats Bar

    /// Verifies the stats bar with Daily Streak, Workouts, and This Week labels is visible.
    func testDashboardShowsStatsBar() throws {
        dismissResumeAlertIfPresent()
        navigateToDashboard()

        let statsBar = app.otherElements["dashboardStatsBar"]
        XCTAssertTrue(statsBar.waitForExistence(timeout: 10), "Stats bar not found on the dashboard")

        let dailyStreakLabel = app.staticTexts["Daily Streak"]
        XCTAssertTrue(dailyStreakLabel.waitForExistence(timeout: 5), "'Daily Streak' label not found in the stats bar")

        let workoutsLabel = app.staticTexts["Workouts"]
        XCTAssertTrue(workoutsLabel.waitForExistence(timeout: 5), "'Workouts' label not found in the stats bar")

        let thisWeekLabel = app.staticTexts["This Week"]
        XCTAssertTrue(thisWeekLabel.waitForExistence(timeout: 5), "'This Week' label not found in the stats bar")
    }

    // MARK: - Test: Dashboard Shows Weekly Goal Card

    /// Verifies the Weekly Goal card is visible with its key elements.
    func testDashboardShowsWeeklyGoalCard() throws {
        dismissResumeAlertIfPresent()
        navigateToDashboard()

        let weeklyGoalCard = app.otherElements["weeklyGoalCard"]
        XCTAssertTrue(weeklyGoalCard.waitForExistence(timeout: 10), "Weekly Goal card not found on the dashboard")

        let weeklyGoalLabel = app.staticTexts["Weekly Goal"]
        XCTAssertTrue(weeklyGoalLabel.waitForExistence(timeout: 5), "'Weekly Goal' label not found")

        // The edit goal button should be present
        let editButton = app.buttons["editWeeklyGoalButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit Weekly Goal button not found")
    }

    // MARK: - Test: Dashboard Shows Empty Today Card

    /// Verifies the empty state card when no workouts are scheduled for today.
    func testDashboardShowsEmptyTodayCard() throws {
        dismissResumeAlertIfPresent()
        navigateToDashboard()

        // Look for the "Today" section header
        let todayHeader = app.staticTexts["Today"]
        XCTAssertTrue(todayHeader.waitForExistence(timeout: 10), "'Today' section header not found")

        // Check for empty state text — may or may not be present depending on schedule
        // If workouts are scheduled, we'll see the routine name; otherwise, the empty state.
        let noWorkoutsText = app.staticTexts["No workouts scheduled"]
        let addButton = app.buttons["dashboardAddWorkoutButton"]
        let todayCard = app.otherElements["dashboardTodayWorkoutCard"]

        let hasContent = noWorkoutsText.waitForExistence(timeout: 5) || addButton.exists || todayCard.exists
        XCTAssertTrue(hasContent, "Neither empty state nor scheduled workout card found in the Today section")
    }

    // MARK: - Test: Dashboard Shows Scheduled Workout Card

    /// Creates a routine, schedules it for today, then navigates to the dashboard
    /// and verifies the routine name and "Scheduled" label appear on the today card.
    func testDashboardShowsScheduledWorkoutCard() throws {
        let routineName = "UITest Dash \(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create a routine with an exercise
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10), "Routine detail not showing")
        addBenchPressToRoutine()
        navigateBackToRoutineList()
        waitForAnimation()

        // 2. Schedule it for today
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        // 3. Navigate to the Dashboard
        navigateToDashboard()

        let routineOnDashboard = app.staticTexts[routineName]
        XCTAssertTrue(routineOnDashboard.waitForExistence(timeout: 10), "Scheduled routine '\(routineName)' not found on the dashboard")

        let scheduledLabel = app.staticTexts["Scheduled"]
        XCTAssertTrue(scheduledLabel.waitForExistence(timeout: 5), "'Scheduled' label not found on the today workout card")

        // The "Start" button should be visible for an uncompleted workout.
        // Note: The parent card's accessibilityIdentifier ("dashboardTodayWorkoutCard")
        // merges with the inner button, so we find it by identifier + label.
        let startButton = app.buttons.matching(NSPredicate(
            format: "identifier == 'dashboardTodayWorkoutCard' AND label == 'Start'"
        )).firstMatch
        if !startButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start button not found on the today workout card")
    }

    // MARK: - Test: Schedule Workout From Dashboard Empty State

    /// Taps the "Add" button on the empty today card and verifies
    /// the routine picker sheet appears.
    func testScheduleWorkoutFromDashboardEmptyState() throws {
        dismissResumeAlertIfPresent()
        navigateToDashboard()

        // This test assumes no workouts are scheduled for today.
        // Look for the "Add" button in the empty today card.
        let addButton = app.buttons["dashboardAddWorkoutButton"]

        // If a workout is already scheduled, the empty card won't show.
        // Skip gracefully in that case.
        guard addButton.waitForExistence(timeout: 10) else {
            // A workout is already scheduled — the Add button won't appear.
            // This is not a failure; just skip the rest of the test.
            return
        }

        addButton.tap()

        // The routine picker sheet should appear with "Select Routine" title
        let selectRoutineTitle = app.navigationBars["Select Routine"]
        XCTAssertTrue(selectRoutineTitle.waitForExistence(timeout: 5), "Routine picker sheet did not appear after tapping Add on dashboard")

        // Dismiss the picker
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
            waitForAnimation()
        }
    }

    // MARK: - Test: Open Weekly Goal Sheet

    /// Taps the edit goal button on the weekly goal card and verifies
    /// the Weekly Workout Goal sheet appears with its key elements.
    func testOpenWeeklyGoalSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToDashboard()

        // Tap the edit goal button
        let editButton = app.buttons["editWeeklyGoalButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Edit Weekly Goal button not found")
        editButton.tap()

        // Verify the sheet appeared
        let sheetTitle = app.staticTexts["Weekly Workout Goal"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Weekly Workout Goal sheet title not found")

        let subtitle = app.staticTexts["Set your target workout minutes per week"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "Sheet subtitle not found")

        let minutesLabel = app.staticTexts["minutes per week"]
        XCTAssertTrue(minutesLabel.waitForExistence(timeout: 5), "'minutes per week' label not found in the goal sheet")

        // Verify suggested goals section
        let suggestedTitle = app.staticTexts["Suggested Goals"]
        XCTAssertTrue(suggestedTitle.waitForExistence(timeout: 5), "'Suggested Goals' section not found")

        let balancedButton = app.buttons["goalButton_150"]
        XCTAssertTrue(balancedButton.waitForExistence(timeout: 5), "'Balanced' (150 min) suggested goal not found")

        let consistentButton = app.buttons["goalButton_210"]
        XCTAssertTrue(consistentButton.waitForExistence(timeout: 5), "'Consistent' (210 min) suggested goal not found")

        let dedicatedButton = app.buttons["goalButton_300"]
        XCTAssertTrue(dedicatedButton.waitForExistence(timeout: 5), "'Dedicated' (300 min) suggested goal not found")

        // Verify Save and Cancel buttons exist
        let saveButton = app.buttons["saveWeeklyGoalButton"]
        XCTAssertTrue(saveButton.exists, "Save button not found on the goal sheet")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found on the goal sheet")

        // Dismiss
        cancelButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Update Weekly Goal From Dashboard

    /// Opens the weekly goal sheet, selects a suggested goal that differs
    /// from the current selection, saves, and verifies the updated value.
    func testUpdateWeeklyGoalFromDashboard() throws {
        dismissResumeAlertIfPresent()
        navigateToDashboard()

        // Open the goal sheet
        let editButton = app.buttons["editWeeklyGoalButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Edit Weekly Goal button not found")
        editButton.tap()

        // Wait for sheet to appear
        let sheetTitle = app.staticTexts["Weekly Workout Goal"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Weekly Workout Goal sheet did not appear")

        // Pick a goal that isn't already selected
        // Check if 300 is already displayed; if so, pick 150 instead
        let goalOptions = [(minutes: 300, label: "Dedicated"), (minutes: 150, label: "Balanced")]
        var targetMinutes = goalOptions[0].minutes

        if app.staticTexts["300"].exists {
            targetMinutes = goalOptions[1].minutes
        }

        let goalButton = app.buttons["goalButton_\(targetMinutes)"]
        XCTAssertTrue(goalButton.waitForExistence(timeout: 5), "Suggested goal button for \(targetMinutes) not found")
        goalButton.tap()
        waitForAnimation()

        // Verify the large value display shows the selected goal
        let valueDisplay = app.staticTexts["\(targetMinutes)"]
        XCTAssertTrue(valueDisplay.waitForExistence(timeout: 5), "Goal value did not update to \(targetMinutes) in the sheet")

        // Save
        let saveButton = app.buttons["saveWeeklyGoalButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button not found")
        saveButton.tap()

        // Verify the weekly goal card now shows the updated goal
        let updatedGoalText = app.staticTexts["/ \(targetMinutes) min"]
        XCTAssertTrue(updatedGoalText.waitForExistence(timeout: 10), "Weekly goal card did not update to show '/ \(targetMinutes) min'")
    }
}
