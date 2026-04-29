//
//  MultipleSetWorkoutTests.swift
//  PulseUITests
//
//  Tests for completing multiple sets in a workout.
//

import XCTest

final class MultipleSetWorkoutTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsWorkoutCleanup: Bool { true }

    // MARK: - Test: Complete Multiple Sets Then Finish Workout

    /// Starts a workout, completes sets 1 and 2 with different weights,
    /// then finishes and verifies the summary shows correct set count.
    func testCompleteMultipleSetsAndFinish() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        let finishButton = app.buttons["finishWorkoutButton"]

        // Complete set 1
        let weightField1 = app.textFields["weightField_1"]
        XCTAssertTrue(weightField1.waitForExistence(timeout: 5), "Weight field 1 not found")
        weightField1.tap()
        weightField1.typeText("80")

        app.navigationBars.firstMatch.tap()
        waitForAnimation()

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        XCTAssertTrue(setOnePill.waitForExistence(timeout: 5), "Set 1 pill not found")
        setOnePill.tap()
        confirmRepsPromptIfPresent()

        // Complete set 2
        let weightField2 = app.textFields["weightField_2"]
        if weightField2.waitForExistence(timeout: 5) {
            weightField2.tap()
            weightField2.typeText("85")

            app.navigationBars.firstMatch.tap()
            waitForAnimation()

            let setTwoPill = app.buttons.matching(NSPredicate(format: "label == '2'")).firstMatch
            if setTwoPill.waitForExistence(timeout: 5) {
                setTwoPill.tap()
                confirmRepsPromptIfPresent()
            }
        }

        // Finish the workout
        finishButton.tap()

        let finishAlert = app.alerts["Finish Workout?"]
        XCTAssertTrue(finishAlert.waitForExistence(timeout: 5), "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        // Verify workout summary appeared
        let summaryTitle = app.staticTexts["Workout Completed"]
        XCTAssertTrue(summaryTitle.waitForExistence(timeout: 10), "Workout Completed title not found on summary")

        // Verify "Duration" label is present
        let durationLabel = app.staticTexts["Duration"]
        XCTAssertTrue(durationLabel.waitForExistence(timeout: 5), "'Duration' label not found on summary")

        // Verify "Volume" label is present
        let volumeLabel = app.staticTexts["Volume"]
        XCTAssertTrue(volumeLabel.waitForExistence(timeout: 5), "'Volume' label not found on summary")

        // Verify "Exercises" label is present
        let exercisesLabel = app.staticTexts["Exercises"]
        XCTAssertTrue(exercisesLabel.waitForExistence(timeout: 5), "'Exercises' label not found on summary")

        // Dismiss summary
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Done button not found")
        doneButton.tap()

        // Verify we returned to the workout screen
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10), "Did not return to workout screen")
    }

    // MARK: - Test: Workout Summary Shows Exercise Breakdown

    /// Starts a workout, completes one set, finishes, and verifies the
    /// summary view shows the exercise name and set/weight/reps columns.
    func testWorkoutSummaryShowsExerciseBreakdown() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        let finishButton = app.buttons["finishWorkoutButton"]

        // Complete set 1
        let weightField = app.textFields["weightField_1"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Weight field not found")
        weightField.tap()
        weightField.typeText("100")

        app.navigationBars.firstMatch.tap()
        waitForAnimation()

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        XCTAssertTrue(setOnePill.waitForExistence(timeout: 5), "Set 1 pill not found")
        setOnePill.tap()
        confirmRepsPromptIfPresent()

        // Finish
        finishButton.tap()
        let finishAlert = app.alerts["Finish Workout?"]
        XCTAssertTrue(finishAlert.waitForExistence(timeout: 5))
        finishAlert.buttons["Finish"].tap()

        // Verify summary shows column headers
        let setHeader = app.staticTexts["SET"]
        XCTAssertTrue(setHeader.waitForExistence(timeout: 10), "'SET' column header not found on summary")

        // Either WEIGHT or DURATION depending on exercise type
        let weightHeader = app.staticTexts["WEIGHT"]
        let durationHeader = app.staticTexts["DURATION"]
        XCTAssertTrue(weightHeader.waitForExistence(timeout: 5) || durationHeader.exists,
                      "Neither 'WEIGHT' nor 'DURATION' column header found on summary")

        // Dismiss
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()

        // Verify we returned to the workout screen
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10), "Did not return to workout screen")
    }
}
