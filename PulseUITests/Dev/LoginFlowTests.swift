//
//  LoginFlowTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-20.
//

import XCTest

final class LoginFlowTests: XCTestCase {

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

        // Wait for splash screen to fully dismiss
        sleep(10)

        // Navigate to login
        let signInButton = app.buttons["Already Have an Account"]
        if signInButton.waitForExistence(timeout: 5) {
            signInButton.tap()
        } else {
            let signInText = app.staticTexts["Already Have an Account"]
            XCTAssertTrue(signInText.waitForExistence(timeout: 5), "Auth selection screen not found")
            signInText.tap()
        }

        let emailField = app.textFields["loginEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "Email field not found")
        emailField.tap()
        emailField.typeText(TestSecrets.uitestEmail)

        let passwordField = app.secureTextFields["loginPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3), "Password field not found")
        passwordField.tap()
        passwordField.typeText(TestSecrets.uitestPassword)

        let loginButton = app.buttons["loginButton"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 3), "Login button not found")
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
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 20), "Home screen did not appear after login")
    }
}
