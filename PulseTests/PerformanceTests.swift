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

    override func tearDownWithError() throws {}

    // MARK: - Test: Streak Calculation Performance (1000 Workouts)

    func testStreakCalculationPerformanceWith1000Workouts() throws {
        // Build a mock dataset of 1000 completed workout sessions
        // spread across consecutive days to stress the streak logic.
        let userId = UUID()
        let routineId = UUID()
        let calendar = Calendar.current
        let now = Date()

        var sessions: [WorkoutSession] = []
        for i in 0..<1000 {
            let startDate = calendar.date(byAdding: .day, value: -i, to: now)!
            let completedDate = startDate.addingTimeInterval(3600) // 1 hour workout
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
            // Simulate streak calculation: count consecutive days with a workout
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

    // MARK: - Test: HealthKit Data Fetch Performance

    func testHealthKitDataFetchPerformance() throws {
        // Measure the performance of creating and configuring
        // HealthKit workout builders with a batch of workout data.
        // Note: Actual HK store interactions require device/entitlements,
        // so this measures the data preparation and serialization path.
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
            // Simulate the data transformation that happens before
            // saving to HealthKit: date formatting, metadata assembly,
            // and configuration creation for each workout.
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
}
