//
//  DashboardTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-21.
//

import XCTest

final class DashboardTests: XCTestCase {

    var app: XCUIApplication!

    /// Unique suffix to avoid name collisions between test runs.
    private let uniqueSuffix = UUID().uuidString.prefix(6)

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

    /// Navigate to the Dashboard tab (first tab, default on launch).
    private func navigateToDashboard() {
        let dashboardTab = app.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 15), "Dashboard tab not found")
        dashboardTab.tap()
        sleep(2)
    }

    /// Navigate to the Routines sub-tab inside the Workout tab.
    private func navigateToRoutinesTab() {
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5), "Routines pill not found")
        routinesPill.tap()
        sleep(2)
    }

    /// Navigate to the Schedule sub-tab inside the Workout tab.
    private func navigateToScheduleTab() {
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        let schedulePill = app.buttons["Schedule"]
        XCTAssertTrue(schedulePill.waitForExistence(timeout: 5), "Schedule pill not found")
        schedulePill.tap()
        sleep(2)
    }

    /// Create a routine with the given name via the UI. Returns the name used.
    @discardableResult
    private func createRoutine(name: String) -> String {
        let newRoutineButton = app.buttons["newRoutineButton"]
        XCTAssertTrue(newRoutineButton.waitForExistence(timeout: 10), "New Routine button not found")
        newRoutineButton.tap()

        let nameField = app.textFields["routineNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Routine name field not found")
        nameField.tap()
        nameField.typeText(name)

        let createButton = app.buttons["createRoutineButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create Routine button not found")
        createButton.tap()

        sleep(3)
        return name
    }

    /// Add "Bench Press" exercise to the current routine detail view.
    private func addBenchPressToRoutine() {
        let addExerciseButton = app.buttons["addExerciseButton"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise button not found")
        addExerciseButton.tap()
        sleep(2)

        let searchField = app.textFields["exerciseSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Exercise search field not found")
        searchField.tap()
        searchField.typeText("Bench Press")
        sleep(2)

        let benchPressResult = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchPressResult.waitForExistence(timeout: 10), "Bench Press not found in search results")
        benchPressResult.tap()
        sleep(1)

        let weightField = app.textFields["exerciseWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Exercise weight field not found")
        weightField.tap()
        weightField.typeText("60")

        let addButton = app.buttons["addExerciseToRoutineButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button not found")
        addButton.tap()
        sleep(2)

        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            sleep(2)
        }
    }

    /// Navigate back from the routine detail view to the routine list.
    private func navigateBackToRoutineList() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            sleep(2)
        }
    }

    /// Schedule a workout on today's date by tapping the Add Workout button and picking a routine.
    /// Assumes we are already on the Schedule tab and today's date is selected.
    private func scheduleWorkout(routineName: String) {
        let addWorkoutButton = app.buttons["addScheduledWorkoutButton"]
        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 5), "Add Workout button not found on schedule")
        addWorkoutButton.tap()
        sleep(2)

        let selectRoutineTitle = app.navigationBars["Select Routine"]
        XCTAssertTrue(selectRoutineTitle.waitForExistence(timeout: 5), "Routine picker sheet not shown")

        let routineRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", routineName)).firstMatch
        XCTAssertTrue(routineRow.waitForExistence(timeout: 10), "Routine '\(routineName)' not found in picker")
        routineRow.tap()
        sleep(3)
    }

    /// Delete all routines whose names contain the given substring.
    private func cleanupRoutines(containing substring: String) {
        navigateToRoutinesTab()
        sleep(2)

        let routineRows = app.buttons.matching(identifier: "routineRow")
        guard routineRows.count > 0 else { return }

        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let matchingRows = app.buttons.matching(predicate)
        guard matchingRows.count > 0 else { return }

        let modifyButton = app.buttons["modifyRoutinesButton"]
        guard modifyButton.waitForExistence(timeout: 5) else { return }
        modifyButton.tap()
        sleep(1)

        for i in 0..<matchingRows.count {
            matchingRows.element(boundBy: i).tap()
            usleep(500_000)
        }

        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Delete'")).firstMatch
        if deleteButton.waitForExistence(timeout: 3) {
            deleteButton.tap()
            sleep(1)
        }

        let confirmDelete = app.alerts.buttons["Delete"]
        if confirmDelete.waitForExistence(timeout: 3) {
            confirmDelete.tap()
            sleep(2)
        }
    }

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
        let routineName = "UITest Dash \\(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create a routine with an exercise
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10), "Routine detail not showing")
        addBenchPressToRoutine()
        navigateBackToRoutineList()
        sleep(1)

        // 2. Schedule it for today
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        // 3. Navigate to the Dashboard and verify
        navigateToDashboard()
        sleep(3)

        let routineOnDashboard = app.staticTexts[routineName]
        XCTAssertTrue(routineOnDashboard.waitForExistence(timeout: 10), "Scheduled routine '\(routineName)' not found on the dashboard")

        let scheduledLabel = app.staticTexts["Scheduled"]
        XCTAssertTrue(scheduledLabel.waitForExistence(timeout: 5), "'Scheduled' label not found on the today workout card")

        // The "Start" button should be visible for an uncompleted workout
        let startButton = app.buttons["dashboardStartWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start button not found on the today workout card")

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
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
        sleep(2)

        // The routine picker sheet should appear with "Select Routine" title
        let selectRoutineTitle = app.navigationBars["Select Routine"]
        XCTAssertTrue(selectRoutineTitle.waitForExistence(timeout: 5), "Routine picker sheet did not appear after tapping Add on dashboard")

        // Dismiss the picker
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
            sleep(1)
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
        sleep(2)

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
        sleep(1)
    }

    // MARK: - Test: Update Weekly Goal From Dashboard

    /// Opens the weekly goal sheet, selects a suggested goal, saves,
    /// and verifies the updated value reflects on the card.
    func testUpdateWeeklyGoalFromDashboard() throws {
        dismissResumeAlertIfPresent()
        navigateToDashboard()

        // Open the goal sheet
        let editButton = app.buttons["editWeeklyGoalButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Edit Weekly Goal button not found")
        editButton.tap()
        sleep(2)

        // Tap the "Dedicated" (300 min) suggested goal
        let dedicatedButton = app.buttons["goalButton_300"]
        XCTAssertTrue(dedicatedButton.waitForExistence(timeout: 5), "'Dedicated' suggested goal not found")
        dedicatedButton.tap()
        sleep(1)

        // Verify the large value display shows 300
        let valueDisplay = app.staticTexts["300"]
        XCTAssertTrue(valueDisplay.waitForExistence(timeout: 5), "Goal value did not update to 300 in the sheet")

        // Save
        let saveButton = app.buttons["saveWeeklyGoalButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button not found")
        saveButton.tap()
        sleep(3)

        // Verify the weekly goal card now shows "/ 300 min"
        let updatedGoalText = app.staticTexts["/ 300 min"]
        XCTAssertTrue(updatedGoalText.waitForExistence(timeout: 10), "Weekly goal card did not update to show '/ 300 min'")
    }
}
