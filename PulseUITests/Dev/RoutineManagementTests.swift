//
//  RoutineManagementTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-21.
//

import XCTest

final class RoutineManagementTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }
    override var needsCustomExerciseCleanup: Bool { true }

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

        let routineInList = app.staticTexts[routineName]
        XCTAssertTrue(routineInList.waitForExistence(timeout: 10), "Routine '\(routineName)' not found in the list")
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
        waitForAnimation()

        // Clear the name field and type the new name
        let nameField = app.textFields["editRoutineNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Edit routine name field not found")
        nameField.tap()
        // Select all and clear
        nameField.press(forDuration: 1.0)
        waitForAnimation()
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
        }
        nameField.typeText(updatedName)

        // Save changes
        let saveButton = app.buttons["saveRoutineChangesButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save Changes button not found")
        saveButton.tap()

        // Verify the title updated on the detail screen
        let updatedTitle = app.staticTexts[updatedName]
        XCTAssertTrue(updatedTitle.waitForExistence(timeout: 10), "Updated routine name '\(updatedName)' not found")
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

        // The exercise picker sheet should appear with "Add Exercise" as the title
        let addExerciseTitle = app.navigationBars["Add Exercise"]
        XCTAssertTrue(addExerciseTitle.waitForExistence(timeout: 5), "Exercise picker sheet not shown")

        // Search for "Bench Press"
        let searchField = app.textFields["exerciseSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Exercise search field not found")
        searchField.tap()
        searchField.typeText("Bench Press")

        let exerciseRow = app.buttons["exercisePickerRow"].firstMatch
        XCTAssertTrue(exerciseRow.waitForExistence(timeout: 10), "Bench Press exercise not found in search results")
        exerciseRow.tap()
        waitForAnimation()

        // The exercise config sheet should appear - enter a weight
        let weightField = app.textFields["exerciseWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Exercise weight field not found")
        weightField.tap()
        weightField.typeText("60")

        // Tap "Add" to add the exercise to the routine
        let addButton = app.buttons["addExerciseToRoutineButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button not found in exercise config")
        addButton.tap()

        // Tap "Done" to dismiss the exercise picker
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        }

        // Verify the exercise appears in the routine detail
        let benchPressInRoutine = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchPressInRoutine.waitForExistence(timeout: 10), "Bench Press not found in the routine's exercise list")

        // Verify exercise count updated (should show "1 exercise")
        let exerciseCount = app.staticTexts["1 exercise"]
        XCTAssertTrue(exerciseCount.waitForExistence(timeout: 5), "Exercise count did not update to '1 exercise'")
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

        // Tap "Custom" toolbar button to create a custom exercise
        let customButton = app.buttons["customExerciseToolbarButton"]
        XCTAssertTrue(customButton.waitForExistence(timeout: 5), "Custom exercise toolbar button not found")
        customButton.tap()
        waitForAnimation()

        // Fill in the custom exercise name
        let exerciseNameField = app.textFields["customExerciseNameField"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 5), "Custom exercise name field not found")
        exerciseNameField.tap()
        exerciseNameField.typeText(customExerciseName)

        // Tap Create Exercise
        let createExerciseButton = app.buttons["createCustomExerciseButton"]
        XCTAssertTrue(createExerciseButton.waitForExistence(timeout: 5), "Create Exercise button not found")
        createExerciseButton.tap()

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

        // Dismiss the exercise picker
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        }

        // Verify the custom exercise appears in the routine
        let customInRoutine = app.staticTexts[customExerciseName]
        XCTAssertTrue(customInRoutine.waitForExistence(timeout: 10), "Custom exercise '\(customExerciseName)' not found in the routine")
    }

    // MARK: - Test: Delete a Routine

    func testDeleteRoutine() throws {
        let routineName = "UITest Delete \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)

        // Go back to the routine list
        navigateBackToRoutineList()

        // Verify the routine is in the list
        let routineInList = app.staticTexts[routineName]
        XCTAssertTrue(routineInList.waitForExistence(timeout: 10), "Routine '\(routineName)' not found in the list before deletion")

        // Enter select mode
        let modifyButton = app.buttons["modifyRoutinesButton"]
        XCTAssertTrue(modifyButton.waitForExistence(timeout: 5), "Modify button not found")
        modifyButton.tap()
        waitForAnimation()

        // Tap the routine row to select it
        let routineRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", routineName)).firstMatch
        XCTAssertTrue(routineRow.waitForExistence(timeout: 5), "Routine row not found for selection")
        routineRow.tap()
        waitForAnimation()

        // Tap the Delete button
        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Delete'")).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button not found")
        deleteButton.tap()

        // Confirm the deletion alert
        let confirmDelete = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert not found")
        confirmDelete.tap()
        _ = confirmDelete.waitForNonExistence(timeout: 5)

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

        let customButton = app.buttons["customExerciseToolbarButton"]
        XCTAssertTrue(customButton.waitForExistence(timeout: 5), "Custom button not found")
        customButton.tap()
        waitForAnimation()

        let exerciseNameField = app.textFields["customExerciseNameField"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 5), "Custom exercise name field not found")
        exerciseNameField.tap()
        exerciseNameField.typeText(customExerciseName)

        let createExerciseButton = app.buttons["createCustomExerciseButton"]
        XCTAssertTrue(createExerciseButton.waitForExistence(timeout: 5), "Create Exercise button not found")
        createExerciseButton.tap()

        // Cancel the config sheet - we only needed the exercise created
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
            waitForAnimation()
        }

        // Dismiss the exercise picker
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            waitForAnimation()
        }

        // 3. Navigate to Profile tab
        navigateBackToRoutineList()

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "Profile tab not found")
        profileTab.tap()

        // 4. Tap the Custom Exercises "See All" link
        let seeAll = app.buttons["customExercisesSeeAll"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10), "Custom Exercises 'See All' not found")
        seeAll.tap()

        // Verify our custom exercise is in the list
        let exerciseText = app.staticTexts[customExerciseName]
        XCTAssertTrue(exerciseText.waitForExistence(timeout: 10), "Custom exercise '\(customExerciseName)' not found in list")

        // 5. Tap the three-dot menu and delete
        let menuButton = app.buttons["customExerciseMenu"].firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Three-dot menu button not found")
        menuButton.tap()
        waitForAnimation()

        let deleteExerciseOption = app.buttons["Delete Exercise"]
        XCTAssertTrue(deleteExerciseOption.waitForExistence(timeout: 5), "Delete Exercise option not found in menu")
        deleteExerciseOption.tap()
        waitForAnimation()

        // Confirm the deletion
        let confirmDelete = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation alert not found")
        confirmDelete.tap()
        _ = confirmDelete.waitForNonExistence(timeout: 5)

        // 6. Verify the exercise is gone
        let deletedExercise = app.staticTexts[customExerciseName]
        XCTAssertFalse(deletedExercise.exists, "Custom exercise '\(customExerciseName)' still exists after deletion")
    }
}
