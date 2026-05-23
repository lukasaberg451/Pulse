//
//  UITestBaseCase.swift
//  PulseUITests
//
//  Shared base class for all UI tests. Consolidates duplicated navigation,
//  cleanup, and wait helpers to reduce code and improve efficiency.
//

import XCTest

/// Base class for authenticated UI tests that use `--skip-auth`.
/// Subclasses that need `--reset-auth` or `--skip-auth-free` should
/// override `launchArguments`.
class UITestBaseCase: XCTestCase {

    var app: XCUIApplication!

    /// Unique suffix to avoid name collisions between parallel test runs.
    let uniqueSuffix = UUID().uuidString.prefix(6)

    /// Override in subclasses that need different launch arguments
    /// (e.g. `["--uitesting", "--reset-auth"]`).
    var launchArguments: [String] {
        ["--uitesting", "--skip-auth"]
    }

    /// Override in subclasses to indicate which cleanup steps tearDown should perform.
    var needsRoutineCleanup: Bool { false }
    var needsWorkoutCleanup: Bool { false }
    var needsScheduleCleanup: Bool { false }
    var needsCustomExerciseCleanup: Bool { false }

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()
    }

    override func tearDownWithError() throws {
        guard app != nil else { return }

        // Only relaunch for cleanup if subclass declared it needs cleanup
        let needsCleanup = needsRoutineCleanup || needsWorkoutCleanup || needsScheduleCleanup || needsCustomExerciseCleanup
        if needsCleanup {
            app.terminate()
            app.launch()
            dismissResumeAlertIfPresent()

            if needsWorkoutCleanup { cleanupCompletedWorkouts() }
            if needsScheduleCleanup { cleanupScheduledWorkouts() }
            if needsRoutineCleanup { cleanupRoutines(containing: "UITest") }
            if needsCustomExerciseCleanup { cleanupCustomExercises() }
        }

        app = nil
    }

    // MARK: - Wait Helpers

    /// Wait for an element to exist, with a short default timeout.
    @discardableResult
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5, _ message: String? = nil) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Wait for an element and assert it exists.
    func assertExists(_ element: XCUIElement, timeout: TimeInterval = 10, _ message: String = "") {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message.isEmpty ? "\(element) not found" : message)
    }

    /// Brief pause for animations only - use sparingly.
    func waitForAnimation() {
        usleep(500_000) // 0.5s
    }

    // MARK: - Reps Confirmation

    /// If the reps confirmation prompt ("Did you hit X reps?") appears after
    /// tapping a set pill, tap "Yes" to confirm. No-op if the prompt doesn't appear.
    func confirmRepsPromptIfPresent() {
        let yesButton = app.buttons["Yes"]
        if yesButton.waitForExistence(timeout: 2) {
            yesButton.tap()
            waitForAnimation()
        }
    }

    // MARK: - Alert Dismissal

    func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            _ = resumeAlert.waitForNonExistence(timeout: 3)
        }
    }

    // MARK: - Tab Navigation

    func navigateToDashboard() {
        let tab = app.buttons["Dashboard"]
        assertExists(tab, timeout: 15, "Dashboard tab not found")
        tab.tap()
        _ = app.staticTexts.matching(identifier: "dashboardWelcomeText").firstMatch.waitForExistence(timeout: 10)
    }

    func navigateToRoutinesTab() {
        let workoutTab = app.buttons["Workout"]
        assertExists(workoutTab, timeout: 15, "Workout tab not found")
        workoutTab.tap()

        let routinesPill = app.buttons["Routines"]
        assertExists(routinesPill, timeout: 5, "Routines pill not found")
        routinesPill.tap()

        // Wait for either routine rows or empty state to load
        let routineRow = app.buttons.matching(identifier: "routineRow").firstMatch
        let newRoutineButton = app.buttons["newRoutineButton"]
        _ = routineRow.waitForExistence(timeout: 5) || newRoutineButton.waitForExistence(timeout: 2)
    }

    func navigateToScheduleTab() {
        let workoutTab = app.buttons["Workout"]
        assertExists(workoutTab, timeout: 15, "Workout tab not found")
        workoutTab.tap()

        let schedulePill = app.buttons["Schedule"]
        assertExists(schedulePill, timeout: 5, "Schedule pill not found")
        schedulePill.tap()

        // Wait for schedule content to load
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
    }

    func navigateToProfile() {
        let profileTab = app.buttons["Profile"]
        assertExists(profileTab, timeout: 15, "Profile tab not found")
        profileTab.tap()
        _ = app.buttons["profileEditButton"].waitForExistence(timeout: 10)
    }

    func navigateToSettings() {
        navigateToProfile()
        let settingsButton = app.buttons["profileSettingsButton"]
        assertExists(settingsButton, timeout: 10, "Settings button not found")
        settingsButton.tap()
        _ = app.buttons["settingsPlanButton"].waitForExistence(timeout: 5)
    }

    // MARK: - Routine Helpers

    @discardableResult
    func createRoutine(name: String) -> String {
        let newRoutineButton = app.buttons["newRoutineButton"]
        assertExists(newRoutineButton, timeout: 10, "New Routine button not found")
        newRoutineButton.tap()

        let nameField = app.textFields["routineNameField"]
        assertExists(nameField, timeout: 5, "Routine name field not found")
        nameField.tap()
        nameField.typeText(name)

        let createButton = app.buttons["createRoutineButton"]
        assertExists(createButton, timeout: 5, "Create Routine button not found")
        createButton.tap()

        // Wait for detail screen to appear
        _ = app.staticTexts[name].waitForExistence(timeout: 10)
        return name
    }

    func addBenchPressToRoutine() {
        let addExerciseButton = app.buttons["addExerciseButton"]
        assertExists(addExerciseButton, timeout: 5, "Add Exercise button not found")
        addExerciseButton.tap()

        let searchField = app.textFields["exerciseSearchField"]
        assertExists(searchField, timeout: 5, "Exercise search field not found")
        searchField.tap()
        searchField.typeText("Bench Press")

        let exerciseRow = app.buttons["exercisePickerRow"].firstMatch
        assertExists(exerciseRow, timeout: 10, "Bench Press not found in search results")
        exerciseRow.tap()

        let weightField = app.textFields["exerciseWeightField"]
        assertExists(weightField, timeout: 5, "Exercise weight field not found")
        weightField.tap()
        weightField.typeText("60")

        let addButton = app.buttons["addExerciseToRoutineButton"]
        assertExists(addButton, timeout: 5, "Add button not found")
        addButton.tap()

        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        }

        // Wait for exercise to appear in routine
        _ = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bench Press'")).firstMatch.waitForExistence(timeout: 5)
    }

    func navigateBackToRoutineList() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            // Wait for routine list to reload
            _ = app.buttons.matching(identifier: "routineRow").firstMatch.waitForExistence(timeout: 5)
        }
    }

    /// Creates a routine with Bench Press, then starts the workout.
    /// Returns the active workout screen (finishWorkoutButton is visible).
    func createRoutineAndStartWorkout() {
        let routineName = "UITest WL \(uniqueSuffix)"

        navigateToRoutinesTab()
        createRoutine(name: routineName)
        assertExists(app.staticTexts[routineName], timeout: 10)
        addBenchPressToRoutine()

        let startWorkoutButton = app.buttons["startWorkoutButton"]
        assertExists(startWorkoutButton, timeout: 10, "Start Workout button not found")
        startWorkoutButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        assertExists(finishButton, timeout: 10, "Active workout screen did not appear")
    }

    // MARK: - Schedule Helpers

    func scheduleWorkout(routineName: String) {
        let addWorkoutButton = app.buttons["addScheduledWorkoutButton"]
        assertExists(addWorkoutButton, timeout: 5, "Add Workout button not found on schedule")
        addWorkoutButton.tap()

        let selectRoutineTitle = app.navigationBars["Select Routine"]
        assertExists(selectRoutineTitle, timeout: 5, "Routine picker sheet not shown")

        let routineRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", routineName)).firstMatch
        assertExists(routineRow, timeout: 10, "Routine '\(routineName)' not found in picker")
        routineRow.tap()

        // Wait for schedule to update
        waitForAnimation()
    }

    // MARK: - Cleanup Helpers

    func cleanupRoutines(containing substring: String) {
        navigateToRoutinesTab()

        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let matchingRows = app.buttons.matching(predicate)
        guard matchingRows.count > 0 else { return }

        let modifyButton = app.buttons["modifyRoutinesButton"]
        guard modifyButton.waitForExistence(timeout: 5) else { return }
        modifyButton.tap()
        waitForAnimation()

        for i in 0..<matchingRows.count {
            let row = matchingRows.element(boundBy: i)
            if row.isHittable {
                row.tap()
            } else {
                app.swipeUp()
                waitForAnimation()
                if row.isHittable { row.tap() }
            }
            waitForAnimation()
        }

        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Delete'")).firstMatch
        if deleteButton.waitForExistence(timeout: 3) {
            deleteButton.tap()
        }

        let confirmDelete = app.alerts.buttons["Delete"]
        if confirmDelete.waitForExistence(timeout: 3) {
            confirmDelete.tap()
            _ = confirmDelete.waitForNonExistence(timeout: 3)
        }
    }

    func cleanupCompletedWorkouts() {
        navigateToScheduleTab()

        while true {
            let completedCard = app.buttons.matching(NSPredicate(
                format: "identifier == 'scheduledWorkoutCard' AND label CONTAINS 'Completed'"
            )).firstMatch
            guard completedCard.waitForExistence(timeout: 3), completedCard.isHittable else { break }
            completedCard.tap()

            let deleteButton = app.buttons["deleteWorkoutButton"]
            guard deleteButton.waitForExistence(timeout: 3) else {
                let back = app.navigationBars.buttons.element(boundBy: 0)
                if back.exists { back.tap() }
                waitForAnimation()
                break
            }
            deleteButton.tap()

            let confirmDelete = app.alerts.buttons["Delete"]
            if confirmDelete.waitForExistence(timeout: 3) {
                confirmDelete.tap()
                _ = confirmDelete.waitForNonExistence(timeout: 3)
            }
        }
    }

    func cleanupScheduledWorkouts() {
        navigateToScheduleTab()

        let modifyButton = app.buttons["modifyScheduleButton"]
        guard modifyButton.waitForExistence(timeout: 3) else { return }
        modifyButton.tap()
        waitForAnimation()

        let cards = app.otherElements.matching(identifier: "scheduledWorkoutCard")
        let cardButtons = app.buttons.matching(identifier: "scheduledWorkoutCard")
        let count = max(cards.count, cardButtons.count)
        for i in 0..<count {
            let card = cards.count > 0 ? cards.element(boundBy: i) : cardButtons.element(boundBy: i)
            if card.exists && card.isHittable {
                card.tap()
                waitForAnimation()
            }
        }

        let deleteButton = app.buttons["deleteScheduledWorkoutsButton"]
        if deleteButton.waitForExistence(timeout: 3) {
            deleteButton.tap()
        }

        let confirmRemove = app.alerts.buttons["Remove"]
        if confirmRemove.waitForExistence(timeout: 3) {
            confirmRemove.tap()
            _ = confirmRemove.waitForNonExistence(timeout: 3)
        }
    }

    func cleanupCustomExercises() {
        navigateToProfile()

        let seeAll = app.buttons["customExercisesSeeAll"]
        if !seeAll.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        guard seeAll.waitForExistence(timeout: 3) else { return }
        seeAll.tap()

        for _ in 0..<10 {
            let menuButton = app.buttons["customExerciseMenu"].firstMatch
            guard menuButton.waitForExistence(timeout: 3) else { break }
            menuButton.tap()
            waitForAnimation()

            let deleteOption = app.buttons["Delete Exercise"]
            guard deleteOption.waitForExistence(timeout: 3) else { break }
            deleteOption.tap()
            waitForAnimation()

            let confirmDelete = app.alerts.buttons["Delete"]
            if confirmDelete.waitForExistence(timeout: 3) {
                confirmDelete.tap()
                _ = confirmDelete.waitForNonExistence(timeout: 3)
            }
        }

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
        }
    }

    // MARK: - Workout Flow Helpers

    func discardActiveWorkout() {
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        }

        let cancelAlert = app.alerts["Cancel Workout?"]
        if cancelAlert.waitForExistence(timeout: 5) {
            cancelAlert.buttons["Discard"].tap()
            _ = cancelAlert.waitForNonExistence(timeout: 3)
        }
    }

    func scrollToBottom(maxSwipes: Int = 5) {
        for _ in 0..<maxSwipes {
            app.swipeUp()
            waitForAnimation()
        }
    }
}

// MARK: - Free User Base Case

/// Base class for UI tests that launch as a free (non-pro) user.
class FreeUserUITestBaseCase: UITestBaseCase {
    override var launchArguments: [String] {
        ["--uitesting", "--skip-auth-free"]
    }
}

// MARK: - Auth Flow Base Case

/// Base class for UI tests that start from the unauthenticated state.
class AuthFlowUITestBaseCase: UITestBaseCase {
    override var launchArguments: [String] {
        ["--uitesting", "--reset-auth"]
    }

    /// Navigate from auth selection to the login form.
    func navigateToLogin() {
        // Wait for splash screen to dismiss - poll for the auth button instead of sleeping
        let signInButton = app.buttons["Already Have an Account"]
        let signInText = app.staticTexts["Already Have an Account"]

        let found = signInButton.waitForExistence(timeout: 15) || signInText.waitForExistence(timeout: 3)
        XCTAssertTrue(found, "Auth selection screen not found")

        if signInButton.exists {
            signInButton.tap()
        } else {
            signInText.tap()
        }

        let emailField = app.textFields["loginEmailField"]
        assertExists(emailField, timeout: 10, "Login screen did not appear")
    }

    /// Navigate from auth selection to the email registration form.
    func navigateToRegister() {
        let getStartedButton = app.buttons["Let's Get Started"]
        let getStartedText = app.staticTexts["Let's Get Started"]

        let found = getStartedButton.waitForExistence(timeout: 15) || getStartedText.waitForExistence(timeout: 3)
        XCTAssertTrue(found, "Auth selection screen not found")

        if getStartedButton.exists {
            getStartedButton.tap()
        } else {
            getStartedText.tap()
        }

        let signUpWithEmail = app.buttons["Sign Up with Email"]
        if signUpWithEmail.waitForExistence(timeout: 5) {
            signUpWithEmail.tap()
        } else {
            let signUpText = app.staticTexts["Sign Up with Email"]
            assertExists(signUpText, timeout: 5, "Register selection screen not found")
            signUpText.tap()
        }

        let firstNameField = app.textFields["registerFirstNameField"]
        assertExists(firstNameField, timeout: 10, "Registration form did not appear")
    }

    /// Navigate from auth selection to the Forgot Password sheet.
    func navigateToForgotPassword() {
        navigateToLogin()

        let forgotPasswordButton = app.buttons["forgotPasswordButton"]
        assertExists(forgotPasswordButton, timeout: 10, "Forgot Password button not found")
        forgotPasswordButton.tap()

        let resetTitle = app.staticTexts["Reset Password"]
        assertExists(resetTitle, timeout: 5, "Forgot Password sheet did not appear")
    }
}

// MARK: - XCUIElement Non-Existence Helper

extension XCUIElement {
    /// Polls until the element no longer exists, up to the given timeout.
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
