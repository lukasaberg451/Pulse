//
//  BodyweightExerciseTests.swift
//  PulseUITests
//
//  Verifies the bodyweight exercise type:
//  - Custom-creation flow lets the user pick the bodyweight type
//  - Routine config sheet hides the weight field for bodyweight exercises
//  - Active workout set row shows reps only (no weight field) for bodyweight
//

import XCTest

final class BodyweightExerciseTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsWorkoutCleanup: Bool { true }
    override var needsCustomExerciseCleanup: Bool { true }

    // MARK: - Helpers

    /// Creates a custom exercise of the given type via the routine's exercise picker.
    /// After creation, the config sheet for the new exercise is left open.
    private func createCustomBodyweightExercise(name: String) {
        let routineName = "UITest BW \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)
        assertExists(app.staticTexts[routineName], timeout: 10)

        // Open the exercise picker
        let addExerciseButton = app.buttons["addExerciseButton"]
        assertExists(addExerciseButton, timeout: 5, "Add Exercise button not found")
        addExerciseButton.tap()

        let exerciseSearchField = app.textFields["exerciseSearchField"]
        _ = exerciseSearchField.waitForExistence(timeout: 5)

        // Open the create-custom sheet
        let customButton = app.buttons["customExerciseToolbarButton"]
        assertExists(customButton, timeout: 5, "Custom exercise toolbar button not found")
        customButton.tap()

        // Name
        let exerciseNameField = app.textFields["customExerciseNameField"]
        assertExists(exerciseNameField, timeout: 5, "Custom exercise name field not found")
        exerciseNameField.tap()
        exerciseNameField.typeText(name)

        // Pick the Bodyweight segment
        let typePicker = app.segmentedControls.firstMatch
        assertExists(typePicker, timeout: 5, "Exercise type segmented picker not found")
        let bodyweightSegment = typePicker.buttons["Bodyweight"]
        assertExists(bodyweightSegment, timeout: 5, "Bodyweight segment not found in picker")
        bodyweightSegment.tap()
        XCTAssertTrue(bodyweightSegment.isSelected, "Bodyweight segment did not become selected")

        // Create
        let createExerciseButton = app.buttons["createCustomExerciseButton"]
        assertExists(createExerciseButton, timeout: 5, "Create Exercise button not found")
        createExerciseButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Config sheet hides the weight field

    /// Creates a bodyweight custom exercise and verifies the routine config sheet
    /// (which appears after creation) does not show the weight TextField.
    func testBodyweightExerciseConfigSheetHidesWeightField() throws {
        let customName = "BW Test \(uniqueSuffix)"

        dismissResumeAlertIfPresent()
        createCustomBodyweightExercise(name: customName)

        // Config sheet should be visible - reps field exists, weight field does NOT
        let configTitle = app.navigationBars["Configure Exercise"]
        assertExists(configTitle, timeout: 5, "Configure Exercise sheet did not appear")

        let weightField = app.textFields["exerciseWeightField"]
        XCTAssertFalse(
            weightField.waitForExistence(timeout: 2),
            "Weight field should be hidden for bodyweight exercises"
        )
    }

    // MARK: - Test: Active workout set row hides the weight field

    /// Creates a bodyweight exercise, adds it to a routine, starts a workout,
    /// and verifies the set row does not show a weight TextField.
    func testBodyweightExerciseActiveWorkoutHidesWeightField() throws {
        let customName = "BW Live \(uniqueSuffix)"

        dismissResumeAlertIfPresent()
        createCustomBodyweightExercise(name: customName)

        // Add the exercise to the routine (config sheet is already open)
        let addButton = app.buttons["addExerciseToRoutineButton"]
        assertExists(addButton, timeout: 5, "Add to routine button not found")
        addButton.tap()

        // Dismiss the exercise picker if still visible
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            waitForAnimation()
        }

        // Wait for the exercise to appear in the routine
        let exerciseLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", customName)
        ).firstMatch
        assertExists(exerciseLabel, timeout: 10, "Bodyweight exercise did not appear in routine")

        // Start the workout
        let startWorkoutButton = app.buttons["startWorkoutButton"]
        assertExists(startWorkoutButton, timeout: 10, "Start Workout button not found")
        startWorkoutButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        assertExists(finishButton, timeout: 10, "Active workout screen did not appear")

        // The weight field for set 1 should NOT exist
        let weightField = app.textFields["weightField_1"]
        XCTAssertFalse(
            weightField.waitForExistence(timeout: 3),
            "Weight field should not appear in active workout for bodyweight exercise"
        )

        // Discard the workout to clean up
        discardActiveWorkout()
    }
}
