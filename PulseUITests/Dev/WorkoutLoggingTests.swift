//
//  WorkoutLoggingTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-20.
//

import XCTest

final class WorkoutLoggingTests: XCTestCase {

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
            cleanupCompletedWorkouts()
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

        // Tap the exercise row using its accessibility identifier
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

    private func cleanupCompletedWorkouts() {
        navigateToScheduleTab()
        sleep(2)

        while true {
            let completedCard = app.buttons.matching(NSPredicate(
                format: "identifier == 'scheduledWorkoutCard' AND label CONTAINS 'Completed'"
            )).firstMatch
            guard completedCard.waitForExistence(timeout: 3), completedCard.isHittable else { break }
            completedCard.tap()
            sleep(2)

            let deleteButton = app.buttons["deleteWorkoutButton"]
            guard deleteButton.waitForExistence(timeout: 3) else {
                let back = app.navigationBars.buttons.element(boundBy: 0)
                if back.exists { back.tap() }
                sleep(1)
                break
            }
            deleteButton.tap()

            let confirmDelete = app.alerts.buttons["Delete"]
            if confirmDelete.waitForExistence(timeout: 3) {
                confirmDelete.tap()
                sleep(2)
            }
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

    /// Creates a routine with an exercise and starts the workout, returning to the active workout screen.
    private func createRoutineAndStartWorkout() {
        let routineName = "UITest WL \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10))
        addBenchPressToRoutine()

        let startWorkoutButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startWorkoutButton.waitForExistence(timeout: 10), "Start Workout button not found")
        startWorkoutButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout screen did not appear")
    }

    func testStartAndCompleteWorkout() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        let finishButton = app.buttons["finishWorkoutButton"]

        // Enter a weight in the first set's weight field
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

        // Tap "Finish" to end the workout
        finishButton.tap()

        // Confirm the "Finish Workout?" alert
        let finishAlert = app.alerts["Finish Workout?"]
        XCTAssertTrue(finishAlert.waitForExistence(timeout: 5), "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        // Dismiss the workout summary screen
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Done button not found on workout summary")
        doneButton.tap()

        // Verify we're back on the workout tab
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10), "Did not return to workout screen after finishing")
    }
}
