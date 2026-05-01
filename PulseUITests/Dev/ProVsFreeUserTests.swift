//
//  ProVsFreeUserTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//
//  Simplified walkthrough tests that verify each tab loads for free/pro users.
//  Detailed subscription assertions (plan labels, paywall content, Apple Watch
//  gating) live in SubscriptionTests.swift to avoid duplicate coverage.
//

import XCTest

// MARK: - Free User Walkthrough

/// Walks a free user through every main tab and verifies they load without crashing.
final class FreeUserWalkthroughTests: FreeUserUITestBaseCase {

    // MARK: - Test: Dashboard Loads for Free User

    func testDashboardLoadsForFreeUser() throws {
        dismissResumeAlertIfPresent()

        let dashboardHeader = app.staticTexts.matching(identifier: "dashboardWelcomeText").firstMatch
        XCTAssertTrue(dashboardHeader.waitForExistence(timeout: 15), "Dashboard welcome header not found for free user")
    }

    // MARK: - Test: Workout Tab Loads for Free User

    func testWorkoutTabLoadsForFreeUser() throws {
        dismissResumeAlertIfPresent()
        navigateToRoutinesTab()

        let routineRow = app.buttons.matching(identifier: "routineRow").firstMatch
        let emptyState = app.staticTexts["Create your first workout routine"]
        XCTAssertTrue(routineRow.waitForExistence(timeout: 5) || emptyState.exists,
                      "Neither routine list nor empty state visible for free user")
    }

    // MARK: - Test: Schedule Tab Loads for Free User

    func testScheduleTabLoadsForFreeUser() throws {
        dismissResumeAlertIfPresent()
        navigateToScheduleTab()
        // Just verify the tab loaded without crashing
    }

    // MARK: - Test: Progress Tab for Free User

    func testProgressTabForFreeUser() throws {
        dismissResumeAlertIfPresent()

        let progressTab = app.buttons["Progress"]
        assertExists(progressTab, timeout: 15, "Progress tab not found")
        progressTab.tap()

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' section should be visible for free user")

        let paywallPrompt = app.otherElements["progressPaywallPrompt"]
        XCTAssertTrue(paywallPrompt.waitForExistence(timeout: 10), "Paywall prompt not found on Progress tab for free user")
    }

    // MARK: - Test: Profile Tab Loads for Free User

    func testProfileTabLoadsForFreeUser() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()
        // Profile edit button is asserted by navigateToProfile()
    }
}

// MARK: - Pro User Walkthrough

/// Walks a pro user through every main tab and verifies they see full ungated experience.
final class ProUserWalkthroughTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }

    // MARK: - Test: Dashboard Loads for Pro User

    func testDashboardLoadsForProUser() throws {
        dismissResumeAlertIfPresent()

        let dashboardHeader = app.staticTexts.matching(identifier: "dashboardWelcomeText").firstMatch
        XCTAssertTrue(dashboardHeader.waitForExistence(timeout: 15), "Dashboard welcome header not found for pro user")
    }

    // MARK: - Test: Workout Tab and Routines for Pro User

    func testWorkoutTabAndRoutinesForProUser() throws {
        dismissResumeAlertIfPresent()
        navigateToRoutinesTab()

        let newRoutineButton = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'New Routine'"
        )).firstMatch
        XCTAssertTrue(newRoutineButton.waitForExistence(timeout: 5), "'New Routine' button not found for pro user")
    }

    // MARK: - Test: Progress Tab Shows Analytics for Pro User

    func testProgressTabShowsAnalyticsForProUser() throws {
        dismissResumeAlertIfPresent()

        let progressTab = app.buttons["Progress"]
        assertExists(progressTab, timeout: 15, "Progress tab not found")
        progressTab.tap()

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' section should be visible for pro user")

        let paywallPrompt = app.otherElements["progressPaywallPrompt"]
        XCTAssertFalse(paywallPrompt.exists, "Paywall prompt should NOT be visible for pro user")
    }

    // MARK: - Test: Profile Tab Loads for Pro User

    func testProfileTabLoadsForProUser() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let milestonesHeader = app.staticTexts["Milestones"]
        if !milestonesHeader.exists {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(milestonesHeader.waitForExistence(timeout: 5), "Milestones section not found for pro user")
    }

    // MARK: - Test: Pro User Can Start Workout

    func testProUserCanAccessStartWorkout() throws {
        dismissResumeAlertIfPresent()

        let routineName = "UITest Pro \(uniqueSuffix)"
        navigateToRoutinesTab()
        createRoutine(name: routineName)
        assertExists(app.staticTexts[routineName], timeout: 10)

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found for pro user")
    }
}
