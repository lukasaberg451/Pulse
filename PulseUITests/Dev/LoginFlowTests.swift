//
//  LoginFlowTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-20.
//

import XCTest

final class LoginFlowTests: AuthFlowUITestBaseCase {

    func testLoginWithValidCredentials() throws {
        // Dismiss any system alerts (e.g. "Save Password" prompt) automatically
        addUIInterruptionMonitor(withDescription: "Save Password") { alert in
            let notNow = alert.buttons["Not Now"]
            if notNow.exists {
                notNow.tap()
                return true
            }
            return false
        }

        // Navigate to login using base class helper (waits for splash dismissal)
        navigateToLogin()

        let emailField = app.textFields["loginEmailField"]
        assertExists(emailField, timeout: 10, "Email field not found")
        emailField.tap()
        emailField.typeText(TestSecrets.uitestEmail)

        let passwordField = app.secureTextFields["loginPasswordField"]
        assertExists(passwordField, timeout: 3, "Password field not found")
        passwordField.tap()
        passwordField.typeText(TestSecrets.uitestPassword)

        let loginButton = app.buttons["loginButton"]
        assertExists(loginButton, timeout: 3, "Login button not found")
        loginButton.tap()

        // Dismiss the iOS "Save Password" prompt if it appears
        let savePasswordButton = app.buttons["Not Now"]
        if savePasswordButton.waitForExistence(timeout: 5) {
            savePasswordButton.tap()
        }
        // Tap the app to trigger any pending UI interruption monitors
        app.tap()

        // Assert the home screen appeared (post-login loading takes ~4s)
        let dashboardTab = app.staticTexts["Dashboard"]
        assertExists(dashboardTab, timeout: 20, "Home screen did not appear after login")
    }
}
