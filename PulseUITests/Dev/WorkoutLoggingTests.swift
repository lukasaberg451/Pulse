//
//  WorkoutLoggingTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-20.
//

import XCTest

final class WorkoutLoggingTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsWorkoutCleanup: Bool { true }

    func testStartAndCompleteWorkout() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        let finishButton = app.buttons["finishWorkoutButton"]

        // Enter a weight in the first set's weight field
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

        // Tap "Finish" to end the workout
        finishButton.tap()

        // Confirm the "Finish Workout?" alert
        let finishAlert = app.alerts["Finish Workout?"]
        assertExists(finishAlert, timeout: 5, "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        // Dismiss the workout summary screen
        let doneButton = app.buttons["Done"]
        assertExists(doneButton, timeout: 10, "Done button not found on workout summary")
        doneButton.tap()

        // Verify we're back on the workout tab
        let workoutTab = app.buttons["Workout"]
        assertExists(workoutTab, timeout: 10, "Did not return to workout screen after finishing")
    }
}
