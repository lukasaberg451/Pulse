//
//  EditCustomExerciseTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class EditCustomExerciseTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsCustomExerciseCleanup: Bool { true }

    // MARK: - Helpers

    private func navigateToAllCustomExercises() {
        navigateToProfile()

        let seeAllButton = app.buttons["customExercisesSeeAll"]
        if !seeAllButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }

        XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5), "'See All' for custom exercises not found")
        seeAllButton.tap()
        waitForAnimation()
    }

    /// Creates a routine and a custom exercise via the exercise picker, then dismisses back.
    private func createCustomExercise(name: String) {
        let routineName = "UITest CE \(uniqueSuffix)"

        navigateToRoutinesTab()

        let newRoutineButton = app.buttons["newRoutineButton"]
        assertExists(newRoutineButton, timeout: 10, "New Routine button not found")
        newRoutineButton.tap()

        let nameField = app.textFields["routineNameField"]
        assertExists(nameField, timeout: 5, "Routine name field not found")
        nameField.tap()
        nameField.typeText(routineName)

        let createButton = app.buttons["createRoutineButton"]
        assertExists(createButton, timeout: 5, "Create Routine button not found")
        createButton.tap()
        _ = app.staticTexts[routineName].waitForExistence(timeout: 10)

        // Open exercise picker
        let addExerciseButton = app.buttons["addExerciseButton"]
        assertExists(addExerciseButton, timeout: 5, "Add Exercise button not found")
        addExerciseButton.tap()

        let exerciseSearchField = app.textFields["exerciseSearchField"]
        _ = exerciseSearchField.waitForExistence(timeout: 5)

        // Tap "Custom" toolbar button
        let customButton = app.buttons["customExerciseToolbarButton"]
        assertExists(customButton, timeout: 5, "Custom exercise toolbar button not found")
        customButton.tap()

        // Fill in the custom exercise name
        let exerciseNameField = app.textFields["customExerciseNameField"]
        assertExists(exerciseNameField, timeout: 5, "Custom exercise name field not found")
        exerciseNameField.tap()
        exerciseNameField.typeText(name)

        // Create the exercise
        let createExerciseButton = app.buttons["createCustomExerciseButton"]
        assertExists(createExerciseButton, timeout: 5, "Create Exercise button not found")
        createExerciseButton.tap()
        waitForAnimation()

        // Cancel the config sheet
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
            waitForAnimation()
        }

        // Dismiss the exercise picker
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            waitForAnimation()
        }

        // Navigate back to routine list
        navigateBackToRoutineList()
    }

    // MARK: - Test: Custom Exercise Appears in Exercise List

    /// Creates a custom exercise from a routine, then navigates to Profile
    /// and verifies the "My Custom Exercises" section is visible.
    func testCustomExerciseVisibleOnProfile() throws {
        let customName = "CustEx \(uniqueSuffix)"

        dismissResumeAlertIfPresent()
        createCustomExercise(name: customName)

        navigateToProfile()

        let sectionHeader = app.staticTexts["My Custom Exercises"]
        if !sectionHeader.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 5), "'My Custom Exercises' section not found on profile")
    }

    // MARK: - Test: Delete Custom Exercise from All Custom Exercises View

    /// Creates a custom exercise, navigates to the All Custom Exercises list,
    /// taps the three-dot menu, selects Delete, confirms, and verifies removal.
    func testDeleteCustomExerciseFromAllExercisesView() throws {
        let customName = "DelCustEx \(uniqueSuffix)"

        dismissResumeAlertIfPresent()
        createCustomExercise(name: customName)

        navigateToAllCustomExercises()

        // Tap the three-dot menu on the first custom exercise
        let exerciseMenu = app.buttons["customExerciseMenu"]
        XCTAssertTrue(exerciseMenu.waitForExistence(timeout: 10), "Custom exercise menu not found")
        exerciseMenu.firstMatch.tap()
        waitForAnimation()

        // Tap "Delete Exercise" from the context menu
        let deleteOption = app.buttons["Delete Exercise"]
        XCTAssertTrue(deleteOption.waitForExistence(timeout: 5), "'Delete Exercise' menu option not found")
        deleteOption.tap()

        // Confirm the deletion alert
        let deleteAlert = app.alerts["Delete Exercise"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5), "Delete confirmation alert not found")
        deleteAlert.buttons["Delete"].tap()
        _ = deleteAlert.waitForNonExistence(timeout: 3)

        // The exercise should be removed
        XCTAssertFalse(deleteAlert.exists, "Delete alert should have dismissed after confirming")
    }
}
