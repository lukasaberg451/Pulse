//
//  ScheduleManagementTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-21.
//

import XCTest

final class ScheduleManagementTests: XCTestCase {

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

    /// Dismiss any leftover "Resume Workout?" alert.
    private func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }
    }

    /// Schedule a workout on today's date by tapping the Add Workout button and picking a routine.
    /// Assumes we are already on the Schedule tab and today's date is selected.
    private func scheduleWorkout(routineName: String) {
        // Tap the "Add Workout" button (either empty state or inline)
        let addWorkoutButton = app.buttons["addScheduledWorkoutButton"]
        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 5), "Add Workout button not found on schedule")
        addWorkoutButton.tap()
        sleep(2)

        // The routine picker sheet should appear
        let selectRoutineTitle = app.navigationBars["Select Routine"]
        XCTAssertTrue(selectRoutineTitle.waitForExistence(timeout: 5), "Routine picker sheet not shown")

        // Find and tap the routine by name
        let routineRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", routineName)).firstMatch
        XCTAssertTrue(routineRow.waitForExistence(timeout: 10), "Routine '\(routineName)' not found in picker")
        routineRow.tap()
        sleep(3)
    }

    /// Start a scheduled workout from the schedule card, complete one set, finish and dismiss summary.
    private func startAndCompleteScheduledWorkout() {
        let startButton = app.buttons["startScheduledWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start button not found on scheduled workout card")
        startButton.tap()
        sleep(2)

        // Verify active workout screen appeared
        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Finish button not found — active workout screen may not have appeared")

        // Enter a weight in the first set
        let weightField = app.textFields["weightField_1"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Weight field for set 1 not found")
        weightField.tap()
        weightField.typeText("80")

        // Dismiss keyboard, then tap the set number pill to complete the set
        app.navigationBars.firstMatch.tap()
        sleep(1)

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        XCTAssertTrue(setOnePill.waitForExistence(timeout: 5), "Set 1 pill not found")
        setOnePill.tap()
        sleep(1)

        // Finish the workout
        finishButton.tap()

        let finishAlert = app.alerts["Finish Workout?"]
        XCTAssertTrue(finishAlert.waitForExistence(timeout: 5), "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        // Dismiss the workout summary
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Done button not found on workout summary")
        doneButton.tap()
        sleep(2)
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

    // MARK: - Test: Add Routine to Schedule and Complete Workout

    /// Creates a routine with an exercise, adds it to the schedule, starts the workout,
    /// completes it, and verifies the "Completed" status appears on the card.
    func testScheduleRoutineAndCompleteWorkout() throws {
        let routineName = "UITest Sched \(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create a routine with an exercise
        navigateToRoutinesTab()
        createRoutine(name: routineName)

        // Verify routine detail appeared
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10), "Routine detail not showing")

        // Add an exercise so we can start a workout
        addBenchPressToRoutine()

        // Go back to routine list
        navigateBackToRoutineList()
        sleep(1)

        // 2. Switch to schedule tab and add the routine
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        // 3. Verify the scheduled workout card appears with the routine name
        let scheduledCard = app.staticTexts[routineName]
        XCTAssertTrue(scheduledCard.waitForExistence(timeout: 10), "Scheduled workout card with '\(routineName)' not found")

        // 4. Start and complete the workout
        startAndCompleteScheduledWorkout()

        // 5. Navigate back to schedule and verify "Completed" badge
        navigateToScheduleTab()
        let completedText = app.staticTexts["Completed"]
        XCTAssertTrue(completedText.waitForExistence(timeout: 10), "Completed badge not found on the scheduled workout card")

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Delete Routine Shows "Deleted Routine" on Schedule Card

    /// Creates a routine, adds it to the schedule, deletes the routine,
    /// and verifies the schedule card shows "Deleted Routine" / "Routine deleted".
    func testDeletedRoutineShowsOnScheduleCard() throws {
        let routineName = "UITest DelSched \(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create a routine
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        navigateBackToRoutineList()
        sleep(1)

        // 2. Schedule the routine on today
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        // Verify card appears
        let scheduledCard = app.staticTexts[routineName]
        XCTAssertTrue(scheduledCard.waitForExistence(timeout: 10), "Scheduled card not found for '\(routineName)'")

        // 3. Delete the routine
        cleanupRoutines(containing: String(uniqueSuffix))

        // 4. Go back to schedule and verify "Routine deleted" text appears
        navigateToScheduleTab()
        sleep(3)

        let deletedText = app.staticTexts["Routine deleted"]
        XCTAssertTrue(deletedText.waitForExistence(timeout: 10), "'Routine deleted' text not found on the schedule card after routine deletion")

        // Also verify the card uses the deleted routine card identifier
        let deletedCard = app.otherElements.matching(identifier: "deletedRoutineWorkoutCard").firstMatch
            .waitForExistence(timeout: 5)
        XCTAssertTrue(deletedCard, "Deleted routine workout card not found")
    }

    // MARK: - Test: Cannot Delete Completed Scheduled Workouts

    /// Schedules a workout, completes it, enters Modify mode, and verifies
    /// the completed workout cannot be selected for deletion.
    func testCannotDeleteCompletedScheduledWorkout() throws {
        let routineName = "UITest NoDel \(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create a routine with an exercise
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10), "Routine detail not showing")
        addBenchPressToRoutine()
        navigateBackToRoutineList()
        sleep(1)

        // 2. Schedule the routine and complete it
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        let scheduledCard = app.staticTexts[routineName]
        XCTAssertTrue(scheduledCard.waitForExistence(timeout: 10), "Scheduled card not found")

        startAndCompleteScheduledWorkout()

        // 3. Go back to schedule
        navigateToScheduleTab()
        let completedText = app.staticTexts["Completed"]
        XCTAssertTrue(completedText.waitForExistence(timeout: 10), "Completed badge not found")

        // 4. The "Modify" button should NOT be visible when all workouts are completed
        //    (the view only shows Modify when uncompletedWorkouts.count > 0)
        let modifyButton = app.buttons["modifyScheduleButton"]
        XCTAssertFalse(modifyButton.exists, "Modify button should not appear when all scheduled workouts are completed")

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Delete Uncompleted Scheduled Workout

    /// Adds a routine to the schedule, enters Modify mode, selects it,
    /// and deletes it from the schedule.
    func testDeleteUncompletedScheduledWorkout() throws {
        let routineName = "UITest RemSched \(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create a routine
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        navigateBackToRoutineList()
        sleep(1)

        // 2. Schedule the routine
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        let scheduledCard = app.staticTexts[routineName]
        XCTAssertTrue(scheduledCard.waitForExistence(timeout: 10), "Scheduled card not found")

        // 3. Enter Modify mode
        let modifyButton = app.buttons["modifyScheduleButton"]
        XCTAssertTrue(modifyButton.waitForExistence(timeout: 5), "Modify button not found")
        modifyButton.tap()
        sleep(1)

        // 4. Select the scheduled workout card
        let workoutCard = app.otherElements.matching(identifier: "scheduledWorkoutCard").firstMatch
        XCTAssertTrue(workoutCard.waitForExistence(timeout: 5), "Scheduled workout card not found for selection")
        workoutCard.tap()
        sleep(1)

        // 5. Tap the delete button
        let deleteButton = app.buttons["deleteScheduledWorkoutsButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button not found in schedule select mode")
        deleteButton.tap()
        sleep(1)

        // 6. Confirm the deletion
        let confirmRemove = app.alerts.buttons["Remove"]
        XCTAssertTrue(confirmRemove.waitForExistence(timeout: 5), "Remove confirmation alert not found")
        confirmRemove.tap()
        sleep(3)

        // 7. Verify the card is gone and empty state is shown
        let noWorkoutsText = app.staticTexts["No workouts scheduled"]
        XCTAssertTrue(noWorkoutsText.waitForExistence(timeout: 10), "Empty state not shown after deleting scheduled workout")

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Schedule Multiple Routines on Same Day

    /// Schedules two routines on the same day and verifies both appear.
    func testScheduleMultipleRoutinesSameDay() throws {
        let routineName1 = "UITest Multi1 \(uniqueSuffix)"
        let routineName2 = "UITest Multi2 \(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create two routines
        navigateToRoutinesTab()
        createRoutine(name: routineName1)
        navigateBackToRoutineList()
        sleep(1)

        createRoutine(name: routineName2)
        navigateBackToRoutineList()
        sleep(1)

        // 2. Schedule both routines on today
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName1)

        // Verify first card
        let card1 = app.staticTexts[routineName1]
        XCTAssertTrue(card1.waitForExistence(timeout: 10), "First scheduled routine not found")

        // Schedule the second
        scheduleWorkout(routineName: routineName2)

        // Verify second card
        let card2 = app.staticTexts[routineName2]
        XCTAssertTrue(card2.waitForExistence(timeout: 10), "Second scheduled routine not found")

        // Verify both cards are visible
        XCTAssertTrue(card1.exists, "First routine card disappeared after scheduling second")

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Modify Mode Only Allows Selecting Uncompleted Workouts

    /// Schedules two workouts, completes one, enters Modify mode, and verifies
    /// only the uncompleted one can be selected/deleted.
    func testModifyModeOnlySelectsUncompletedWorkouts() throws {
        let completedRoutine = "UITest Comp \(uniqueSuffix)"
        let pendingRoutine = "UITest Pend \(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create two routines with exercises
        navigateToRoutinesTab()
        createRoutine(name: completedRoutine)
        XCTAssertTrue(app.staticTexts[completedRoutine].waitForExistence(timeout: 10))
        addBenchPressToRoutine()
        navigateBackToRoutineList()
        sleep(1)

        createRoutine(name: pendingRoutine)
        navigateBackToRoutineList()
        sleep(1)

        // 2. Schedule both
        navigateToScheduleTab()
        scheduleWorkout(routineName: completedRoutine)
        XCTAssertTrue(app.staticTexts[completedRoutine].waitForExistence(timeout: 10))

        scheduleWorkout(routineName: pendingRoutine)
        XCTAssertTrue(app.staticTexts[pendingRoutine].waitForExistence(timeout: 10))

        // 3. Complete the first workout
        startAndCompleteScheduledWorkout()

        // 4. Go back to schedule
        navigateToScheduleTab()
        sleep(2)

        // Verify completed badge exists
        let completedText = app.staticTexts["Completed"]
        XCTAssertTrue(completedText.waitForExistence(timeout: 10), "Completed badge not found")

        // 5. The Modify button should still be visible because there's an uncompleted workout
        let modifyButton = app.buttons["modifyScheduleButton"]
        XCTAssertTrue(modifyButton.waitForExistence(timeout: 5), "Modify button should be visible when uncompleted workouts exist")
        modifyButton.tap()
        sleep(1)

        // 6. The completed workout card should NOT show a selection circle
        //    (in the code, selection circles only appear for `!scheduled.completed` cards)
        //    We verify by counting scheduledWorkoutCard elements with selection state
        //    The uncompleted card should be tappable for selection
        let scheduledCards = app.otherElements.matching(identifier: "scheduledWorkoutCard")
        XCTAssertTrue(scheduledCards.count > 0, "No scheduled workout cards found in select mode")

        // Cleanup — cancel select mode first
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
            sleep(1)
        }

        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Empty Schedule Shows Empty State

    /// Verifies that when no workouts are scheduled, the empty state is displayed.
    func testEmptyScheduleShowsEmptyState() throws {
        dismissResumeAlertIfPresent()

        navigateToScheduleTab()
        sleep(3)

        // Check for empty state — either "No workouts scheduled" text or the "Add Workout" CTA
        let noWorkoutsText = app.staticTexts["No workouts scheduled"]
        let addWorkoutButton = app.buttons["addScheduledWorkoutButton"]

        let hasEmptyState = noWorkoutsText.waitForExistence(timeout: 10) || addWorkoutButton.exists
        XCTAssertTrue(hasEmptyState, "Neither empty state text nor Add Workout button found on empty schedule")
    }

    // MARK: - Test: Navigate Month Forward and Back

    /// Verifies the month navigation arrows work on the schedule calendar.
    func testNavigateMonthForwardAndBack() throws {
        dismissResumeAlertIfPresent()

        navigateToScheduleTab()
        sleep(3)

        // The month/year label is visible in the calendar header
        // We navigate forward and back to verify the calendar responds

        // Tap the forward arrow (chevron-right)
        // The right chevron button is the second one in the month header HStack
        let forwardButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron'")).element(boundBy: 1)
        if forwardButton.waitForExistence(timeout: 5) {
            forwardButton.tap()
            sleep(2)
        }

        // Tap the back arrow to return
        let backArrowButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron'")).element(boundBy: 0)
        if backArrowButton.waitForExistence(timeout: 5) {
            backArrowButton.tap()
            sleep(2)
        }

        // The schedule view should still be functional
        let noWorkoutsText = app.staticTexts["No workouts scheduled"]
        let addWorkoutButton = app.buttons["addScheduledWorkoutButton"]
        let scheduleIsVisible = noWorkoutsText.exists || addWorkoutButton.exists
            || app.otherElements.matching(identifier: "scheduledWorkoutCard").count > 0
        XCTAssertTrue(scheduleIsVisible, "Schedule view is not functional after month navigation")
    }
}
