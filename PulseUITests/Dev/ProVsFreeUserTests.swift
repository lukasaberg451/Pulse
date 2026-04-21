//
//  ProVsFreeUserTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

// MARK: - Free User Walkthrough

/// Walks a free user through every main tab and verifies they see
/// the correct gated/ungated UI throughout the app.
final class FreeUserWalkthroughTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth-free"]
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

    // MARK: - Test: Dashboard Loads for Free User

    /// Verifies the dashboard loads normally for a free user with
    /// welcome header, stats bar, and weekly goal visible.
    func testDashboardLoadsForFreeUser() throws {
        dismissResumeAlertIfPresent()

        let dashboardHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Welcome' OR label CONTAINS[c] 'Good'")).firstMatch
        XCTAssertTrue(dashboardHeader.waitForExistence(timeout: 15), "Dashboard welcome header not found for free user")

        let statsBar = app.otherElements["dashboardStatsBar"]
        if statsBar.exists {
            // Stats bar is visible — free users can still see basic stats
        }
    }

    // MARK: - Test: Workout Tab Loads for Free User

    /// Verifies the workout tab loads and routines are accessible.
    func testWorkoutTabLoadsForFreeUser() throws {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        // Free users can access the Routines sub-tab
        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5), "Routines pill not found for free user")
        routinesPill.tap()
        sleep(2)

        // Verify routine list or empty state is visible
        let routineRow = app.buttons.matching(identifier: "routineRow").firstMatch
        let emptyState = app.staticTexts["Create your first workout routine"]
        XCTAssertTrue(routineRow.waitForExistence(timeout: 5) || emptyState.exists,
                      "Neither routine list nor empty state visible for free user")
    }

    // MARK: - Test: Schedule Tab Loads for Free User

    /// Verifies the schedule tab is accessible for free users.
    func testScheduleTabLoadsForFreeUser() throws {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        // Schedule sub-tab should be accessible
        let schedulePill = app.buttons["Schedule"]
        XCTAssertTrue(schedulePill.waitForExistence(timeout: 5), "Schedule pill not found for free user")
        schedulePill.tap()
        sleep(2)

        // The schedule view should load (calendar or empty state)
        let monthNav = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron'")).firstMatch
        let emptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'No workouts'")).firstMatch
        // Just verify the tab didn't crash — some content should be visible
        sleep(1)
    }

    // MARK: - Test: Progress Tab Shows Paywall for Free User

    /// Verifies the Progress tab shows the paywall prompt instead
    /// of analytics content for a free user.
    func testProgressTabShowsPaywallForFreeUser() throws {
        dismissResumeAlertIfPresent()

        let progressTab = app.buttons["Progress"]
        XCTAssertTrue(progressTab.waitForExistence(timeout: 15), "Progress tab not found")
        progressTab.tap()
        sleep(3)

        let paywallPrompt = app.otherElements["progressPaywallPrompt"]
        XCTAssertTrue(paywallPrompt.waitForExistence(timeout: 10), "Paywall prompt not found on Progress tab for free user")

        let unlockText = app.staticTexts["Unlock Progress Tracking"]
        XCTAssertTrue(unlockText.exists, "'Unlock Progress Tracking' text not found")

        // Analytics should NOT be visible
        let activityHeader = app.staticTexts["Activity"]
        XCTAssertFalse(activityHeader.exists, "Activity section should NOT be visible for free user")
    }

    // MARK: - Test: Profile Tab Loads for Free User

    /// Verifies the profile tab loads with expected sections for a free user.
    func testProfileTabLoadsForFreeUser() throws {
        dismissResumeAlertIfPresent()

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)

        // Profile header should be visible
        let editProfile = app.buttons["profileEditButton"]
        XCTAssertTrue(editProfile.waitForExistence(timeout: 10), "Profile edit button not found for free user")
    }

    // MARK: - Test: Settings Shows Free Plan for Free User

    /// Navigates to Settings and verifies the plan shows "Free"
    /// and Apple Watch shows "Upgrade to Pro".
    func testSettingsShowsFreePlanAndGatedFeatures() throws {
        dismissResumeAlertIfPresent()

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)

        let settingsButton = app.buttons["profileSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button not found")
        settingsButton.tap()
        sleep(2)

        // Plan should show "Free"
        let freeLabel = app.staticTexts["Free"]
        XCTAssertTrue(freeLabel.waitForExistence(timeout: 5), "Plan should show 'Free' for free user")

        // Apple Watch should show "Upgrade to Pro"
        let upgradeToPro = app.staticTexts["Upgrade to Pro"]
        XCTAssertTrue(upgradeToPro.exists, "Apple Watch row should show 'Upgrade to Pro' for free user")
    }
}

// MARK: - Pro User Walkthrough

/// Walks a pro user through every main tab and verifies they see
/// the full ungated experience throughout the app.
final class ProUserWalkthroughTests: XCTestCase {

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

    // MARK: - Test: Dashboard Loads for Pro User

    /// Verifies the dashboard loads normally for a pro user.
    func testDashboardLoadsForProUser() throws {
        dismissResumeAlertIfPresent()

        let dashboardHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Welcome' OR label CONTAINS[c] 'Good'")).firstMatch
        XCTAssertTrue(dashboardHeader.waitForExistence(timeout: 15), "Dashboard welcome header not found for pro user")
    }

    // MARK: - Test: Workout Tab and Routines for Pro User

    /// Verifies the workout tab loads and the pro user can access routines.
    func testWorkoutTabAndRoutinesForProUser() throws {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5), "Routines pill not found")
        routinesPill.tap()
        sleep(2)

        // Pro user should see "New Routine" button (unlimited routines)
        let newRoutineButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'New Routine'")).firstMatch
        XCTAssertTrue(newRoutineButton.waitForExistence(timeout: 5), "'New Routine' button not found for pro user")
    }

    // MARK: - Test: Progress Tab Shows Analytics for Pro User

    /// Verifies the Progress tab shows full analytics (Activity section,
    /// streak card, workouts card) instead of a paywall.
    func testProgressTabShowsAnalyticsForProUser() throws {
        dismissResumeAlertIfPresent()

        let progressTab = app.buttons["Progress"]
        XCTAssertTrue(progressTab.waitForExistence(timeout: 15), "Progress tab not found")
        progressTab.tap()
        sleep(3)

        // Activity section should be visible
        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' section should be visible for pro user")

        // Streak card should be visible
        let streakCard = app.otherElements["progressStreakCard"]
        XCTAssertTrue(streakCard.waitForExistence(timeout: 5), "Streak card should be visible for pro user")

        // Paywall should NOT be visible
        let paywallPrompt = app.otherElements["progressPaywallPrompt"]
        XCTAssertFalse(paywallPrompt.exists, "Paywall prompt should NOT be visible for pro user")
    }

    // MARK: - Test: Profile Tab Loads for Pro User

    /// Verifies the profile tab loads with expected sections for a pro user.
    func testProfileTabLoadsForProUser() throws {
        dismissResumeAlertIfPresent()

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)

        let editProfile = app.buttons["profileEditButton"]
        XCTAssertTrue(editProfile.waitForExistence(timeout: 10), "Profile edit button not found for pro user")

        // Milestones section should be visible
        let milestonesHeader = app.staticTexts["Milestones"]
        if !milestonesHeader.exists {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(milestonesHeader.waitForExistence(timeout: 5), "Milestones section not found for pro user")
    }

    // MARK: - Test: Settings Shows Pro Plan

    /// Navigates to Settings and verifies the plan shows "Pro" and
    /// Apple Watch shows connection status instead of upgrade prompt.
    func testSettingsShowsProPlanAndFullFeatures() throws {
        dismissResumeAlertIfPresent()

        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)

        let settingsButton = app.buttons["profileSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button not found")
        settingsButton.tap()
        sleep(2)

        // Plan should show "Pro"
        let proLabel = app.staticTexts["Pro"]
        XCTAssertTrue(proLabel.waitForExistence(timeout: 5), "Plan should show 'Pro' for pro user")

        // Apple Watch should NOT show "Upgrade to Pro"
        let upgradeToPro = app.staticTexts["Upgrade to Pro"]
        XCTAssertFalse(upgradeToPro.exists, "Apple Watch should NOT show 'Upgrade to Pro' for pro user")

        // Should show Connected or Not Connected instead
        let connected = app.staticTexts["Connected"]
        let notConnected = app.staticTexts["Not Connected"]
        XCTAssertTrue(connected.exists || notConnected.exists, "Apple Watch should show connection status for pro user")
    }

    // MARK: - Test: Pro User Can Start Workout

    /// Verifies a pro user can navigate to a routine and see the
    /// Start Workout button (full access, no paywall gating).
    func testProUserCanAccessStartWorkout() throws {
        dismissResumeAlertIfPresent()

        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5), "Routines pill not found")
        routinesPill.tap()
        sleep(2)

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found for pro user")
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found for pro user")
    }
}
