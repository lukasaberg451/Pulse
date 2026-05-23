//
//  SignOutFlowTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class SignOutFlowTests: UITestBaseCase {

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
            waitForAnimation()
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 10), "Sign Out button not found")
        signOutButton.tap()

        // Confirm the alert
        let signOutAlert = app.alerts["Sign Out"]
        XCTAssertTrue(signOutAlert.waitForExistence(timeout: 5), "Sign Out confirmation alert not found")
        signOutAlert.buttons["Sign Out"].tap()

        // Verify the auth selection screen appears
        let alreadyHaveAccountBtn = app.buttons["Already Have an Account"]
        let authScreenAppeared = alreadyHaveAccountBtn.waitForExistence(timeout: 30)
        XCTAssertTrue(authScreenAppeared, "Auth selection screen did not appear after sign out")

        let getStartedBtn = app.buttons["Let's Get Started"]
        XCTAssertTrue(getStartedBtn.waitForExistence(timeout: 10), "'Let's Get Started' button not found on auth screen")
    }

    // MARK: - Test: Sign Out then Sign In Round-Trip

    /// Signs out, then signs back in with test credentials and verifies
    /// the home screen appears - proving the full auth lifecycle works.
    func testSignOutThenSignInRoundTrip() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll to find Sign Out if needed
        let signOutButton = app.buttons["settingsSignOutButton"]
        if !signOutButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 10), "Sign Out button not found")
        signOutButton.tap()

        let signOutAlert = app.alerts["Sign Out"]
        XCTAssertTrue(signOutAlert.waitForExistence(timeout: 5), "Sign Out alert not found")
        signOutAlert.buttons["Sign Out"].tap()

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
        waitForAnimation()

        // If the tap didn't navigate (system alert intercepted), retry
        let emailField = app.textFields["loginEmailField"]
        if !emailField.waitForExistence(timeout: 5) {
            // Tap again in case a system alert consumed the first tap
            if signInBtn.exists {
                signInBtn.tap()
                waitForAnimation()
            }
        }
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "Email field not found")
        emailField.tap()
        emailField.typeText(TestSecrets.uitestEmail)

        let passwordField = app.secureTextFields["loginPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field not found")
        passwordField.tap()
        passwordField.typeText(TestSecrets.uitestPassword)

        let loginButton = app.buttons["loginButton"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5), "Login button not found")
        loginButton.tap()

        // Dismiss the iOS "Save Password" prompt if it appears
        let savePasswordButton = app.buttons["Not Now"]
        if savePasswordButton.waitForExistence(timeout: 10) {
            savePasswordButton.tap()
            waitForAnimation()
        }
        // Tap to dismiss any remaining system UI
        app.tap()
        waitForAnimation()

        // Verify the home screen appeared
        let dashboardTab = app.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 30), "Home screen did not appear after sign-in round-trip")
    }
}
