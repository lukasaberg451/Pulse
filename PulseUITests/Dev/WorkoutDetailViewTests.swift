//
//  WorkoutDetailViewTests.swift
//  PulseUITests
//
//  Tests for viewing workout details after completing a workout.
//

import XCTest

final class WorkoutDetailViewTests: XCTestCase {

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
            cleanupRoutines(containing: String(uniqueSuffix))
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

        // Dismiss keyboard so search results become hittable
        app.swipeDown()
        sleep(1)

        let benchPressResult = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchPressResult.waitForExistence(timeout: 10), "Bench Press not found")
        if !benchPressResult.isHittable {
            app.swipeUp()
            sleep(1)
        }
        benchPressResult.tap()
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

    private func scheduleWorkout(routineName: String) {
        let addWorkoutButton = app.buttons["addScheduledWorkoutButton"]
        XCTAssertTrue(addWorkoutButton.waitForExistence(timeout: 5), "Add Workout button not found")
        addWorkoutButton.tap()
        sleep(2)

        let routineRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", routineName)).firstMatch
        XCTAssertTrue(routineRow.waitForExistence(timeout: 10), "Routine '\(routineName)' not found in picker")
        routineRow.tap()
        sleep(3)
    }

    private func completeWorkoutWithOneSet() {
        let startButton = app.buttons["startScheduledWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start button not found")
        startButton.tap()
        sleep(2)

        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Finish button not found")

        let weightField = app.textFields["weightField_1"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Weight field not found")
        weightField.tap()
        weightField.typeText("80")

        app.navigationBars.firstMatch.tap()
        sleep(1)

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        XCTAssertTrue(setOnePill.waitForExistence(timeout: 5), "Set 1 pill not found")
        setOnePill.tap()
        sleep(1)

        finishButton.tap()

        let finishAlert = app.alerts["Finish Workout?"]
        XCTAssertTrue(finishAlert.waitForExistence(timeout: 5), "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Done button not found on summary")
        doneButton.tap()
        sleep(2)
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
            matchingRows.element(boundBy: i).tap()
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
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10))
        addBenchPressToRoutine()
        navigateBackToRoutineList()
        sleep(1)

        // 2. Schedule and complete
        navigateToScheduleTab()
        scheduleWorkout(routineName: routineName)
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10))
        completeWorkoutWithOneSet()

        // 3. Navigate back to schedule and tap the completed card
        navigateToScheduleTab()
        let completedText = app.staticTexts["Completed"]
        XCTAssertTrue(completedText.waitForExistence(timeout: 10), "Completed badge not found")

        // Tap the completed workout card — it's a NavigationLink
        let completedCard = app.otherElements.matching(identifier: "scheduledWorkoutCard").firstMatch
        XCTAssertTrue(completedCard.waitForExistence(timeout: 5), "Completed workout card not found")
        completedCard.tap()
        sleep(3)

        // 4. Verify workout detail view elements
        let workoutTitle = app.staticTexts[routineName]
        XCTAssertTrue(workoutTitle.waitForExistence(timeout: 10), "Workout name '\(routineName)' not found on detail view")

        let durationLabel = app.staticTexts["Duration"]
        XCTAssertTrue(durationLabel.waitForExistence(timeout: 5), "'Duration' stat not found")

        let totalSetsLabel = app.staticTexts["Total Sets"]
        XCTAssertTrue(totalSetsLabel.waitForExistence(timeout: 5), "'Total Sets' stat not found")

        let volumeLabel = app.staticTexts["Volume"]
        XCTAssertTrue(volumeLabel.waitForExistence(timeout: 5), "'Volume' stat not found")

        let exercisesHeader = app.staticTexts["Exercises"]
        XCTAssertTrue(exercisesHeader.waitForExistence(timeout: 5), "'Exercises' section header not found")

        // Verify Bench Press appears in the exercises list
        let benchPress = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchPress.waitForExistence(timeout: 5), "Bench Press not found in workout detail exercises")

        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            sleep(1)
        }

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
    }
}
