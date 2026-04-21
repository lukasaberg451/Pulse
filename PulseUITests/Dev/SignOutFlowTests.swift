//
//  SignOutFlowTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class SignOutFlowTests: XCTestCase {

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
        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)

        let settingsButton = app.buttons["profileSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button not found")
        settingsButton.tap()
        sleep(2)
    }

    // MARK: - Test: Sign Out Completes and Returns to Auth Screen

    /// Taps Sign Out, confirms the alert, and verifies the auth selection
    /// screen appears (indicating the user was fully signed out).
    func testSignOutCompletesAndShowsAuthScreen() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll to find the Sign Out button if needed
        let signOutButton = app.buttons["settingsSignOutButton"]
        if !signOutButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 10), "Sign Out button not found")
        signOutButton.tap()
        sleep(1)

        // Confirm the alert
        let signOutAlert = app.alerts["Sign Out"]
        XCTAssertTrue(signOutAlert.waitForExistence(timeout: 5), "Sign Out confirmation alert not found")
        signOutAlert.buttons["Sign Out"].tap()

        // Wait for sign-out to complete (server session invalidation + UI transition)
        sleep(3)

        // Verify the auth selection screen appears
        let alreadyHaveAccountBtn = app.buttons["Already Have an Account"]
        let authScreenAppeared = alreadyHaveAccountBtn.waitForExistence(timeout: 30)
        XCTAssertTrue(authScreenAppeared, "Auth selection screen did not appear after sign out")

        let getStartedBtn = app.buttons["Let's Get Started"]
        XCTAssertTrue(getStartedBtn.waitForExistence(timeout: 10), "'Let's Get Started' button not found on auth screen")
    }

    // MARK: - Test: Sign Out then Sign In Round-Trip

    /// Signs out, then signs back in with test credentials and verifies
    /// the home screen appears — proving the full auth lifecycle works.
    func testSignOutThenSignInRoundTrip() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll to find Sign Out if needed
        let signOutButton = app.buttons["settingsSignOutButton"]
        if !signOutButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 10), "Sign Out button not found")
        signOutButton.tap()
        sleep(1)

        let signOutAlert = app.alerts["Sign Out"]
        XCTAssertTrue(signOutAlert.waitForExistence(timeout: 5), "Sign Out alert not found")
        signOutAlert.buttons["Sign Out"].tap()

        // Wait for sign-out to complete
        sleep(3)

        // Wait for auth screen
        let signInBtn = app.buttons["Already Have an Account"]
        XCTAssertTrue(signInBtn.waitForExistence(timeout: 30), "Auth screen did not appear after sign out")

        // Dismiss any system alerts (e.g. "Save Password" prompt)
        addUIInterruptionMonitor(withDescription: "Save Password") { alert in
            let notNow = alert.buttons["Not Now"]
            if notNow.exists {
                notNow.tap()
                return true
            }
            return false
        }

        // Navigate to login
        signInBtn.tap()
        sleep(2)

        // Enter credentials
        let emailField = app.textFields["loginEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "Email field not found")
        emailField.tap()
        emailField.typeText(TestSecrets.uitestEmail)

        let passwordField = app.secureTextFields["loginPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field not found")
        passwordField.tap()
        passwordField.typeText(TestSecrets.uitestPassword)

        let loginButton = app.buttons["loginButton"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5), "Login button not found")
        loginButton.tap()

        // Wait for server response and potential system prompts
        sleep(5)

        // Dismiss the iOS "Save Password" prompt if it appears
        let savePasswordButton = app.buttons["Not Now"]
        if savePasswordButton.waitForExistence(timeout: 5) {
            savePasswordButton.tap()
            sleep(1)
        }
        // Tap to dismiss any remaining system UI
        app.tap()
        sleep(2)

        // Verify the home screen appeared
        let dashboardTab = app.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 30), "Home screen did not appear after sign-in round-trip")
    }
}
