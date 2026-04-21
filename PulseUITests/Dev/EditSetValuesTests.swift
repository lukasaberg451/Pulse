//
//  EditSetValuesTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class EditSetValuesTests: XCTestCase {

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

    private func startWorkout() {
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5), "Routines pill not found")
        routinesPill.tap()
        sleep(2)

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found")
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found")
        startButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout screen did not appear")
    }

    private func discardWorkout() {
        // Cancel the workout to clean up
        let cancelButton = app.buttons["cancelWorkoutButton"]
        if cancelButton.exists {
            cancelButton.tap()
            let cancelAlert = app.alerts["Cancel Workout?"]
            if cancelAlert.waitForExistence(timeout: 3) {
                cancelAlert.buttons["Discard"].tap()
                sleep(1)
            }
        }
    }

    // MARK: - Test: Edit Weight Before Completing Set

    /// Enters a custom weight value in the weight field, then completes
    /// the set and verifies it shows as completed.
    func testEditWeightBeforeCompletingSet() throws {
        dismissResumeAlertIfPresent()
        startWorkout()

        // Find the weight field for set 1
        let weightField = app.textFields["weightField_1"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Weight field for set 1 not found")

        // Tap and type a custom weight
        weightField.tap()
        sleep(1)
        // SelectAllTextField auto-selects, so typing replaces existing value
        weightField.typeText("95")

        // Dismiss keyboard
        app.navigationBars.firstMatch.tap()
        sleep(1)

        // Complete the set by tapping the set number pill
        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        XCTAssertTrue(setOnePill.waitForExistence(timeout: 5), "Set 1 pill not found")
        setOnePill.tap()
        sleep(1)

        // The set should now show as completed (green check icon appears)
        let checkIcon = app.images.matching(NSPredicate(format: "identifier == 'check-circle' OR label CONTAINS 'check'")).firstMatch
        // Alternatively, verify the weight is displayed (completed sets show the weight as text, not a field)
        let completedWeight = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '95'")).firstMatch
        XCTAssertTrue(completedWeight.waitForExistence(timeout: 5), "Completed set should display the entered weight of 95")

        // Clean up
        discardWorkout()
    }

    // MARK: - Test: Edit Weight to Different Value on Second Set

    /// Changes the weight on set 2 to a different value than set 1,
    /// completes both, and verifies both are marked completed.
    func testDifferentWeightsOnConsecutiveSets() throws {
        dismissResumeAlertIfPresent()
        startWorkout()

        // Complete set 1 with 80
        let weightField1 = app.textFields["weightField_1"]
        XCTAssertTrue(weightField1.waitForExistence(timeout: 5), "Weight field for set 1 not found")
        weightField1.tap()
        weightField1.typeText("80")
        app.navigationBars.firstMatch.tap()
        sleep(1)

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        XCTAssertTrue(setOnePill.waitForExistence(timeout: 5), "Set 1 pill not found")
        setOnePill.tap()
        sleep(1)

        // Now edit set 2 with 85
        let weightField2 = app.textFields["weightField_2"]
        XCTAssertTrue(weightField2.waitForExistence(timeout: 5), "Weight field for set 2 not found")
        weightField2.tap()
        weightField2.typeText("85")
        app.navigationBars.firstMatch.tap()
        sleep(1)

        let setTwoPill = app.buttons.matching(NSPredicate(format: "label == '2'")).firstMatch
        XCTAssertTrue(setTwoPill.waitForExistence(timeout: 5), "Set 2 pill not found")
        setTwoPill.tap()
        sleep(1)

        // Verify both weights are displayed as completed
        let weight80 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '80'")).firstMatch
        let weight85 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '85'")).firstMatch
        XCTAssertTrue(weight80.exists, "Set 1 should show weight of 80")
        XCTAssertTrue(weight85.exists, "Set 2 should show weight of 85")

        // Clean up
        discardWorkout()
    }
}
