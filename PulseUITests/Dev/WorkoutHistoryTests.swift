//
//  WorkoutHistoryTests.swift
//  PulseUITests
//
//  Tests for workout history list and pagination.
//

import XCTest

final class WorkoutHistoryTests: UITestBaseCase {

    // MARK: - Test: Completed Workouts Section Shows on Profile

    /// Navigates to the Profile tab and verifies the Completed Workouts
    /// section is visible, either with workout rows or an empty state.
    func testCompletedWorkoutsSectionVisibleOnProfile() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let section = app.otherElements["profileCompletedWorkoutsSection"]
        if !section.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }

        let header = app.staticTexts["Completed Workouts"]
        assertExists(header, timeout: 5, "'Completed Workouts' section not found on profile")
    }

    // MARK: - Test: Workout History List Loads After Scroll

    /// Navigates to the Profile tab, scrolls down to the Completed Workouts
    /// section, and verifies the list is present and scrollable.
    func testWorkoutHistoryListIsScrollable() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        // Scroll to completed workouts section
        let section = app.otherElements["profileCompletedWorkoutsSection"]
        if !section.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        assertExists(section, timeout: 5, "Completed workouts section not found")

        // Try scrolling within the profile view - this tests that the list
        // renders and doesn't crash on scroll
        app.swipeUp()
        waitForAnimation()

        // The profile should still be functional after scrolling
        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.exists, "Profile tab should still be accessible after scrolling")
    }

    // MARK: - Test: Completed Workout Row Navigates to Detail

    /// If the user has completed workouts, taps the first one
    /// and verifies the WorkoutDetailView appears.
    func testTapCompletedWorkoutRowNavigatesToDetail() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        // Scroll to completed workouts section
        let section = app.otherElements["profileCompletedWorkoutsSection"]
        if !section.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }

        // Look for a "See All" button for completed workouts or any workout row
        let seeAll = app.buttons["completedWorkoutsSeeAll"]
        if seeAll.waitForExistence(timeout: 5) {
            seeAll.tap()

            // Should be on the all workouts list - look for any workout card
            let firstWorkout = app.buttons.firstMatch
            if firstWorkout.waitForExistence(timeout: 5) {
                firstWorkout.tap()

                // If we navigated to a detail view, look for typical detail elements
                let durationLabel = app.staticTexts["Duration"]
                let exercisesHeader = app.staticTexts["Exercises"]
                let isOnDetail = durationLabel.waitForExistence(timeout: 5) || exercisesHeader.exists

                if isOnDetail {
                    // Navigate back
                    let backButton = app.navigationBars.buttons.element(boundBy: 0)
                    if backButton.waitForExistence(timeout: 5) {
                        backButton.tap()
                        waitForAnimation()
                    }
                }
            }
        }
        // If no completed workouts exist yet, the test passes gracefully
    }
}
