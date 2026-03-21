//
//  WorkoutLoggingTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-20.
//

import XCTest

final class WorkoutLoggingTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testStartAndCompleteWorkout() throws {
        // 0. Dismiss any "Resume Workout?" alert left over from a previous run
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
        }

        // 1. Tap the Workout tab
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()

        // 2. Switch to Routines sub-tab and wait for page transition
        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5), "Routines pill not found")
        routinesPill.tap()
        sleep(2)

        // 3. Tap the first routine in the list
        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found in the list")
        firstRoutine.tap()

        // 4. Tap "Start Workout" on the routine detail screen
        let startWorkoutButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startWorkoutButton.waitForExistence(timeout: 10), "Start Workout button not found")
        startWorkoutButton.tap()

        // 5. Verify active workout screen appeared
        let finishButton = app.buttons["Finish"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Finish button not found — active workout screen may not have appeared")

        // 6. Enter a weight in the first set's weight field
        let weightField = app.textFields["weightField_1"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Weight field for set 1 not found")
        weightField.tap()
        // SelectAllTextField auto-selects text on focus, so typing replaces it
        weightField.typeText("80")

        // 7. Dismiss keyboard, then swipe left on the set row to complete it
        // Tap elsewhere to dismiss the keyboard first
        app.swipeDown()
        sleep(1)
        weightField.swipeLeft()
        sleep(1) // Wait for completion animation

        // 8. Tap "Finish" to end the workout (now with completed sets)
        finishButton.tap()

        // 9. Confirm the "Finish Workout?" alert
        let finishAlert = app.alerts["Finish Workout?"]
        XCTAssertTrue(finishAlert.waitForExistence(timeout: 5), "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        // 10. Dismiss the workout summary screen
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Done button not found on workout summary")
        doneButton.tap()

        // 11. Verify we're back on the workout tab
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10), "Did not return to workout screen after finishing")
    }
}
