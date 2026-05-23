//
//  EditExerciseInRoutineTests.swift
//  PulseUITests
//
//  Tests for editing exercise configuration (sets/reps/weight) in a routine.
//

import XCTest

final class EditExerciseInRoutineTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }

    // MARK: - Test: Edit Exercise Opens Edit Sheet

    /// Creates a routine with an exercise, taps the three-dot menu on the
    /// exercise, taps "Edit Exercise", and verifies the edit sheet appears.
    func testEditExerciseOpensEditSheet() throws {
        let routineName = "UITest EditEx \(uniqueSuffix)"

        dismissResumeAlertIfPresent()
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10))
        addBenchPressToRoutine()

        // Verify exercise appears in the routine
        let benchPress = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchPress.waitForExistence(timeout: 10), "Bench Press not found in routine")

        // Tap the three-dot menu on the exercise row
        let menuButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ellipsis' OR label CONTAINS 'More'")).firstMatch
        if menuButton.waitForExistence(timeout: 5) {
            menuButton.tap()
            waitForAnimation()

            // Tap "Edit Exercise"
            let editOption = app.buttons["Edit Exercise"]
            XCTAssertTrue(editOption.waitForExistence(timeout: 5), "'Edit Exercise' option not found in menu")
            editOption.tap()

            // Verify the edit sheet appeared - look for weight or sets fields
            let weightField = app.textFields["exerciseWeightField"]
            let setsField = app.textFields.matching(NSPredicate(format: "label CONTAINS[c] 'sets' OR identifier CONTAINS 'sets'")).firstMatch
            let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Save' OR label CONTAINS[c] 'Update'")).firstMatch

            let sheetAppeared = weightField.waitForExistence(timeout: 5) || setsField.exists || saveButton.exists
            XCTAssertTrue(sheetAppeared, "Edit exercise sheet did not appear after tapping Edit Exercise")

            // Dismiss
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.waitForExistence(timeout: 3) {
                cancelButton.tap()
                waitForAnimation()
            }
        }

        // Cleanup
        navigateBackToRoutineList()
    }

    // MARK: - Test: Delete Exercise From Routine

    /// Creates a routine with an exercise, taps the three-dot menu,
    /// taps "Delete Exercise", and verifies the exercise is removed.
    func testDeleteExerciseFromRoutine() throws {
        let routineName = "UITest DelExR \(uniqueSuffix)"

        dismissResumeAlertIfPresent()
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10))
        addBenchPressToRoutine()

        // Verify exercise exists
        let benchPress = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchPress.waitForExistence(timeout: 10), "Bench Press not found in routine")

        // Tap the three-dot menu
        let menuButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ellipsis' OR label CONTAINS 'More'")).firstMatch
        if menuButton.waitForExistence(timeout: 5) {
            menuButton.tap()
            waitForAnimation()

            // Tap "Delete Exercise"
            let deleteOption = app.buttons["Delete Exercise"]
            XCTAssertTrue(deleteOption.waitForExistence(timeout: 5), "'Delete Exercise' option not found in menu")
            deleteOption.tap()

            // Verify "No Exercises Yet" empty state appears
            let noExercises = app.staticTexts["No Exercises Yet"]
            XCTAssertTrue(noExercises.waitForExistence(timeout: 10), "Empty exercises state not shown after deleting the exercise")
        }

        // Cleanup
        navigateBackToRoutineList()
    }
}
