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
final class SmokeTests: UITestBaseCase {

    // MARK: - 1. App Launches and Dashboard Loads

    func testAppLaunchesAndDashboardLoads() throws {
        dismissResumeAlertIfPresent()

        let dashboardHeader = app.staticTexts.matching(identifier: "dashboardWelcomeText").firstMatch
        XCTAssertTrue(dashboardHeader.waitForExistence(timeout: 15), "Dashboard header not visible after launch")
    }

    // MARK: - 2. All Tabs Are Reachable

    func testAllTabsAreReachable() throws {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        assertExists(workoutTab, timeout: 10, "Workout tab not found")
        workoutTab.tap()
        _ = app.buttons["Routines"].waitForExistence(timeout: 5)

        let progressTab = app.buttons["Progress"]
        assertExists(progressTab, timeout: 10, "Progress tab not found")
        progressTab.tap()
        _ = app.staticTexts["Activity"].waitForExistence(timeout: 5)

        let profileTab = app.buttons["Profile"]
        assertExists(profileTab, timeout: 10, "Profile tab not found")
        profileTab.tap()
        _ = app.buttons["profileEditButton"].waitForExistence(timeout: 5)

        let dashboardTab = app.buttons["Dashboard"]
        assertExists(dashboardTab, timeout: 10, "Dashboard tab not found")
        dashboardTab.tap()
    }

    // MARK: - 3. Can View a Routine

    func testCanViewRoutine() throws {
        dismissResumeAlertIfPresent()
        navigateToRoutinesTab()

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found in the list")
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found on routine detail")
    }

    // MARK: - 4. Can Start and Discard a Workout

    func testCanStartAndDiscardWorkout() throws {
        dismissResumeAlertIfPresent()
        navigateToRoutinesTab()

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        assertExists(firstRoutine, timeout: 10)
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        assertExists(startButton, timeout: 10)
        startButton.tap()

        let finishButton = app.buttons["finishWorkoutButton"]
        assertExists(finishButton, timeout: 10, "Active workout did not appear")

        discardActiveWorkout()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 10), "Did not return after discarding workout")
    }

    // MARK: - 5. Progress Tab Loads Analytics

    func testProgressTabLoadsAnalytics() throws {
        dismissResumeAlertIfPresent()

        let progressTab = app.buttons["Progress"]
        assertExists(progressTab, timeout: 10)
        progressTab.tap()

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "Activity section not found on Progress tab")
    }

    // MARK: - 6. Profile Loads with User Info

    func testProfileLoadsWithUserInfo() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()
    }

    // MARK: - 7. Settings Is Reachable

    func testSettingsIsReachable() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let signOutButton = app.buttons["settingsSignOutButton"]
        XCTAssertTrue(signOutButton.exists, "Sign Out button not found in Settings")
    }

    // MARK: - 8. Schedule View Loads

    func testScheduleViewLoads() throws {
        dismissResumeAlertIfPresent()
        navigateToScheduleTab()
    }
}
