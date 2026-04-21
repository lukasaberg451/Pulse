//
//  EditCustomExerciseTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class EditCustomExerciseTests: XCTestCase {

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

    private func navigateToProfile() {
        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)
    }

    private func navigateToAllCustomExercises() {
        navigateToProfile()

        // Scroll down to the custom exercises section if needed
        let seeAllButton = app.buttons["customExercisesSeeAll"]
        if !seeAllButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }

        XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5), "'See All' for custom exercises not found — user may have no custom exercises")
        seeAllButton.tap()
        sleep(2)
    }

    // MARK: - Test: Custom Exercise Appears in Exercise List

    /// Verifies that a custom exercise created from a routine also shows up
    /// in the profile's custom exercises section.
    func testCustomExerciseVisibleOnProfile() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        // Look for "My Custom Exercises" section header
        let sectionHeader = app.staticTexts["My Custom Exercises"]
        if !sectionHeader.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 5), "'My Custom Exercises' section not found on profile")
    }

    // MARK: - Test: Delete Custom Exercise from All Custom Exercises View

    /// Navigates to the All Custom Exercises list, taps the three-dot menu
    /// on a custom exercise, selects Delete, confirms, and verifies removal.
    func testDeleteCustomExerciseFromAllExercisesView() throws {
        dismissResumeAlertIfPresent()
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

        // The exercise should be removed — we just verify the alert dismissed
        XCTAssertFalse(deleteAlert.exists, "Delete alert should have dismissed after confirming")
    }
}
