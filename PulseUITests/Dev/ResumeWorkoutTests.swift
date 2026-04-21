//
//  ResumeWorkoutTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class ResumeWorkoutTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        // Clean up: discard any in-progress workout so it doesn't leak
        // into other tests. Re-launch to trigger the resume alert if needed.
        if app != nil {
            app.terminate()
            app.launch()
            let resumeAlert = app.alerts["Resume Workout?"]
            if resumeAlert.waitForExistence(timeout: 5) {
                resumeAlert.buttons["Discard"].tap()
                sleep(1)
            }
            app = nil
        }
    }

    // MARK: - Helpers

    private func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }
    }

    private func startWorkout() {
        // Navigate to Workout tab → Routines → first routine → Start Workout
        let workoutTab = app.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 15), "Workout tab not found")
        workoutTab.tap()
        sleep(2)

        let routinesPill = app.buttons["Routines"]
        XCTAssertTrue(routinesPill.waitForExistence(timeout: 5), "Routines pill not found")
        routinesPill.tap()
        sleep(2)

        let firstRoutine = app.buttons.matching(identifier: "routineRow").firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10), "No routine found")
        firstRoutine.tap()

        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start Workout button not found")
        startButton.tap()

        // Verify active workout appeared
        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout screen did not appear")
    }

    // MARK: - Test: Resume Workout After App Kill

    /// Starts a workout, terminates the app, relaunches, and verifies
    /// the "Resume Workout?" alert appears. Taps Resume and checks
    /// the active workout view is restored.
    func testResumeWorkoutAfterAppKill() throws {
        dismissResumeAlertIfPresent()
        startWorkout()

        // Terminate the app (simulates user killing the app)
        app.terminate()
        sleep(1)

        // Relaunch the app
        app.launch()

        // The "Resume Workout?" alert should appear
        let resumeAlert = app.alerts["Resume Workout?"]
        XCTAssertTrue(resumeAlert.waitForExistence(timeout: 10), "Resume Workout alert did not appear after relaunch")

        // Tap Resume
        resumeAlert.buttons["Resume"].tap()
        sleep(2)

        // Verify the active workout view is back
        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout view did not restore after tapping Resume")
    }

    // MARK: - Test: Discard Workout After App Kill

    /// Starts a workout, terminates the app, relaunches, and taps Discard
    /// on the resume alert. Verifies the dashboard appears normally.
    func testDiscardWorkoutAfterAppKill() throws {
        dismissResumeAlertIfPresent()
        startWorkout()

        // Terminate and relaunch
        app.terminate()
        sleep(1)
        app.launch()

        // The "Resume Workout?" alert should appear
        let resumeAlert = app.alerts["Resume Workout?"]
        XCTAssertTrue(resumeAlert.waitForExistence(timeout: 10), "Resume Workout alert did not appear after relaunch")

        // Tap Discard
        resumeAlert.buttons["Discard"].tap()
        sleep(2)

        // Verify the dashboard loads normally
        let dashboardTab = app.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10), "Dashboard did not appear after discarding resumed workout")
    }
}
