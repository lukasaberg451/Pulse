//
//  DashboardFormatTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

@MainActor
final class DashboardFormatTests: XCTestCase {

    private var viewModel: DashboardViewModel!

    override func setUp() {
        super.setUp()
        viewModel = DashboardViewModel()
    }

    // MARK: - formatDuration

    func testFormatDurationSeconds() {
        XCTAssertEqual(viewModel.formatDuration(45), "45s")
    }

    func testFormatDurationMinutesAndSeconds() {
        XCTAssertEqual(viewModel.formatDuration(125), "2m 5s")
    }

    func testFormatDurationHoursMinutesSeconds() {
        XCTAssertEqual(viewModel.formatDuration(3661), "1h 1m 1s")
    }

    func testFormatDurationExactHour() {
        XCTAssertEqual(viewModel.formatDuration(3600), "1h 0m 0s")
    }

    func testFormatDurationExactMinute() {
        XCTAssertEqual(viewModel.formatDuration(60), "1m 0s")
    }

    func testFormatDurationZero() {
        XCTAssertEqual(viewModel.formatDuration(0), "0s")
    }

    func testFormatDurationNil() {
        XCTAssertEqual(viewModel.formatDuration(nil), "N/A")
    }

    func testFormatDurationLargeValue() {
        // 2h 30m 15s = 9015 seconds
        XCTAssertEqual(viewModel.formatDuration(9015), "2h 30m 15s")
    }

    // MARK: - Helper lookups

    func testRoutineReturnsNilForUnknownId() {
        XCTAssertNil(viewModel.routine(for: UUID()))
    }

    func testExerciseCountReturnsZeroForUnknownId() {
        XCTAssertEqual(viewModel.exerciseCount(for: UUID()), 0)
    }

    func testSessionNameReturnsDeletedForUnknownSession() {
        let sw = ScheduledWorkout(
            id: UUID(),
            userId: UUID(),
            routineId: nil,
            scheduledDate: "2026-04-15",
            completed: false,
            workoutSessionId: UUID(),
            notes: nil,
            createdAt: Date(),
            routineDeleted: nil
        )
        XCTAssertEqual(viewModel.sessionName(for: sw), "Deleted Routine")
    }
}
