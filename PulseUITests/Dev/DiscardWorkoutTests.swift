//
//  DiscardWorkoutTests.swift
//  PulseUITests
//
//  Tests for starting and discarding a workout without completing it.
//

import XCTest

final class DiscardWorkoutTests: XCTestCase {

    var app: XCUIApplication!

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

    // MARK: - Test: Cancel Workout via Cancel Button

    /// Starts a workout from the first routine, taps Cancel, confirms Discard,
    /// and verifies we return to the workout screen without the workout being saved.
    func testDiscardWorkoutViaCancelButton() throws {
        dismissResumeAlertIfPresent()
        navigateToRoutinesTab()

        // Tap the first routine
        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found in the list")
        firstRoutine.tap()

        // Start workout
        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found")
        startButton.tap()

        // Verify active workout screen appeared
        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout screen did not appear")

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
        navigateToRoutinesTab()

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found")
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found")
        startButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout screen did not appear")

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
        navigateToRoutinesTab()

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found")
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found")
        startButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout screen did not appear")

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
