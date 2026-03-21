//
//  PerformanceTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-22.
//

import XCTest

final class UIPerformanceTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test: App Launch Performance

    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    // MARK: - Test: Workout History List Load Time

    func testWorkoutHistoryListLoadTime() throws {
        app.launch()

        // Dismiss any leftover "Resume Workout?" alert
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }

        // Navigate to the Progress tab
        let progressTab = app.buttons["Progress"]
        XCTAssertTrue(progressTab.waitForExistence(timeout: 15), "Progress tab not found")
        progressTab.tap()
        sleep(3)

        // Scroll down to find the "Completed Workouts" section / See All link
        // and navigate to the AllRecentWorkoutsView
        let completedWorkoutsTitle = app.staticTexts["Completed Workouts"]
        if !completedWorkoutsTitle.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
            app.swipeUp()
            sleep(1)
        }

        measure {
            // Navigate to the full workout history list
            let seeAllButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'See All'")).firstMatch
            if seeAllButton.waitForExistence(timeout: 5) {
                seeAllButton.tap()
            }

            // Wait for the first workout card to appear
            let firstCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Completed'")).firstMatch
            _ = firstCard.waitForExistence(timeout: 15)

            // Navigate back for the next iteration
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 5) {
                backButton.tap()
                sleep(1)
            }
        }
    }
}
