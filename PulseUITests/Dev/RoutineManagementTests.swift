//
//  RoutineManagementTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-21.
//

import XCTest

final class RoutineManagementTests: XCTestCase {

    var app: XCUIApplication!

    /// Unique suffix to avoid name collisions between test runs.
    private let uniqueSuffix = UUID().uuidString.prefix(6)

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate to the Routines sub-tab inside the Workout tab.
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

    /// Create a routine with the given name via the UI.
    /// Returns the name used so callers can reference it for cleanup.
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

        // Wait for the routine detail screen to appear (navigated automatically after creation)
        sleep(3)

        return name
    }

    /// Navigate back from the routine detail view to the routine list.
    private func navigateBackToRoutineList() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            sleep(2)
        }
    }

    /// Delete all routines whose names contain the given substring.
    /// Uses the "Modify" select mode to batch-delete.
    private func cleanupRoutines(containing substring: String) {
        navigateToRoutinesTab()
        sleep(2)

        // Check if there are any routines matching our substring
        let routineRows = app.buttons.matching(identifier: "routineRow")
        guard routineRows.count > 0 else { return }

        // Check if any routine contains our substring
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let matchingRows = app.buttons.matching(predicate)
        guard matchingRows.count > 0 else { return }

        let modifyButton = app.buttons["modifyRoutinesButton"]
        guard modifyButton.waitForExistence(timeout: 5) else { return }
        modifyButton.tap()
        sleep(1)

        // Tap each matching routine to select it
        for i in 0..<matchingRows.count {
            matchingRows.element(boundBy: i).tap()
            usleep(500_000)
        }

        // Tap the delete button
        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Delete'")).firstMatch
        if deleteButton.waitForExistence(timeout: 3) {
            deleteButton.tap()
            sleep(1)
        }

        // Confirm the delete alert
        let confirmDelete = app.alerts.buttons["Delete"]
        if confirmDelete.waitForExistence(timeout: 3) {
            confirmDelete.tap()
            sleep(2)
        }
    }

    // MARK: - Test: Create a Routine

    func testCreateRoutine() throws {
        let routineName = "UITest Routine \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)

        // Verify we ended up on the routine detail view with the correct name
        let routineTitle = app.staticTexts[routineName]
        XCTAssertTrue(routineTitle.waitForExistence(timeout: 10), "Routine title '\(routineName)' not found on detail screen")

        // Verify "No Exercises Yet" empty state is shown
        let noExercisesText = app.staticTexts["No Exercises Yet"]
        XCTAssertTrue(noExercisesText.waitForExistence(timeout: 5), "Empty exercises state not shown")

        // Navigate back and verify the routine appears in the list
        navigateBackToRoutineList()
        sleep(2)

        let routineInList = app.staticTexts[routineName]
        XCTAssertTrue(routineInList.waitForExistence(timeout: 10), "Routine '\(routineName)' not found in the list")

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Edit a Routine

    func testEditRoutineName() throws {
        let originalName = "UITest Edit \(uniqueSuffix)"
        let updatedName = "UITest Edited \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: originalName)

        // Verify we're on the detail screen
        let routineTitle = app.staticTexts[originalName]
        XCTAssertTrue(routineTitle.waitForExistence(timeout: 10), "Routine detail screen not showing")

        // Tap Edit Routine
        let editButton = app.buttons["editRoutineButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit Routine button not found")
        editButton.tap()
        sleep(1)

        // Clear the name field and type the new name
        let nameField = app.textFields["editRoutineNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Edit routine name field not found")
        nameField.tap()
        // Select all and clear
        nameField.press(forDuration: 1.0)
        usleep(500_000)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
        }
        nameField.typeText(updatedName)

        // Save changes
        let saveButton = app.buttons["saveRoutineChangesButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save Changes button not found")
        saveButton.tap()
        sleep(2)

        // Verify the title updated on the detail screen
        let updatedTitle = app.staticTexts[updatedName]
        XCTAssertTrue(updatedTitle.waitForExistence(timeout: 10), "Updated routine name '\(updatedName)' not found")

        // Cleanup
        navigateBackToRoutineList()
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Add an Exercise to a Routine

    func testAddExerciseToRoutine() throws {
        let routineName = "UITest AddEx \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)

        // Verify detail screen
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10), "Routine detail not showing")

        // Tap "Add Exercise"
        let addExerciseButton = app.buttons["addExerciseButton"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise button not found")
        addExerciseButton.tap()
        sleep(2)

        // The exercise picker sheet should appear with "Add Exercise" as the title
        let addExerciseTitle = app.navigationBars["Add Exercise"]
        XCTAssertTrue(addExerciseTitle.waitForExistence(timeout: 5), "Exercise picker sheet not shown")

        // Search for "Bench Press"
        let searchField = app.textFields["exerciseSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Exercise search field not found")
        searchField.tap()
        searchField.typeText("Bench Press")
        sleep(2)

        // Tap the first exercise result containing "Bench Press"
        let benchPressResult = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchPressResult.waitForExistence(timeout: 10), "Bench Press exercise not found in search results")
        benchPressResult.tap()
        sleep(1)

        // The exercise config sheet should appear - enter a weight
        let weightField = app.textFields["exerciseWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Exercise weight field not found")
        weightField.tap()
        weightField.typeText("60")

        // Tap "Add" to add the exercise to the routine
        let addButton = app.buttons["addExerciseToRoutineButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button not found in exercise config")
        addButton.tap()
        sleep(2)

        // Tap "Done" to dismiss the exercise picker
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            sleep(2)
        }

        // Verify the exercise appears in the routine detail
        let benchPressInRoutine = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchPressInRoutine.waitForExistence(timeout: 10), "Bench Press not found in the routine's exercise list")

        // Verify exercise count updated (should show "1 exercise")
        let exerciseCount = app.staticTexts["1 exercise"]
        XCTAssertTrue(exerciseCount.waitForExistence(timeout: 5), "Exercise count did not update to '1 exercise'")

        // Cleanup
        navigateBackToRoutineList()
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Create and Use a Custom Exercise

    func testCreateCustomExerciseAndAddToRoutine() throws {
        let routineName = "UITest Custom \(uniqueSuffix)"
        let customExerciseName = "Custom Ex \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)

        // Verify detail screen
        XCTAssertTrue(app.staticTexts[routineName].waitForExistence(timeout: 10), "Routine detail not showing")

        // Open exercise picker
        let addExerciseButton = app.buttons["addExerciseButton"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise button not found")
        addExerciseButton.tap()
        sleep(2)

        // Tap "Custom" toolbar button to create a custom exercise
        let customButton = app.buttons["customExerciseToolbarButton"]
        XCTAssertTrue(customButton.waitForExistence(timeout: 5), "Custom exercise toolbar button not found")
        customButton.tap()
        sleep(1)

        // Fill in the custom exercise name
        let exerciseNameField = app.textFields["customExerciseNameField"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 5), "Custom exercise name field not found")
        exerciseNameField.tap()
        exerciseNameField.typeText(customExerciseName)

        // Tap Create Exercise
        let createExerciseButton = app.buttons["createCustomExerciseButton"]
        XCTAssertTrue(createExerciseButton.waitForExistence(timeout: 5), "Create Exercise button not found")
        createExerciseButton.tap()
        sleep(2)

        // The exercise config sheet should appear automatically for the new exercise
        // Enter a weight to enable the Add button
        let weightField = app.textFields["exerciseWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Weight field not found after creating custom exercise")
        weightField.tap()
        weightField.typeText("50")

        // Tap Add
        let addButton = app.buttons["addExerciseToRoutineButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button not found")
        addButton.tap()
        sleep(2)

        // Dismiss the exercise picker
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            sleep(2)
        }

        // Verify the custom exercise appears in the routine
        let customInRoutine = app.staticTexts[customExerciseName]
        XCTAssertTrue(customInRoutine.waitForExistence(timeout: 10), "Custom exercise '\(customExerciseName)' not found in the routine")

        // Cleanup
        navigateBackToRoutineList()
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Delete a Routine

    func testDeleteRoutine() throws {
        let routineName = "UITest Delete \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)

        // Go back to the routine list
        navigateBackToRoutineList()
        sleep(2)

        // Verify the routine is in the list
        let routineInList = app.staticTexts[routineName]
        XCTAssertTrue(routineInList.waitForExistence(timeout: 10), "Routine '\(routineName)' not found in the list before deletion")

        // Enter select mode
        let modifyButton = app.buttons["modifyRoutinesButton"]
        XCTAssertTrue(modifyButton.waitForExistence(timeout: 5), "Modify button not found")
        modifyButton.tap()
        sleep(1)

        // Tap the routine row to select it
        let routineRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", routineName)).firstMatch
        XCTAssertTrue(routineRow.waitForExistence(timeout: 5), "Routine row not found for selection")
        routineRow.tap()
        sleep(1)

        // Tap the Delete button
        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Delete'")).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button not found")
        deleteButton.tap()
        sleep(1)

        // Confirm the deletion alert
        let confirmDelete = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert not found")
        confirmDelete.tap()
        sleep(3)

        // Verify the routine is gone from the list
        let deletedRoutine = app.staticTexts[routineName]
        XCTAssertFalse(deletedRoutine.exists, "Routine '\(routineName)' still exists after deletion")
    }

    // MARK: - Test: Delete a Custom Exercise from Profile

    /// Creates a custom exercise via a routine, then navigates to Profile → My Custom Exercises
    /// and deletes it.
    func testDeleteCustomExerciseFromProfile() throws {
        let routineName = "UITest DelEx \(uniqueSuffix)"
        let customExerciseName = "DelTestEx \(uniqueSuffix)"

        // 1. Create a routine so we can access the exercise picker
        navigateToRoutinesTab()
        createRoutine(name: routineName)

        // 2. Open exercise picker and create a custom exercise
        let addExerciseButton = app.buttons["addExerciseButton"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise button not found")
        addExerciseButton.tap()
        sleep(2)

        let customButton = app.buttons["customExerciseToolbarButton"]
        XCTAssertTrue(customButton.waitForExistence(timeout: 5), "Custom button not found")
        customButton.tap()
        sleep(1)

        let exerciseNameField = app.textFields["customExerciseNameField"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 5), "Custom exercise name field not found")
        exerciseNameField.tap()
        exerciseNameField.typeText(customExerciseName)

        let createExerciseButton = app.buttons["createCustomExerciseButton"]
        XCTAssertTrue(createExerciseButton.waitForExistence(timeout: 5), "Create Exercise button not found")
        createExerciseButton.tap()
        sleep(2)

        // Cancel the config sheet — we only needed the exercise created
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

        // 3. Navigate to Profile tab
        navigateBackToRoutineList()
        sleep(1)

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "Profile tab not found")
        profileTab.tap()
        sleep(3)

        // 4. Tap the Custom Exercises "See All" link
        let seeAll = app.buttons["customExercisesSeeAll"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10), "Custom Exercises 'See All' not found")
        seeAll.tap()
        sleep(2)

        // Verify our custom exercise is in the list
        let exerciseText = app.staticTexts[customExerciseName]
        XCTAssertTrue(exerciseText.waitForExistence(timeout: 10), "Custom exercise '\(customExerciseName)' not found in list")

        // 5. Tap the three-dot menu and delete
        let menuButton = app.buttons["customExerciseMenu"].firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Three-dot menu button not found")
        menuButton.tap()
        sleep(1)

        let deleteExerciseOption = app.buttons["Delete Exercise"]
        XCTAssertTrue(deleteExerciseOption.waitForExistence(timeout: 5), "Delete Exercise option not found in menu")
        deleteExerciseOption.tap()
        sleep(1)

        // Confirm the deletion
        let confirmDelete = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert not found")
        confirmDelete.tap()
        sleep(2)

        // 6. Verify the exercise is gone
        let deletedExercise = app.staticTexts[customExerciseName]
        XCTAssertFalse(deletedExercise.exists, "Custom exercise '\(customExerciseName)' still exists after deletion")

        // Cleanup the test routine
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            sleep(1)
        }

        cleanupRoutines(containing: String(uniqueSuffix))
    }
}
