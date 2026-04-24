//
//  PerformanceTests.swift
//  PulseTests
//
//  Created by Lukas Åberg on 2026-03-22.
//

import XCTest
@testable import Pulse

final class UnitPerformanceTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Test: Streak Calculation Performance (1000 Workouts)

    func testStreakCalculationPerformanceWith1000Workouts() throws {
        let userId = UUID()
        let routineId = UUID()
        let calendar = Calendar.current
        let now = Date()

        var sessions: [WorkoutSession] = []
        for i in 0..<1000 {
            let startDate = calendar.date(byAdding: .day, value: -i, to: now)!
            let completedDate = startDate.addingTimeInterval(3600)
            let session = WorkoutSession(
                id: UUID(),
                userId: userId,
                routineId: routineId,
                name: "Workout \(i)",
                startedAt: startDate,
                completedAt: completedDate,
                durationSeconds: 3600,
                notes: nil,
                createdAt: startDate,
                routineDeleted: false
            )
            sessions.append(session)
        }

        measure {
            // Calculate streak using the same algorithm pattern used in production:
            // group by unique calendar days, then count consecutive days from today.
            let sortedDates = sessions
                .compactMap { $0.completedAt }
                .map { calendar.startOfDay(for: $0) }
                .sorted(by: >)

            let uniqueDays = Array(Set(sortedDates)).sorted(by: >)

            var streak = 0
            var expectedDate = calendar.startOfDay(for: now)

            for date in uniqueDays {
                if date == expectedDate {
                    streak += 1
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
                } else if date < expectedDate {
                    break
                }
            }

            XCTAssertGreaterThan(streak, 0, "Streak should be calculated from mock data")
        }
    }

    // MARK: - Test: Workout Data Transformation Performance

    func testWorkoutDataTransformationPerformance() throws {
        let userId = UUID()
        let routineId = UUID()
        let calendar = Calendar.current
        let now = Date()

        var workouts: [(name: String, startDate: Date, durationSeconds: Int, exercises: [String])] = []
        for i in 0..<1000 {
            let startDate = calendar.date(byAdding: .hour, value: -i, to: now)!
            workouts.append((
                name: "Workout \(i)",
                startDate: startDate,
                durationSeconds: Int.random(in: 1800...7200),
                exercises: ["Bench Press", "Squat", "Deadlift"].shuffled()
            ))
        }

        measure {
            var results: [(start: Date, end: Date, metadata: [String: String])] = []
            results.reserveCapacity(workouts.count)

            for workout in workouts {
                let endDate = workout.startDate.addingTimeInterval(TimeInterval(workout.durationSeconds))
                let metadata: [String: String] = [
                    "WorkoutBrandName": "Pulse",
                    "WorkoutName": workout.name,
                    "Exercises": workout.exercises.joined(separator: ","),
                    "UserID": userId.uuidString,
                    "RoutineID": routineId.uuidString
                ]
                results.append((start: workout.startDate, end: endDate, metadata: metadata))
            }

            XCTAssertEqual(results.count, 1000, "All workouts should be processed")
        }
    }

    // MARK: - Test: Calendar Days Computation Performance

    func testCalendarDaysComputationPerformance() throws {
        // Test the calendar grid computation that ScheduleViewModel uses.
        // This exercises the same date math as calendarDays.
        let calendar = Calendar.current

        measure {
            for monthOffset in -12...12 {
                let month = calendar.date(byAdding: .month, value: monthOffset, to: Date())!
                let components = calendar.dateComponents([.year, .month], from: month)
                guard let firstOfMonth = calendar.date(from: components) else { continue }

                let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
                let adjustedFirstWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2

                var days: [Date?] = Array(repeating: nil, count: adjustedFirstWeekday)
                let range = calendar.range(of: .day, in: .month, for: firstOfMonth)!
                for day in range {
                    if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                        days.append(date)
                    }
                }

                XCTAssertGreaterThanOrEqual(days.count, 28)
            }
        }
    }
}
