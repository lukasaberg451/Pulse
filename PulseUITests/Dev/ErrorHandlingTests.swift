//
//  ErrorHandlingTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-22.
//

import XCTest

// MARK: - Login Validation Error Tests

/// Tests that verify client-side validation errors on the Login screen.
/// Uses `--reset-auth` so the app starts from the unauthenticated state.
final class LoginValidationErrorTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate from the auth selection screen to the login form.
    private func navigateToLogin() {
        sleep(10) // Wait for splash screen to fully dismiss

        let signInButton = app.buttons["Already Have an Account"]
        if signInButton.waitForExistence(timeout: 5) {
            signInButton.tap()
        } else {
            let signInText = app.staticTexts["Already Have an Account"]
            XCTAssertTrue(signInText.waitForExistence(timeout: 5), "Auth selection screen not found")
            signInText.tap()
        }

        let emailField = app.textFields["loginEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "Login screen did not appear")
    }

    // MARK: - Test: Empty Email Shows Error

    func testLoginEmptyEmailShowsError() throws {
        // Arrange
        navigateToLogin()

        // Act — tap Sign In with no input
        let loginButton = app.buttons["loginButton"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5), "Login button not found")
        loginButton.tap()
        sleep(1)

        // Assert — error box appears with "Email is required"
        let errorBox = app.otherElements["loginErrorBox"]
        XCTAssertTrue(errorBox.waitForExistence(timeout: 5), "Error box did not appear for empty email")

        let errorText = app.staticTexts["loginErrorText"]
        XCTAssertTrue(errorText.exists, "Error text not found")
        XCTAssertEqual(errorText.label, "Email is required")
    }

    // MARK: - Test: Invalid Email Format Shows Error

    func testLoginInvalidEmailShowsError() throws {
        // Arrange
        navigateToLogin()

        let emailField = app.textFields["loginEmailField"]
        emailField.tap()
        emailField.typeText("notanemail")

        // Act
        let loginButton = app.buttons["loginButton"]
        loginButton.tap()
        sleep(1)

        // Assert
        let errorBox = app.otherElements["loginErrorBox"]
        XCTAssertTrue(errorBox.waitForExistence(timeout: 5), "Error box did not appear for invalid email")

        let errorText = app.staticTexts["loginErrorText"]
        XCTAssertTrue(errorText.exists, "Error text not found")
        XCTAssertEqual(errorText.label, "Please enter a valid email address")
    }

    // MARK: - Test: Empty Password Shows Error

    func testLoginEmptyPasswordShowsError() throws {
        // Arrange
        navigateToLogin()

        let emailField = app.textFields["loginEmailField"]
        emailField.tap()
        emailField.typeText("valid@example.com")

        // Act — leave password empty and submit
        let loginButton = app.buttons["loginButton"]
        loginButton.tap()
        sleep(1)

        // Assert
        let errorBox = app.otherElements["loginErrorBox"]
        XCTAssertTrue(errorBox.waitForExistence(timeout: 5), "Error box did not appear for empty password")

        let errorText = app.staticTexts["loginErrorText"]
        XCTAssertTrue(errorText.exists, "Error text not found")
        XCTAssertEqual(errorText.label, "Password is required")
    }

    // MARK: - Test: Wrong Credentials Shows Error

    func testLoginWrongCredentialsShowsError() throws {
        // Arrange
        navigateToLogin()

        let emailField = app.textFields["loginEmailField"]
        emailField.tap()
        emailField.typeText("wrong@example.com")

        let passwordField = app.secureTextFields["loginPasswordField"]
        passwordField.tap()
        passwordField.typeText("WrongPassword1")

        // Act
        let loginButton = app.buttons["loginButton"]
        loginButton.tap()

        // Assert — wait for the server round-trip error
        let errorBox = app.otherElements["loginErrorBox"]
        XCTAssertTrue(errorBox.waitForExistence(timeout: 15), "Error box did not appear for wrong credentials")

        let errorText = app.staticTexts["loginErrorText"]
        XCTAssertTrue(errorText.exists, "Error text not found")
        XCTAssertEqual(errorText.label, "Invalid email or password. Please try again.")
    }

    // MARK: - Test: Error Clears When Typing

    func testLoginErrorClearsOnTyping() throws {
        // Arrange — trigger an error first
        navigateToLogin()

        let loginButton = app.buttons["loginButton"]
        loginButton.tap()
        sleep(1)

        let errorBox = app.otherElements["loginErrorBox"]
        XCTAssertTrue(errorBox.waitForExistence(timeout: 5), "Error box did not appear")

        // Act — start typing in the email field
        let emailField = app.textFields["loginEmailField"]
        emailField.tap()
        emailField.typeText("a")
        sleep(1)

        // Assert — error should be dismissed
        XCTAssertFalse(errorBox.exists, "Error box should disappear when user starts typing")
    }

    // MARK: - Test: Rate Limit After Wrong Credentials

    func testLoginRateLimitAfterFailedAttempts() throws {
        // Arrange
        navigateToLogin()

        let emailField = app.textFields["loginEmailField"]
        let passwordField = app.secureTextFields["loginPasswordField"]
        let loginButton = app.buttons["loginButton"]

        // Act — submit wrong credentials to trigger rate limiting
        emailField.tap()
        emailField.typeText("wrong@example.com")
        passwordField.tap()
        passwordField.typeText("WrongPassword1")
        loginButton.tap()

        // The rate limit countdown (2s) starts when the server responds.
        // Poll rapidly to catch the brief "Wait Xs" label before it expires.
        let deadline = Date().addingTimeInterval(20)
        var foundWait = false
        while Date() < deadline {
            let currentLabel = app.buttons["loginButton"].label
            if currentLabel.hasPrefix("Wait") {
                foundWait = true
                break
            }
            usleep(200_000) // 0.2s
        }

        XCTAssertTrue(foundWait, "Rate limit 'Wait Xs' button did not appear after failed attempt")
    }
}

// MARK: - Registration Validation Error Tests

/// Tests that verify client-side validation errors on the Registration screen.
/// Uses `--reset-auth` so the app starts from the unauthenticated state.
final class RegistrationValidationErrorTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate from the auth selection screen to the email registration form.
    private func navigateToRegister() {
        sleep(10) // Wait for splash screen to fully dismiss

        let getStartedButton = app.buttons["Let's Get Started"]
        if getStartedButton.waitForExistence(timeout: 5) {
            getStartedButton.tap()
        } else {
            let getStartedText = app.staticTexts["Let's Get Started"]
            XCTAssertTrue(getStartedText.waitForExistence(timeout: 5), "Auth selection screen not found")
            getStartedText.tap()
        }
        sleep(2)

        // Tap "Sign Up with Email"
        let signUpWithEmail = app.buttons["Sign Up with Email"]
        if signUpWithEmail.waitForExistence(timeout: 5) {
            signUpWithEmail.tap()
        } else {
            let signUpText = app.staticTexts["Sign Up with Email"]
            XCTAssertTrue(signUpText.waitForExistence(timeout: 5), "Register selection screen not found")
            signUpText.tap()
        }

        let firstNameField = app.textFields["registerFirstNameField"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 10), "Registration form did not appear")
    }

    // MARK: - Test: Empty Fields Shows Error

    func testRegisterEmptyFieldsShowsError() throws {
        // Arrange
        navigateToRegister()

        // The Sign Up button is disabled when fields are empty,
        // so we need to fill partial data then submit to trigger the
        // server-side validation path. Instead, test the button is disabled.

        // Act — try to find the Sign Up button
        let signUpButton = app.buttons["registerButton"]
        XCTAssertTrue(signUpButton.waitForExistence(timeout: 5), "Sign Up button not found")

        // Assert — the button should be disabled when all fields are empty
        XCTAssertFalse(signUpButton.isEnabled, "Sign Up button should be disabled when fields are empty")
    }

    // MARK: - Test: Invalid Email Shows Error

    func testRegisterInvalidEmailShowsError() throws {
        // Arrange
        navigateToRegister()

        let firstNameField = app.textFields["registerFirstNameField"]
        firstNameField.tap()
        firstNameField.typeText("Test")

        let lastNameField = app.textFields["registerLastNameField"]
        lastNameField.tap()
        lastNameField.typeText("User")

        let emailField = app.textFields["registerEmailField"]
        emailField.tap()
        emailField.typeText("notanemail")

        // Enter a valid password to enable the button
        let passwordField = app.secureTextFields["registerPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field not found")
        passwordField.tap()
        passwordField.typeText("ValidPass1")

        // Agree to terms — tap the checkbox
        let termsCheckbox = app.buttons["termsCheckbox"]
        if termsCheckbox.waitForExistence(timeout: 3) {
            termsCheckbox.tap()
            sleep(1)
        }

        // Assert — button should still be disabled due to invalid email
        let signUpButton = app.buttons["registerButton"]
        XCTAssertTrue(signUpButton.waitForExistence(timeout: 5), "Sign Up button not found")
        XCTAssertFalse(signUpButton.isEnabled, "Sign Up button should be disabled with invalid email format")
    }

    // MARK: - Test: Weak Password Keeps Button Disabled

    func testRegisterWeakPasswordDisablesButton() throws {
        // Arrange
        navigateToRegister()

        let firstNameField = app.textFields["registerFirstNameField"]
        firstNameField.tap()
        firstNameField.typeText("Test")

        let lastNameField = app.textFields["registerLastNameField"]
        lastNameField.tap()
        lastNameField.typeText("User")

        let emailField = app.textFields["registerEmailField"]
        emailField.tap()
        emailField.typeText("test@example.com")

        // Enter a weak password (too short, no uppercase, no number)
        let passwordField = app.secureTextFields["registerPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field not found")
        passwordField.tap()
        passwordField.typeText("short")

        // Assert — button should be disabled
        let signUpButton = app.buttons["registerButton"]
        XCTAssertTrue(signUpButton.waitForExistence(timeout: 5), "Sign Up button not found")
        XCTAssertFalse(signUpButton.isEnabled, "Sign Up button should be disabled with a weak password")

        // Also verify the password strength indicator shows "Weak"
        let weakIndicator = app.staticTexts["Weak"]
        XCTAssertTrue(weakIndicator.waitForExistence(timeout: 3), "Password strength indicator should show 'Weak'")
    }

    // MARK: - Test: Password Without Number Disables Button

    func testRegisterPasswordWithoutNumberDisablesButton() throws {
        // Arrange
        navigateToRegister()

        let firstNameField = app.textFields["registerFirstNameField"]
        firstNameField.tap()
        firstNameField.typeText("Test")

        let lastNameField = app.textFields["registerLastNameField"]
        lastNameField.tap()
        lastNameField.typeText("User")

        let emailField = app.textFields["registerEmailField"]
        emailField.tap()
        emailField.typeText("test@example.com")

        // Enter a password missing a number
        let passwordField = app.secureTextFields["registerPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field not found")
        passwordField.tap()
        passwordField.typeText("NoNumberPass")

        // Assert — button should be disabled (password needs uppercase, lowercase, number, 8+ chars)
        let signUpButton = app.buttons["registerButton"]
        XCTAssertTrue(signUpButton.waitForExistence(timeout: 5), "Sign Up button not found")
        XCTAssertFalse(signUpButton.isEnabled, "Sign Up button should be disabled when password has no number")
    }

    // MARK: - Test: Terms Not Agreed Keeps Button Disabled

    func testRegisterTermsNotAgreedDisablesButton() throws {
        // Arrange — fill all fields correctly but don't agree to terms
        navigateToRegister()

        let firstNameField = app.textFields["registerFirstNameField"]
        firstNameField.tap()
        firstNameField.typeText("Test")

        let lastNameField = app.textFields["registerLastNameField"]
        lastNameField.tap()
        lastNameField.typeText("User")

        let emailField = app.textFields["registerEmailField"]
        emailField.tap()
        emailField.typeText("test@example.com")

        let passwordField = app.secureTextFields["registerPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field not found")
        passwordField.tap()
        passwordField.typeText("ValidPass1")

        // Act — do NOT tap the terms checkbox

        // Assert — button should be disabled
        let signUpButton = app.buttons["registerButton"]
        XCTAssertTrue(signUpButton.waitForExistence(timeout: 5), "Sign Up button not found")
        XCTAssertFalse(signUpButton.isEnabled, "Sign Up button should be disabled when terms are not agreed")
    }
}

// MARK: - Forgot Password Validation Error Tests

/// Tests that verify client-side validation on the Forgot Password flow.
/// Uses `--reset-auth` so the app starts from the unauthenticated state.
final class ForgotPasswordValidationErrorTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate from auth selection → Login → Forgot Password sheet.
    private func navigateToForgotPassword() {
        sleep(10) // Wait for splash screen to fully dismiss

        let signInButton = app.buttons["Already Have an Account"]
        if signInButton.waitForExistence(timeout: 5) {
            signInButton.tap()
        } else {
            let signInText = app.staticTexts["Already Have an Account"]
            XCTAssertTrue(signInText.waitForExistence(timeout: 5), "Auth selection screen not found")
            signInText.tap()
        }

        let forgotPasswordButton = app.buttons["forgotPasswordButton"]
        XCTAssertTrue(forgotPasswordButton.waitForExistence(timeout: 10), "Forgot Password button not found")
        forgotPasswordButton.tap()
        sleep(2)

        // Verify the forgot password sheet appeared
        let resetTitle = app.staticTexts["Reset Password"]
        XCTAssertTrue(resetTitle.waitForExistence(timeout: 5), "Forgot Password sheet did not appear")
    }

    // MARK: - Test: Empty Email Shows Error

    func testForgotPasswordEmptyEmailShowsError() throws {
        // Arrange
        navigateToForgotPassword()

        // Act — tap "Send Code" without entering an email
        let sendCodeButton = app.buttons["Send Code"]
        XCTAssertTrue(sendCodeButton.waitForExistence(timeout: 5), "Send Code button not found")
        sendCodeButton.tap()
        sleep(1)

        // Assert
        let errorBox = app.otherElements["forgotPasswordErrorBox"]
        XCTAssertTrue(errorBox.waitForExistence(timeout: 5), "Error box did not appear for empty email")

        let errorText = app.staticTexts["forgotPasswordErrorText"]
        XCTAssertTrue(errorText.exists, "Error text not found")
        XCTAssertEqual(errorText.label, "Email is required")
    }

    // MARK: - Test: Invalid Email Shows Error

    func testForgotPasswordInvalidEmailShowsError() throws {
        // Arrange
        navigateToForgotPassword()

        // Type an invalid email
        let emailField = app.textFields["forgotPasswordEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email field not found")
        emailField.tap()
        emailField.typeText("notanemail")

        // Act
        let sendCodeButton = app.buttons["Send Code"]
        sendCodeButton.tap()
        sleep(1)

        // Assert
        let errorBox = app.otherElements["forgotPasswordErrorBox"]
        XCTAssertTrue(errorBox.waitForExistence(timeout: 5), "Error box did not appear for invalid email")

        let errorText = app.staticTexts["forgotPasswordErrorText"]
        XCTAssertTrue(errorText.exists, "Error text not found")
        XCTAssertEqual(errorText.label, "Please enter a valid email address")
    }
}

// MARK: - Routine Error Handling Tests

/// Tests that verify error-related behavior during routine management.
/// Uses `--skip-auth` to land on the authenticated home screen.
final class RoutineErrorHandlingTests: XCTestCase {

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
            app = nil
        }
    }

    // MARK: - Helpers

    /// Dismiss any leftover "Resume Workout?" alert.
    private func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }
    }

    /// Navigate to the Routines sub-tab inside the Workout tab.
    private func navigateToRoutinesTab() {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5), "Routines pill not found")
        routinesPill.tap()
        sleep(2)
    }

    /// Delete all routines whose names contain the given substring.
    private func cleanupRoutines(containing substring: String) {
        navigateToRoutinesTab()
        sleep(2)

        let routineRows = app.buttons.matching(identifier: "routineRow")
        guard routineRows.count > 0 else { return }

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

    // MARK: - Test: Create Routine Button Disabled When Name Is Empty

    func testCreateRoutineDisabledWithEmptyName() throws {
        // Arrange
        navigateToRoutinesTab()

        let newRoutineButton = app.buttons["newRoutineButton"]
        XCTAssertTrue(newRoutineButton.waitForExistence(timeout: 10), "New Routine button not found")
        newRoutineButton.tap()
        sleep(1)

        // Act — don't type anything in the name field

        // Assert — the Create Routine button should be disabled
        let createButton = app.buttons["createRoutineButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create Routine button not found")
        XCTAssertFalse(createButton.isEnabled, "Create Routine button should be disabled when name is empty")
    }

    // MARK: - Test: Create Routine Button Enables When Name Is Entered

    func testCreateRoutineEnablesWithName() throws {
        // Arrange
        navigateToRoutinesTab()

        let newRoutineButton = app.buttons["newRoutineButton"]
        XCTAssertTrue(newRoutineButton.waitForExistence(timeout: 10), "New Routine button not found")
        newRoutineButton.tap()
        sleep(1)

        // Act — type a name
        let nameField = app.textFields["routineNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Routine name field not found")
        nameField.tap()
        nameField.typeText("UITest Enable \(uniqueSuffix)")

        // Assert — the Create Routine button should now be enabled
        let createButton = app.buttons["createRoutineButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create Routine button not found")
        XCTAssertTrue(createButton.isEnabled, "Create Routine button should be enabled when name is provided")

        // Cancel without creating to avoid test data
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        }
    }

    // MARK: - Test: Delete Routine Shows Confirmation Alert

    func testDeleteRoutineShowsConfirmationAlert() throws {
        let routineName = "UITest DelErr \(uniqueSuffix)"

        // Arrange — create a routine to delete
        navigateToRoutinesTab()

        let newRoutineButton = app.buttons["newRoutineButton"]
        XCTAssertTrue(newRoutineButton.waitForExistence(timeout: 10), "New Routine button not found")
        newRoutineButton.tap()

        let nameField = app.textFields["routineNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Routine name field not found")
        nameField.tap()
        nameField.typeText(routineName)

        let createButton = app.buttons["createRoutineButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create button not found")
        createButton.tap()
        sleep(3)

        // Navigate back to the list
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            sleep(2)
        }

        // Act — enter modify mode and select the routine
        let modifyButton = app.buttons["modifyRoutinesButton"]
        XCTAssertTrue(modifyButton.waitForExistence(timeout: 5), "Modify button not found")
        modifyButton.tap()
        sleep(1)

        let routineRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", routineName)).firstMatch
        XCTAssertTrue(routineRow.waitForExistence(timeout: 5), "Routine row not found")
        routineRow.tap()
        sleep(1)

        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Delete'")).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button not found")
        deleteButton.tap()
        sleep(1)

        // Assert — confirmation alert should appear
        let deleteAlert = app.alerts.firstMatch
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5), "Delete confirmation alert did not appear")

        let confirmButton = deleteAlert.buttons["Delete"]
        XCTAssertTrue(confirmButton.exists, "Delete confirmation button not found in alert")

        let cancelAlertButton = deleteAlert.buttons["Cancel"]
        XCTAssertTrue(cancelAlertButton.exists, "Cancel button not found in alert")

        // Act — cancel the deletion
        cancelAlertButton.tap()
        sleep(1)

        // Assert — routine should still exist
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            sleep(1)
        }

        let routineStillExists = app.staticTexts[routineName]
        XCTAssertTrue(routineStillExists.waitForExistence(timeout: 5), "Routine should still exist after cancelling deletion")

        // Cleanup
        cleanupRoutines(containing: String(uniqueSuffix))
    }

    // MARK: - Test: Empty Routine Shows No Exercises State

    func testEmptyRoutineShowsNoExercisesState() throws {
        let routineName = "UITest Empty \(uniqueSuffix)"

        // Arrange — create a routine with no exercises
        navigateToRoutinesTab()

        let newRoutineButton = app.buttons["newRoutineButton"]
        XCTAssertTrue(newRoutineButton.waitForExistence(timeout: 10), "New Routine button not found")
        newRoutineButton.tap()

        let nameField = app.textFields["routineNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Routine name field not found")
        nameField.tap()
        nameField.typeText(routineName)

        let createButton = app.buttons["createRoutineButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create button not found")
        createButton.tap()
        sleep(3)

        // Assert — "No Exercises Yet" empty state should appear
        let noExercises = app.staticTexts["No Exercises Yet"]
        XCTAssertTrue(noExercises.waitForExistence(timeout: 5), "Empty exercises state not shown for new routine")

        // Cleanup
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
            sleep(1)
        }
        cleanupRoutines(containing: String(uniqueSuffix))
    }
}

// MARK: - Schedule Error Handling Tests

/// Tests that verify error-related behavior during schedule management.
/// Uses `--skip-auth` to land on the authenticated home screen.
final class ScheduleErrorHandlingTests: XCTestCase {

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

    // MARK: - Helpers

    private func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }
    }

    private func navigateToScheduleTab() {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        let schedulePill = app.buttons["Schedule"]
        XCTAssertTrue(schedulePill.waitForExistence(timeout: 5), "Schedule pill not found")
        schedulePill.tap()
        sleep(2)
    }

    // MARK: - Test: Schedule Workout Requires Routine Selection

    func testScheduleWorkoutRequiresRoutineSelection() throws {
        // Arrange
        navigateToScheduleTab()

        // Act — tap a calendar day to open the schedule sheet
        let addButton = app.buttons["addScheduledWorkoutButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add Scheduled Workout button not found")
        addButton.tap()
        sleep(2)

        // Assert — the routine selection sheet should appear, requiring a routine pick
        let sheetTitle = app.navigationBars["Select Routine"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Select Routine sheet did not appear — user must pick a routine to schedule")
    }
}

// MARK: - Settings Error Handling Tests

/// Tests that verify confirmation flows for destructive actions in Settings.
/// Uses `--skip-auth` to land on the authenticated home screen.
final class SettingsErrorHandlingTests: XCTestCase {

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

    // MARK: - Helpers

    private func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }
    }

    private func navigateToSettings() {
        dismissResumeAlertIfPresent()

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)

        let settingsButton = app.buttons["profileSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button not found")
        settingsButton.tap()
        sleep(2)
    }

    // MARK: - Test: Sign Out Shows Confirmation Alert

    func testSignOutShowsConfirmationAndCanCancel() throws {
        // Arrange
        navigateToSettings()

        // Scroll down to find Sign Out button
        app.swipeUp()
        sleep(1)

        // Act
        let signOutButton = app.buttons["settingsSignOutButton"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5), "Sign Out button not found")
        signOutButton.tap()
        sleep(1)

        // Assert — confirmation alert appears
        let signOutAlert = app.alerts["Sign Out"]
        XCTAssertTrue(signOutAlert.waitForExistence(timeout: 5), "Sign Out confirmation alert did not appear")

        let cancelButton = signOutAlert.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found in Sign Out alert")

        // Act — cancel the sign out
        cancelButton.tap()
        sleep(1)

        // Assert — still on settings screen
        let settingsTitle = app.navigationBars.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.exists || app.buttons["settingsSignOutButton"].exists,
                      "Should remain on Settings screen after cancelling sign out")
    }

    // MARK: - Test: Delete Account Shows Two-Step Confirmation

    func testDeleteAccountShowsConfirmationAndCanCancel() throws {
        // Arrange
        navigateToSettings()

        // Scroll down to find Delete Account button
        app.swipeUp()
        sleep(1)
        app.swipeUp()
        sleep(1)

        // Act
        let deleteAccountButton = app.buttons["settingsDeleteAccountButton"]
        XCTAssertTrue(deleteAccountButton.waitForExistence(timeout: 5), "Delete Account button not found")
        deleteAccountButton.tap()
        sleep(1)

        // Assert — first confirmation alert appears
        let deleteAlert = app.alerts["Delete Account"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5), "Delete Account confirmation alert did not appear")

        let cancelButton = deleteAlert.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found in Delete Account alert")

        // Act — cancel the deletion
        cancelButton.tap()
        sleep(1)

        // Assert — still on settings screen
        XCTAssertTrue(deleteAccountButton.waitForExistence(timeout: 5),
                      "Should remain on Settings screen after cancelling account deletion")
    }
}
