//
//  SmokeTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-20.
//

import XCTest

/// Lightweight smoke tests that run before every release.
/// These verify the critical user paths work end-to-end without
/// going deep into edge cases. If any of these fail, the build
/// should NOT be shipped.
final class SmokeTests: XCTestCase {

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

    // MARK: - 1. App Launches and Dashboard Loads

    /// The most basic test: app launches, auth completes, and the
    /// dashboard is visible with key elements.
    func testAppLaunchesAndDashboardLoads() throws {
        dismissResumeAlertIfPresent()

        let dashboardHeader = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] 'Welcome' OR label CONTAINS[c] 'Good'"
        )).firstMatch
        XCTAssertTrue(dashboardHeader.waitForExistence(timeout: 15), "Dashboard header not visible after launch")
    }

    // MARK: - 2. All Tabs Are Reachable

    /// Taps through every tab and verifies each one loads without crashing.
    func testAllTabsAreReachable() throws {
        dismissResumeAlertIfPresent()

        // Workout tab
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        // Progress tab
        let progressTab = app.buttons["Progress"]
        XCTAssertTrue(progressTab.waitForExistence(timeout: 10), "Progress tab not found")
        progressTab.tap()
        sleep(2)

        // Profile tab
        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "Profile tab not found")
        profileTab.tap()
        sleep(2)

        // Back to Dashboard
        let dashboardTab = app.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10), "Dashboard tab not found")
        dashboardTab.tap()
        sleep(1)
    }

    // MARK: - 3. Can View a Routine

    /// Navigates to the Routines list and opens the first routine.
    /// Verifies the routine detail view loads with a Start Workout button.
    func testCanViewRoutine() throws {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10))
        workoutTab.tap()
        sleep(2)

        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5))
        routinesPill.tap()
        sleep(2)

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found in the list")
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found on routine detail")
    }

    // MARK: - 4. Can Start and Discard a Workout

    /// Starts a workout and immediately discards it. Verifies the full
    /// start → cancel → discard flow works without crashing.
    func testCanStartAndDiscardWorkout() throws {
        dismissResumeAlertIfPresent()

        // Navigate to first routine
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10))
        workoutTab.tap()
        sleep(2)

        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5))
        routinesPill.tap()
        sleep(2)

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10))
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        // Active workout should appear
        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout did not appear")

        // Cancel → Discard
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        let cancelAlert = app.alerts["Cancel Workout?"]
        XCTAssertTrue(cancelAlert.waitForExistence(timeout: 5))
        cancelAlert.buttons["Discard"].tap()
        sleep(2)

        // Should be back on routine detail or workout tab
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10), "Did not return after discarding workout")
    }

    // MARK: - 5. Progress Tab Loads Analytics

    /// Verifies the Progress tab loads with the Activity section
    /// and at least the streak card (pro user).
    func testProgressTabLoadsAnalytics() throws {
        dismissResumeAlertIfPresent()

        let progressTab = app.buttons["Progress"]
        XCTAssertTrue(progressTab.waitForExistence(timeout: 10))
        progressTab.tap()
        sleep(3)

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "Activity section not found on Progress tab")
    }

    // MARK: - 6. Profile Loads with User Info

    /// Verifies the Profile tab loads and shows the user's profile
    /// header with an edit option.
    func testProfileLoadsWithUserInfo() throws {
        dismissResumeAlertIfPresent()

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()
        sleep(3)

        let editProfile = app.buttons["profileEditButton"]
        XCTAssertTrue(editProfile.waitForExistence(timeout: 10), "Profile header not found")
    }

    // MARK: - 7. Settings Is Reachable

    /// Navigates from Profile to Settings and verifies key sections load.
    func testSettingsIsReachable() throws {
        dismissResumeAlertIfPresent()

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()
        sleep(3)

        let settingsButton = app.buttons["profileSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()
        sleep(2)

        // Verify key settings rows exist
        let planButton = app.buttons["settingsPlanButton"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 5), "Plan button not found in Settings")

        let signOutButton = app.buttons["settingsSignOutButton"]
        XCTAssertTrue(signOutButton.exists, "Sign Out button not found in Settings")
    }

    // MARK: - 8. Schedule View Loads

    /// Navigates to the Schedule sub-tab and verifies it loads.
    func testScheduleViewLoads() throws {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10))
        workoutTab.tap()
        sleep(2)

        let schedulePill = app.buttons["Schedule"]
        XCTAssertTrue(schedulePill.waitForExistence(timeout: 5), "Schedule pill not found")
        schedulePill.tap()
        sleep(2)

        // Schedule should show calendar month navigation
        // or at minimum not crash
        let scheduleContent = app.scrollViews.firstMatch
        XCTAssertTrue(scheduleContent.waitForExistence(timeout: 5), "Schedule content not found")
    }
}
