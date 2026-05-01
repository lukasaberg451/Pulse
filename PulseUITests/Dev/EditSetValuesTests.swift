//
//  EditSetValuesTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class EditSetValuesTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }

    // MARK: - Helpers

    /// Discards workout via the cancelWorkoutButton (differs from base class discardActiveWorkout
    /// which uses the generic "Cancel" button).
    private func discardWorkout() {
        let cancelButton = app.buttons["cancelWorkoutButton"]
        if cancelButton.exists {
            cancelButton.tap()
            let cancelAlert = app.alerts["Cancel Workout?"]
            if cancelAlert.waitForExistence(timeout: 3) {
                cancelAlert.buttons["Discard"].tap()
                _ = cancelAlert.waitForNonExistence(timeout: 3)
            }
        }
    }

    // MARK: - Test: Edit Weight Before Completing Set

    /// Enters a custom weight value in the weight field, then completes
    /// the set and verifies it shows as completed.
    func testEditWeightBeforeCompletingSet() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        // Find the weight field for set 1
        let weightField = app.textFields["weightField_1"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Weight field for set 1 not found")

        // Tap and type a custom weight
        weightField.tap()
        waitForAnimation()
        // SelectAllTextField auto-selects, so typing replaces existing value
        weightField.typeText("95")

        // Dismiss keyboard
        app.navigationBars.firstMatch.tap()
        waitForAnimation()

        // Complete the set by tapping the set number pill
        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        XCTAssertTrue(setOnePill.waitForExistence(timeout: 5), "Set 1 pill not found")
        setOnePill.tap()
        confirmRepsPromptIfPresent()

        // Verify the weight is displayed (completed sets show the weight as text, not a field)
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
        createRoutineAndStartWorkout()

        // Complete set 1 with 80
        let weightField1 = app.textFields["weightField_1"]
        XCTAssertTrue(weightField1.waitForExistence(timeout: 5), "Weight field for set 1 not found")
        weightField1.tap()
        weightField1.typeText("80")
        app.navigationBars.firstMatch.tap()
        waitForAnimation()

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        XCTAssertTrue(setOnePill.waitForExistence(timeout: 5), "Set 1 pill not found")
        setOnePill.tap()
        confirmRepsPromptIfPresent()

        // Now edit set 2 with 85
        let weightField2 = app.textFields["weightField_2"]
        XCTAssertTrue(weightField2.waitForExistence(timeout: 5), "Weight field for set 2 not found")
        weightField2.tap()
        weightField2.typeText("85")
        app.navigationBars.firstMatch.tap()
        waitForAnimation()

        let setTwoPill = app.buttons.matching(NSPredicate(format: "label == '2'")).firstMatch
        XCTAssertTrue(setTwoPill.waitForExistence(timeout: 5), "Set 2 pill not found")
        setTwoPill.tap()
        confirmRepsPromptIfPresent()

        // Verify both weights are displayed as completed
        let weight80 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '80'")).firstMatch
        let weight85 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '85'")).firstMatch
        XCTAssertTrue(weight80.exists, "Set 1 should show weight of 80")
        XCTAssertTrue(weight85.exists, "Set 2 should show weight of 85")

        // Clean up
        discardWorkout()
    }
}
