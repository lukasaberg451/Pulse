//
//  ScheduleCalendarTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

@MainActor
final class ScheduleCalendarTests: XCTestCase {

    private var viewModel: ScheduleViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ScheduleViewModel()
    }

    // MARK: - calendarDays

    func testCalendarDaysContainsAllDaysOfMonth() {
        // Set to a known month (April 2026 has 30 days)
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "UTC")!
        let april2026 = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        viewModel.currentMonth = april2026

        let days = viewModel.calendarDays
        let nonNilDays = days.compactMap { $0 }

        XCTAssertEqual(nonNilDays.count, 30, "April has 30 days")
    }

    func testCalendarDaysStartsWithLeadingNilsForWeekdayOffset() {
        // April 1, 2026 is a Wednesday → Monday start means 2 leading nils (Mon, Tue)
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "UTC")!
        let april2026 = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        viewModel.currentMonth = april2026

        let days = viewModel.calendarDays

        // The first non-nil entry should be April 1
        let firstNonNilIndex = days.firstIndex(where: { $0 != nil })!
        XCTAssertGreaterThanOrEqual(firstNonNilIndex, 0)

        // Leading entries should be nil
        for i in 0..<firstNonNilIndex {
            XCTAssertNil(days[i], "Day at index \(i) should be nil (padding)")
        }
    }

    func testCalendarDaysForFebruaryLeapYear() {
        // 2028 is a leap year - February has 29 days
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "UTC")!
        let feb2028 = cal.date(from: DateComponents(year: 2028, month: 2, day: 1))!
        viewModel.currentMonth = feb2028

        let days = viewModel.calendarDays
        let nonNilDays = days.compactMap { $0 }

        XCTAssertEqual(nonNilDays.count, 29, "Feb 2028 (leap year) has 29 days")
    }

    func testCalendarDaysForFebruaryNonLeapYear() {
        // 2026 is not a leap year - February has 28 days
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "UTC")!
        let feb2026 = cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        viewModel.currentMonth = feb2026

        let days = viewModel.calendarDays
        let nonNilDays = days.compactMap { $0 }

        XCTAssertEqual(nonNilDays.count, 28, "Feb 2026 has 28 days")
    }

    // MARK: - scheduledWorkouts(for:) sorting

    func testScheduledWorkoutsSortingUncompletedFirst() {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let completed = ScheduledWorkout(
            id: UUID(), userId: UUID(), routineId: UUID(),
            scheduledDate: dateString, completed: true,
            workoutSessionId: nil, notes: nil, createdAt: date,
            routineDeleted: nil
        )
        let uncompleted = ScheduledWorkout(
            id: UUID(), userId: UUID(), routineId: UUID(),
            scheduledDate: dateString, completed: false,
            workoutSessionId: nil, notes: nil, createdAt: date,
            routineDeleted: nil
        )

        viewModel.scheduledWorkouts = [completed, uncompleted]

        let sorted = viewModel.scheduledWorkouts(for: date)
        XCTAssertEqual(sorted.count, 2)
        XCTAssertFalse(sorted[0].completed, "Uncompleted workout should come first")
        XCTAssertTrue(sorted[1].completed, "Completed workout should come second")
    }

    // MARK: - hasScheduledWorkout / isWorkoutCompleted

    func testHasScheduledWorkoutReturnsFalseWhenEmpty() {
        viewModel.scheduledWorkouts = []
        XCTAssertFalse(viewModel.hasScheduledWorkout(on: Date()))
    }

    func testIsWorkoutCompletedReturnsFalseWhenEmpty() {
        viewModel.scheduledWorkouts = []
        XCTAssertFalse(viewModel.isWorkoutCompleted(on: Date()))
    }

    // MARK: - Lookup helpers

    func testRoutineExercisesReturnsEmptyForUnknownId() {
        XCTAssertTrue(viewModel.routineExercises(for: UUID()).isEmpty)
    }

    func testExerciseCountReturnsZeroForUnknownId() {
        XCTAssertEqual(viewModel.exerciseCount(for: UUID()), 0)
    }

    func testRoutineReturnsNilForUnknownId() {
        XCTAssertNil(viewModel.routine(for: UUID()))
    }

    // MARK: - Month navigation

    func testPreviousMonthDecrementsMonth() {
        let cal = Calendar.current
        let original = viewModel.currentMonth
        viewModel.previousMonth()
        let expected = cal.date(byAdding: .month, value: -1, to: original)!
        XCTAssertEqual(
            cal.component(.month, from: viewModel.currentMonth),
            cal.component(.month, from: expected)
        )
    }

    func testNextMonthIncrementsMonth() {
        let cal = Calendar.current
        let original = viewModel.currentMonth
        viewModel.nextMonth()
        let expected = cal.date(byAdding: .month, value: 1, to: original)!
        XCTAssertEqual(
            cal.component(.month, from: viewModel.currentMonth),
            cal.component(.month, from: expected)
        )
    }
}
