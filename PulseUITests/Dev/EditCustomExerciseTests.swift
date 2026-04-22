//
//  EditCustomExerciseTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class EditCustomExerciseTests: XCTestCase {

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
            cleanupCustomExercises()
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

    private func navigateToProfile() {
        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)
    }

    private func navigateToAllCustomExercises() {
        navigateToProfile()

        let seeAllButton = app.buttons["customExercisesSeeAll"]
        if !seeAllButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }

        XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5), "'See All' for custom exercises not found")
        seeAllButton.tap()
        sleep(2)
    }

    /// Creates a routine and a custom exercise via the exercise picker, then dismisses back.
    private func createCustomExercise(name: String) {
        let routineName = "UITest CE \(uniqueSuffix)"

        navigateToRoutinesTab()

        let newRoutineButton = app.buttons["newRoutineButton"]
        XCTAssertTrue(newRoutineButton.waitForExistence(timeout: 10), "New Routine button not found")
        newRoutineButton.tap()

        let nameField = app.textFields["routineNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Routine name field not found")
        nameField.tap()
        nameField.typeText(routineName)

        let createButton = app.buttons["createRoutineButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create Routine button not found")
        createButton.tap()
        sleep(3)

        // Open exercise picker
        let addExerciseButton = app.buttons["addExerciseButton"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise button not found")
        addExerciseButton.tap()
        sleep(2)

        // Tap "Custom" toolbar button
        let customButton = app.buttons["customExerciseToolbarButton"]
        XCTAssertTrue(customButton.waitForExistence(timeout: 5), "Custom exercise toolbar button not found")
        customButton.tap()
        sleep(1)

        // Fill in the custom exercise name
        let exerciseNameField = app.textFields["customExerciseNameField"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 5), "Custom exercise name field not found")
        exerciseNameField.tap()
        exerciseNameField.typeText(name)

        // Create the exercise
        let createExerciseButton = app.buttons["createCustomExerciseButton"]
        XCTAssertTrue(createExerciseButton.waitForExistence(timeout: 5), "Create Exercise button not found")
        createExerciseButton.tap()
        sleep(2)

        // Cancel the config sheet
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
            sleep(1)
        }

        // Dismiss the exercise picker
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            sleep(1)
        }

        // Navigate back to routine list
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

    /// Delete all custom exercises from the Profile → My Custom Exercises list.
    private func cleanupCustomExercises() {
        let profileTab = app.buttons["Profile"]
        guard profileTab.waitForExistence(timeout: 10) else { return }
        profileTab.tap()
        sleep(2)

        let seeAll = app.buttons["customExercisesSeeAll"]
        if !seeAll.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        guard seeAll.waitForExistence(timeout: 3) else { return }
        seeAll.tap()
        sleep(2)

        // Delete exercises one by one via the three-dot menu
        for _ in 0..<10 {
            let menuButton = app.buttons["customExerciseMenu"].firstMatch
            guard menuButton.waitForExistence(timeout: 3) else { break }
            menuButton.tap()
            sleep(1)

            let deleteOption = app.buttons["Delete Exercise"]
            guard deleteOption.waitForExistence(timeout: 3) else { break }
            deleteOption.tap()
            sleep(1)

            let confirmDelete = app.alerts.buttons["Delete"]
            if confirmDelete.waitForExistence(timeout: 3) {
                confirmDelete.tap()
                sleep(2)
            }
        }

        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            sleep(1)
        }
    }

    // MARK: - Test: Custom Exercise Appears in Exercise List

    /// Creates a custom exercise from a routine, then navigates to Profile
    /// and verifies the "My Custom Exercises" section is visible.
    func testCustomExerciseVisibleOnProfile() throws {
        let customName = "CustEx \(uniqueSuffix)"

        dismissResumeAlertIfPresent()
        createCustomExercise(name: customName)

        navigateToProfile()

        let sectionHeader = app.staticTexts["My Custom Exercises"]
        if !sectionHeader.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 5), "'My Custom Exercises' section not found on profile")
    }

    // MARK: - Test: Delete Custom Exercise from All Custom Exercises View

    /// Creates a custom exercise, navigates to the All Custom Exercises list,
    /// taps the three-dot menu, selects Delete, confirms, and verifies removal.
    func testDeleteCustomExerciseFromAllExercisesView() throws {
        let customName = "DelCustEx \(uniqueSuffix)"

        dismissResumeAlertIfPresent()
        createCustomExercise(name: customName)

        navigateToAllCustomExercises()

        // Tap the three-dot menu on the first custom exercise
        let exerciseMenu = app.buttons["customExerciseMenu"]
        XCTAssertTrue(exerciseMenu.waitForExistence(timeout: 10), "Custom exercise menu not found")
        exerciseMenu.firstMatch.tap()
        sleep(1)

        // Tap "Delete Exercise" from the context menu
        let deleteOption = app.buttons["Delete Exercise"]
        XCTAssertTrue(deleteOption.waitForExistence(timeout: 5), "'Delete Exercise' menu option not found")
        deleteOption.tap()
        sleep(1)

        // Confirm the deletion alert
        let deleteAlert = app.alerts["Delete Exercise"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5), "Delete confirmation alert not found")
        deleteAlert.buttons["Delete"].tap()
        sleep(2)

        // The exercise should be removed
        XCTAssertFalse(deleteAlert.exists, "Delete alert should have dismissed after confirming")
    }
}
