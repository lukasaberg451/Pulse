//
//  OneRMDuplicateTests.swift
//  PulseUITests
//
//  Regression test: verifies that completing a workout logs exactly one
//  1RM history entry per exercise (not two).
//

import XCTest

final class OneRMDuplicateTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsWorkoutCleanup: Bool { true }

    // MARK: - Helpers

    private func navigateToProgress() {
        let progressTab = app.buttons["Progress"]
        assertExists(progressTab, timeout: 15, "Progress tab not found")
        progressTab.tap()
        _ = app.staticTexts["Activity"].waitForExistence(timeout: 10)
    }

    private func scrollToEstimated1RMSection() {
        let section = app.otherElements["progressEstimated1RMSection"]
        for _ in 0..<3 {
            if section.waitForExistence(timeout: 3) { break }
            app.swipeUp()
            waitForAnimation()
        }
    }

    /// Navigates into the 1RM detail view for Overhead Press and returns
    /// the history entry count from the hidden toolbar label.
    private func overheadPress1RMHistoryCount() -> Int? {
        scrollToEstimated1RMSection()

        let cardPredicate = NSPredicate(format: "identifier CONTAINS 'estimated1RMCard_' AND identifier CONTAINS[c] 'Overhead Press'")
        let card = app.buttons.matching(cardPredicate).firstMatch
        if !card.waitForExistence(timeout: 5) {
            let seeAll = app.buttons["estimated1RMSeeAllButton"]
            if seeAll.waitForExistence(timeout: 3) {
                seeAll.tap()
                _ = app.navigationBars["Estimated 1RM"].waitForExistence(timeout: 5)
                if !card.waitForExistence(timeout: 5) {
                    app.swipeUp()
                    waitForAnimation()
                }
                guard card.waitForExistence(timeout: 5) else { return nil }
            } else {
                return nil
            }
        }
        card.tap()

        let countLabel = app.staticTexts["exercise1RMHistoryCount"]
        guard countLabel.waitForExistence(timeout: 10) else { return nil }

        // Wait for async history load to finish
        sleep(3)

        guard let count = Int(countLabel.label) else { return nil }
        return count
    }

    private func navigateBackToRoot() {
        for _ in 0..<3 {
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 2), backButton.isHittable {
                backButton.tap()
                waitForAnimation()
            } else {
                break
            }
        }
    }

    private func addOverheadPressToRoutine() {
        let addExerciseButton = app.buttons["addExerciseButton"]
        assertExists(addExerciseButton, timeout: 5, "Add Exercise button not found")
        addExerciseButton.tap()

        let searchField = app.textFields["exerciseSearchField"]
        assertExists(searchField, timeout: 5, "Exercise search field not found")
        searchField.tap()
        searchField.typeText("Overhead Press")

        let exerciseRow = app.buttons["exercisePickerRow"].firstMatch
        assertExists(exerciseRow, timeout: 10, "Overhead Press not found in search results")
        exerciseRow.tap()

        let weightField = app.textFields["exerciseWeightField"]
        assertExists(weightField, timeout: 5, "Exercise weight field not found")
        weightField.tap()
        weightField.typeText("50")

        let addButton = app.buttons["addExerciseToRoutineButton"]
        assertExists(addButton, timeout: 5, "Add button not found")
        addButton.tap()

        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        }

        _ = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Overhead Press'")).firstMatch.waitForExistence(timeout: 5)
    }

    private func createRoutineAndStartWorkoutWithOHP() {
        let routineName = "UITest OHP \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)
        assertExists(app.staticTexts[routineName], timeout: 10)
        addOverheadPressToRoutine()

        let startWorkoutButton = app.buttons["startWorkoutButton"]
        assertExists(startWorkoutButton, timeout: 10, "Start Workout button not found")
        startWorkoutButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        assertExists(finishButton, timeout: 10, "Active workout screen did not appear")
    }

    private func completeWorkoutWithOHP() {
        createRoutineAndStartWorkoutWithOHP()

        let weightField = app.textFields["weightField_1"]
        assertExists(weightField, timeout: 5, "Weight field for set 1 not found")
        weightField.tap()
        weightField.typeText("50")

        app.navigationBars.firstMatch.tap()
        waitForAnimation()

        let setOnePill = app.buttons.matching(NSPredicate(format: "label == '1'")).firstMatch
        assertExists(setOnePill, timeout: 5, "Set 1 pill not found")
        setOnePill.tap()
        confirmRepsPromptIfPresent()

        let finishButton = app.buttons["finishWorkoutButton"]
        finishButton.tap()

        let finishAlert = app.alerts["Finish Workout?"]
        assertExists(finishAlert, timeout: 5, "Finish Workout alert not found")
        finishAlert.buttons["Finish"].tap()

        let doneButton = app.buttons["Done"]
        assertExists(doneButton, timeout: 15, "Done button not found on workout summary")
        doneButton.tap()

        let workoutTab = app.buttons["Workout"]
        assertExists(workoutTab, timeout: 10, "Did not return to workout screen")

        navigateBackToRoutineList()
    }

    // MARK: - Test

    /// Completes a workout, records the 1RM history count, completes another
    /// workout, then asserts the count increased by exactly 1 (not 2).
    func testOneRMLoggedExactlyOncePerWorkout() throws {
        dismissResumeAlertIfPresent()

        // Step 1: Complete first workout to guarantee at least one 1RM entry
        completeWorkoutWithOHP()

        // Step 2: Read the 1RM history count
        navigateToProgress()
        let countAfterFirst = overheadPress1RMHistoryCount()
        XCTAssertNotNil(countAfterFirst, "Could not read 1RM history count after first workout")
        navigateBackToRoot()

        // Step 3: Complete a second workout
        completeWorkoutWithOHP()

        // Step 4: Read the count again and verify it increased by exactly 1
        navigateToProgress()
        let countAfterSecond = overheadPress1RMHistoryCount()
        XCTAssertNotNil(countAfterSecond, "Could not read 1RM history count after second workout")

        XCTAssertEqual(
            countAfterSecond, (countAfterFirst ?? 0) + 1,
            "Expected exactly 1 new 1RM entry but got \((countAfterSecond ?? 0) - (countAfterFirst ?? 0)). Duplicate entries may be logged."
        )
    }
}
