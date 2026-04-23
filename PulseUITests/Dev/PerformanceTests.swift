//
//  PerformanceTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-22.
//

import XCTest

final class UIPerformanceTests: UITestBaseCase {

    // MARK: - Test: App Launch Performance

    func testAppLaunchPerformance() throws {
        // Terminate the app launched by setUp so measure starts fresh
        app.terminate()

        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    // MARK: - Test: Workout History List Load Time

    func testWorkoutHistoryListLoadTime() throws {
        dismissResumeAlertIfPresent()

        navigateToProfile()

        // Scroll to bottom to reach Completed Workouts section
        scrollToBottom()

        let completedWorkoutsTitle = app.staticTexts["Completed Workouts"]
        XCTAssertTrue(completedWorkoutsTitle.waitForExistence(timeout: 5), "Completed Workouts section not found")

        measure {
            // Scroll to bottom each iteration to find the workout See All button
            scrollToBottom()
            let seeAllButton = app.buttons["profileSeeAllWorkoutsButton"]

            if seeAllButton.waitForExistence(timeout: 5) {
                seeAllButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }

            let firstCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Completed'")).firstMatch
            _ = firstCard.waitForExistence(timeout: 15)

            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 5) {
                backButton.tap()
                waitForAnimation()
            }
        }
    }
}
