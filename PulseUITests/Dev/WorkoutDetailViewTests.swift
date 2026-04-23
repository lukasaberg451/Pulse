//
//  WorkoutDetailViewTests.swift
//  PulseUITests
//
//  Tests for viewing workout details after completing a workout.
//

import XCTest

final class WorkoutDetailViewTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsWorkoutCleanup: Bool { true }
    override var needsScheduleCleanup: Bool { true }

    // MARK: - Test-Specific Helpers

    /// Start a scheduled workout, complete one set, finish and dismiss summary.
    private func completeWorkoutWithOneSet() {
        let startButton = app.buttons.matching(NSPredicate(
            format: "identifier == 'scheduledWorkoutCard' AND label == 'Start'"
        )).firstMatch
        assertExists(startButton, timeout: 10, "Start button not found")
        startButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        assertExists(finishButton, timeout: 10, "Finish button not found")

        let weightField = app.textFields["weightField_1"]
        assertExists(weightField, timeout: 5, "Weight field not found")
        weightField.tap()
        weightField.typeText("80")

        app.navigationBars.firstMatch.tap()
        waitForAnimation()

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        assertExists(setOnePill, timeout: 5, "Set 1 pill not found")
        setOnePill.tap()
        waitForAnimation()

        finishButton.tap()

        let finishAlert = app.alerts["Finish Workout?"]
        assertExists(finishAlert, timeout: 5, "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        let doneButton = app.buttons["Done"]
        assertExists(doneButton, timeout: 10, "Done button not found on summary")
        doneButton.tap()

        // Wait for schedule to reload after dismissing summary
        _ = app.buttons["Workout"].waitForExistence(timeout: 5)
    }

    // MARK: - Test: Tap Completed Workout to View Details

    /// Creates a routine, schedules it, completes the workout, then taps the
    /// completed card on the schedule to open the workout detail view and
    /// verifies key elements (duration, total sets, volume, exercises section).
    func testTapCompletedWorkoutShowsDetail() throws {
        let routineName = "UITest Detail \(uniqueSuffix)"

        dismissResumeAlertIfPresent()

        // 1. Create routine with exercise
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        assertExists(app.staticTexts[routineName], timeout: 10)
        addBenchPressToRoutine()
        navigateBackToRoutineList()

        // 2. Schedule and complete
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)
        assertExists(app.staticTexts[routineName], timeout: 10)
        completeWorkoutWithOneSet()

        // 3. Navigate back to schedule and tap the completed card
        navigateToScheduleTab()
        let completedText = app.staticTexts["Completed"]
        assertExists(completedText, timeout: 10, "Completed badge not found")

        // Tap the completed workout card — it's a NavigationLink (button), not otherElement
        let completedCard = app.buttons.matching(identifier: "scheduledWorkoutCard").firstMatch
        assertExists(completedCard, timeout: 5, "Completed workout card not found")
        completedCard.tap()

        // 4. Verify workout detail view elements
        let workoutTitle = app.staticTexts[routineName]
        assertExists(workoutTitle, timeout: 10, "Workout name '\(routineName)' not found on detail view")

        let durationLabel = app.staticTexts["Duration"]
        assertExists(durationLabel, timeout: 5, "'Duration' stat not found")

        let totalSetsLabel = app.staticTexts["Total Sets"]
        assertExists(totalSetsLabel, timeout: 5, "'Total Sets' stat not found")

        let volumeLabel = app.staticTexts["Volume"]
        assertExists(volumeLabel, timeout: 5, "'Volume' stat not found")

        let exercisesHeader = app.staticTexts["Exercises"]
        assertExists(exercisesHeader, timeout: 5, "'Exercises' section header not found")

        // Verify Bench Press appears in the exercises list
        let benchPress = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        assertExists(benchPress, timeout: 5, "Bench Press not found in workout detail exercises")

        // 5. Delete the workout from the detail view
        let deleteButton = app.buttons["deleteWorkoutButton"]
        assertExists(deleteButton, timeout: 5, "Delete workout button not found")
        deleteButton.tap()

        let deleteAlert = app.alerts["Delete Workout"]
        assertExists(deleteAlert, timeout: 5, "Delete Workout confirmation alert not found")
        deleteAlert.buttons["Delete"].tap()

        // Verify we navigated back to the schedule after deletion
        let scheduleButton = app.buttons["Schedule"]
        assertExists(scheduleButton, timeout: 10, "Did not return to schedule after deleting workout")

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
    }
}
