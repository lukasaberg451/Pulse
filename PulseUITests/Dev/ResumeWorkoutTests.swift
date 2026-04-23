//
//  ResumeWorkoutTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-04-21.
//

import XCTest

final class ResumeWorkoutTests: UITestBaseCase {

    override var needsRoutineCleanup: Bool { true }

    // MARK: - Test: Resume Workout After App Kill

    /// Starts a workout, terminates the app, relaunches, and verifies
    /// the "Resume Workout?" alert appears. Taps Resume and checks
    /// the active workout view is restored.
    func testResumeWorkoutAfterAppKill() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        // Terminate the app (simulates user killing the app)
        app.terminate()

        // Relaunch the app
        app.launch()

        // The "Resume Workout?" alert should appear
        let resumeAlert = app.alerts["Resume Workout?"]
        XCTAssertTrue(resumeAlert.waitForExistence(timeout: 10), "Resume Workout alert did not appear after relaunch")

        // Tap Resume
        resumeAlert.buttons["Resume"].tap()

        // Verify the active workout view is back
        let finishButton = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10), "Active workout view did not restore after tapping Resume")
    }

    // MARK: - Test: Discard Workout After App Kill

    /// Starts a workout, terminates the app, relaunches, and taps Discard
    /// on the resume alert. Verifies the dashboard appears normally.
    func testDiscardWorkoutAfterAppKill() throws {
        dismissResumeAlertIfPresent()
        createRoutineAndStartWorkout()

        // Terminate and relaunch
        app.terminate()
        app.launch()

        // The "Resume Workout?" alert should appear
        let resumeAlert = app.alerts["Resume Workout?"]
        XCTAssertTrue(resumeAlert.waitForExistence(timeout: 10), "Resume Workout alert did not appear after relaunch")

        // Tap Discard
        resumeAlert.buttons["Discard"].tap()

        // Verify the dashboard loads normally
        let dashboardTab = app.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10), "Dashboard did not appear after discarding resumed workout")
    }
}
