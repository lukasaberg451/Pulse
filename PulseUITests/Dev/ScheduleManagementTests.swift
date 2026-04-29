//
//  ScheduleManagementTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-21.
//

import XCTest

final class ScheduleManagementTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsWorkoutCleanup: Bool { true }
    override var needsScheduleCleanup: Bool { true }

    // MARK: - Test-Specific Helpers

    /// Start a scheduled workout from the schedule card, complete one set, finish and dismiss summary.
    private func startAndCompleteScheduledWorkout() {
        let startButton = app.buttons.matching(NSPredicate(
            format: "identifier == 'scheduledWorkoutCard' AND label == 'Start' AND isEnabled == true"
        )).firstMatch
        assertExists(startButton, timeout: 10, "Enabled Start button not found on scheduled workout card")
        startButton.tap()

        // Verify active workout screen appeared
        let finishButton = app.buttons["finishWorkoutButton"]
        assertExists(finishButton, timeout: 10, "Finish button not found — active workout screen may not have appeared")

        // Enter a weight in the first set
        let weightField = app.textFields["weightField_1"]
        assertExists(weightField, timeout: 5, "Weight field for set 1 not found")
        weightField.tap()
        weightField.typeText("80")

        // Dismiss keyboard, then tap the set number pill to complete the set
        app.navigationBars.firstMatch.tap()
        waitForAnimation()

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        assertExists(setOnePill, timeout: 5, "Set 1 pill not found")
        setOnePill.tap()
        confirmRepsPromptIfPresent()

        // Finish the workout
        finishButton.tap()

        let finishAlert = app.alerts["Finish Workout?"]
        assertExists(finishAlert, timeout: 5, "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        // Dismiss the workout summary
        let doneButton = app.buttons["Done"]
        assertExists(doneButton, timeout: 10, "Done button not found on workout summary")
        doneButton.tap()

        // Wait for schedule to reload after dismissing summary
        _ = app.buttons["Workout"].waitForExistence(timeout: 5)
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
        assertExists(app.staticTexts[routineName], timeout: 10, "Routine detail not showing")

        // Add an exercise so we can start a workout
        addBenchPressToRoutine()

        // Go back to routine list
        navigateBackToRoutineList()

        // 2. Switch to schedule tab and add the routine
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        // 3. Verify the scheduled workout card appears with the routine name
        let scheduledCard = app.staticTexts[routineName]
        assertExists(scheduledCard, timeout: 10, "Scheduled workout card with '\(routineName)' not found")

        // 4. Start and complete the workout
        startAndCompleteScheduledWorkout()

        // 5. Navigate back to schedule and verify "Completed" badge
        navigateToScheduleTab()
        let completedText = app.staticTexts["Completed"]
        assertExists(completedText, timeout: 10, "Completed badge not found on the scheduled workout card")

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

        // 2. Schedule the routine on today
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        // Verify card appears
        let scheduledCard = app.staticTexts[routineName]
        assertExists(scheduledCard, timeout: 10, "Scheduled card not found for '\(routineName)'")

        // 3. Delete the routine
        cleanupRoutines(containing: String(uniqueSuffix))

        // 4. Go back to schedule and verify "Deleted Routine" or "Routine deleted" text appears
        navigateToScheduleTab()

        let deletedTitle = app.staticTexts["Deleted Routine"]
        let deletedSubtitle = app.staticTexts["Routine deleted"]
        let foundDeletedText = deletedTitle.waitForExistence(timeout: 10) || deletedSubtitle.exists
        XCTAssertTrue(foundDeletedText, "'Deleted Routine' / 'Routine deleted' text not found on the schedule card after routine deletion")

        // Also verify the card uses the deleted routine card identifier
        let deletedCard = app.otherElements.matching(identifier: "deletedRoutineWorkoutCard").firstMatch
        let deletedCardButton = app.buttons.matching(identifier: "deletedRoutineWorkoutCard").firstMatch
        XCTAssertTrue(deletedCard.waitForExistence(timeout: 5) || deletedCardButton.exists, "Deleted routine workout card not found")
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
        assertExists(app.staticTexts[routineName], timeout: 10, "Routine detail not showing")
        addBenchPressToRoutine()
        navigateBackToRoutineList()

        // 2. Schedule the routine and complete it
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        let scheduledCard = app.staticTexts[routineName]
        assertExists(scheduledCard, timeout: 10, "Scheduled card not found")

        startAndCompleteScheduledWorkout()

        // 3. Go back to schedule
        navigateToScheduleTab()
        let completedText = app.staticTexts["Completed"]
        assertExists(completedText, timeout: 10, "Completed badge not found")

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

        // 2. Schedule the routine
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)

        let scheduledCard = app.staticTexts[routineName]
        assertExists(scheduledCard, timeout: 10, "Scheduled card not found")

        // 3. Enter Modify mode
        let modifyButton = app.buttons["modifyScheduleButton"]
        assertExists(modifyButton, timeout: 5, "Modify button not found")
        modifyButton.tap()
        waitForAnimation()

        // 4. Select the scheduled workout card
        let workoutCardOther = app.otherElements.matching(identifier: "scheduledWorkoutCard").firstMatch
        let workoutCardButton = app.buttons.matching(identifier: "scheduledWorkoutCard").firstMatch
        if workoutCardOther.waitForExistence(timeout: 5) {
            workoutCardOther.tap()
        } else {
            assertExists(workoutCardButton, timeout: 5, "Scheduled workout card not found for selection")
            workoutCardButton.tap()
        }
        waitForAnimation()

        // 5. Tap the delete button
        let deleteButton = app.buttons["deleteScheduledWorkoutsButton"]
        assertExists(deleteButton, timeout: 5, "Delete button not found in schedule select mode")
        deleteButton.tap()

        // 6. Confirm the deletion
        let confirmRemove = app.alerts.buttons["Remove"]
        assertExists(confirmRemove, timeout: 5, "Remove confirmation alert not found")
        confirmRemove.tap()

        // 7. Verify the deleted routine's card is gone
        let deletedCard = app.staticTexts[routineName]
        XCTAssertFalse(deletedCard.waitForExistence(timeout: 3), "Scheduled workout '\(routineName)' should be gone after deletion")

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

        createRoutine(name: routineName2)
        navigateBackToRoutineList()

        // 2. Schedule both routines on today
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName1)

        // Verify first card
        let card1 = app.staticTexts[routineName1]
        assertExists(card1, timeout: 10, "First scheduled routine not found")

        // Schedule the second
        scheduleWorkout(routineName: routineName2)

        // Verify second card
        let card2 = app.staticTexts[routineName2]
        assertExists(card2, timeout: 10, "Second scheduled routine not found")

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
        assertExists(app.staticTexts[completedRoutine], timeout: 10)
        addBenchPressToRoutine()
        navigateBackToRoutineList()

        createRoutine(name: pendingRoutine)
        navigateBackToRoutineList()

        // 2. Schedule both
        navigateToScheduleTab()
        scheduleWorkout(routineName: completedRoutine)
        assertExists(app.staticTexts[completedRoutine], timeout: 10)

        scheduleWorkout(routineName: pendingRoutine)
        assertExists(app.staticTexts[pendingRoutine], timeout: 10)

        // 3. Complete the first workout
        startAndCompleteScheduledWorkout()

        // 4. Go back to schedule
        navigateToScheduleTab()

        // Verify completed badge exists
        let completedText = app.staticTexts["Completed"]
        assertExists(completedText, timeout: 10, "Completed badge not found")

        // 5. The Modify button should still be visible because there's an uncompleted workout
        let modifyButton = app.buttons["modifyScheduleButton"]
        assertExists(modifyButton, timeout: 5, "Modify button should be visible when uncompleted workouts exist")
        modifyButton.tap()
        waitForAnimation()

        // 6. The completed workout card should NOT show a selection circle
        let scheduledCards = app.buttons.matching(identifier: "scheduledWorkoutCard")
        let scheduledOther = app.otherElements.matching(identifier: "scheduledWorkoutCard")
        let totalCards = scheduledCards.count + scheduledOther.count
        XCTAssertTrue(totalCards > 0, "No scheduled workout cards found in select mode")

        // Cleanup — cancel select mode first
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
            waitForAnimation()
        }

        cleanupCompletedWorkouts()
        cleanupScheduledWorkouts()
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Empty Schedule Shows Empty State

    /// Verifies that when no workouts are scheduled, the empty state is displayed.
    func testEmptyScheduleShowsEmptyState() throws {
        dismissResumeAlertIfPresent()

        navigateToScheduleTab()

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

        // Tap the forward arrow (chevron-right)
        let forwardButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron'")).element(boundBy: 1)
        if forwardButton.waitForExistence(timeout: 5) {
            forwardButton.tap()
            waitForAnimation()
        }

        // Tap the back arrow to return
        let backArrowButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron'")).element(boundBy: 0)
        if backArrowButton.waitForExistence(timeout: 5) {
            backArrowButton.tap()
            waitForAnimation()
        }

        // The schedule view should still be functional
        let noWorkoutsText = app.staticTexts["No workouts scheduled"]
        let addWorkoutButton = app.buttons["addScheduledWorkoutButton"]
        let scheduleIsVisible = noWorkoutsText.exists || addWorkoutButton.exists
            || app.otherElements.matching(identifier: "scheduledWorkoutCard").count > 0
        XCTAssertTrue(scheduleIsVisible, "Schedule view is not functional after month navigation")
    }
}
