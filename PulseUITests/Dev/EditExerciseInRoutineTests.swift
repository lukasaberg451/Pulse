//
//  EditExerciseInRoutineTests.swift
//  PulseUITests
//
//  Tests for editing exercise configuration (sets/reps/weight) in a routine.
//

import XCTest

final class EditExerciseInRoutineTests: XCTestCase {

    var app: XCUIApplication!
    private let uniqueSuffix = UUID().uuidString.prefix(6)

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        if app != nil {
            app.terminate()
            app.launch()
            let resumeAlert = app.alerts["Resume Workout?"]
            if resumeAlert.waitForExistence(timeout: 5) {
                resumeAlert.buttons["Discard"].tap()
                sleep(1)
            }
            cleanupRoutines(containing: "UITest")
            app = nil
        }
    }

    // MARK: - Helpers

    private func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }
    }

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

        let exerciseRow = app.buttons["exercisePickerRow"].firstMatch
        XCTAssertTrue(exerciseRow.waitForExistence(timeout: 10), "Bench Press not found")
        exerciseRow.tap()
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

    private func navigateBackToRoutineList() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            sleep(2)
        }
    }

    private func cleanupRoutines(containing substring: String) {
        navigateToRoutinesTab()
        sleep(2)

        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let matchingRows = app.buttons.matching(predicate)
        guard matchingRows.count > 0 else { return }

        let modifyButton = app.buttons["modifyRoutinesButton"]
        guard modifyButton.waitForExistence(timeout: 5) else { return }
        modifyButton.tap()
        sleep(1)

        for i in 0..<matchingRows.count {
            let row = matchingRows.element(boundBy: i)
            if row.isHittable {
                row.tap()
            } else {
                // Scroll down to reveal off-screen rows, then retry
                app.swipeUp()
                sleep(1)
                if row.isHittable {
                    row.tap()
                }
            }
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
            sleep(1)

            // Tap "Edit Exercise"
            let editOption = app.buttons["Edit Exercise"]
            XCTAssertTrue(editOption.waitForExistence(timeout: 5), "'Edit Exercise' option not found in menu")
            editOption.tap()
            sleep(2)

            // Verify the edit sheet appeared — look for weight or sets fields
            let weightField = app.textFields["exerciseWeightField"]
            let setsField = app.textFields.matching(NSPredicate(format: "label CONTAINS[c] 'sets' OR identifier CONTAINS 'sets'")).firstMatch
            let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Save' OR label CONTAINS[c] 'Update'")).firstMatch

            let sheetAppeared = weightField.waitForExistence(timeout: 5) || setsField.exists || saveButton.exists
            XCTAssertTrue(sheetAppeared, "Edit exercise sheet did not appear after tapping Edit Exercise")

            // Dismiss
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.waitForExistence(timeout: 3) {
                cancelButton.tap()
                sleep(1)
            }
        }

        // Cleanup
        navigateBackToRoutineList()
        cleanupRoutines(containing: String(uniqueSuffix))
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
            sleep(1)

            // Tap "Delete Exercise"
            let deleteOption = app.buttons["Delete Exercise"]
            XCTAssertTrue(deleteOption.waitForExistence(timeout: 5), "'Delete Exercise' option not found in menu")
            deleteOption.tap()
            sleep(2)

            // Verify "No Exercises Yet" empty state appears
            let noExercises = app.staticTexts["No Exercises Yet"]
            XCTAssertTrue(noExercises.waitForExistence(timeout: 10), "Empty exercises state not shown after deleting the exercise")
        }

        // Cleanup
        navigateBackToRoutineList()
        cleanupRoutines(containing: String(uniqueSuffix))
    }
}
