//
//  DiscardWorkoutTests.swift
//  PulseUITests
//
//  Tests for starting and discarding a workout without completing it.
//

import XCTest

final class DiscardWorkoutTests: XCTestCase {

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

    private func createRoutineAndStartWorkout() {
        let routineName = "UITest DW \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10))
        addBenchPressToRoutine()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found")
        startButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout screen did not appear")
    }

    // MARK: - Test: Cancel Workout via Cancel Button

    /// Starts a workout from the first routine, taps Cancel, confirms Discard,
    /// and verifies we return to the workout screen without the workout being saved.
    func testDiscardWorkoutViaCancelButton() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        // Tap Cancel
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Cancel button not found on active workout")
        cancelButton.tap()

        // Confirm the "Cancel Workout?" alert
        let cancelAlert = app.alerts["Cancel Workout?"]
        XCTAssertTrue(cancelAlert.waitForExistence(timeout: 5), "Cancel Workout alert not found")

        let discardButton = cancelAlert.buttons["Discard"]
        XCTAssertTrue(discardButton.exists, "Discard button not found in cancel alert")
        discardButton.tap()
        sleep(2)

        // Verify we returned to the workout view (tab should still be visible)
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10), "Did not return to workout screen after discarding")
    }

    // MARK: - Test: Cancel Alert Continue Keeps Workout Active

    /// Starts a workout, taps Cancel, then taps "Continue Workout" and
    /// verifies the workout is still active.
    func testCancelAlertContinueKeepsWorkoutActive() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        let finishButton = app.buttons["finishWorkoutButton"]

        // Tap Cancel
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Cancel button not found")
        cancelButton.tap()

        // Tap "Continue Workout" to stay in the workout
        let cancelAlert = app.alerts["Cancel Workout?"]
        XCTAssertTrue(cancelAlert.waitForExistence(timeout: 5), "Cancel Workout alert not found")

        let continueButton = cancelAlert.buttons["Continue Workout"]
        XCTAssertTrue(continueButton.exists, "Continue Workout button not found")
        continueButton.tap()
        sleep(1)

        // Verify we're still on the active workout screen
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5), "Should still be on active workout after choosing Continue")

        // Cleanup — discard the workout
        cancelButton.tap()
        let discardButton = app.alerts["Cancel Workout?"].buttons["Discard"]
        if discardButton.waitForExistence(timeout: 5) {
            discardButton.tap()
        }
        sleep(2)
    }

    // MARK: - Test: Finish With No Completed Sets Shows Empty Finish Alert

    /// Starts a workout, taps Finish without completing any sets,
    /// and verifies the "No Sets Completed" alert appears.
    func testFinishWithNoSetsShowsEmptyFinishAlert() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        let finishButton = app.buttons["finishWorkoutButton"]

        // Tap Finish without completing any sets
        finishButton.tap()

        // Verify "No Sets Completed" alert appears
        let emptyAlert = app.alerts["No Sets Completed"]
        XCTAssertTrue(emptyAlert.waitForExistence(timeout: 5), "No Sets Completed alert did not appear")

        let discardButton = emptyAlert.buttons["Discard"]
        XCTAssertTrue(discardButton.exists, "Discard button not found in empty finish alert")

        let continueButton = emptyAlert.buttons["Continue Workout"]
        XCTAssertTrue(continueButton.exists, "Continue Workout button not found in empty finish alert")

        // Discard to clean up
        discardButton.tap()
        sleep(2)
    }
}
