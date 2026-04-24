//
//  MilestoneTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class MilestoneTests: XCTestCase {

    private func makeMilestone(
        currentValue: Double = 0,
        targetValue: Double = 10,
        achievedAt: Date? = nil,
        unlockedAt: Date? = nil
    ) -> UserMilestone {
        UserMilestone(
            id: UUID(),
            milestoneDefinitionId: UUID(),
            currentValue: currentValue,
            achievedAt: achievedAt,
            unlockedAt: unlockedAt,
            name: "Test Milestone",
            description: "Test Description",
            icon: "star",
            type: "workout_count",
            targetValue: targetValue,
            sortOrder: 0
        )
    }

    // MARK: - isAchieved

    func testIsAchievedWhenAchievedAtSet() {
        let m = makeMilestone(achievedAt: Date())
        XCTAssertTrue(m.isAchieved)
    }

    func testIsNotAchievedWhenAchievedAtNil() {
        let m = makeMilestone(achievedAt: nil)
        XCTAssertFalse(m.isAchieved)
    }

    // MARK: - isUnlocked

    func testIsUnlockedWhenUnlockedAtSet() {
        let m = makeMilestone(unlockedAt: Date())
        XCTAssertTrue(m.isUnlocked)
    }

    func testIsNotUnlockedWhenUnlockedAtNil() {
        let m = makeMilestone(unlockedAt: nil)
        XCTAssertFalse(m.isUnlocked)
    }

    // MARK: - isPendingUnlock

    func testIsPendingUnlockWhenAchievedButNotUnlocked() {
        let m = makeMilestone(achievedAt: Date(), unlockedAt: nil)
        XCTAssertTrue(m.isPendingUnlock)
    }

    func testIsNotPendingUnlockWhenBothSet() {
        let m = makeMilestone(achievedAt: Date(), unlockedAt: Date())
        XCTAssertFalse(m.isPendingUnlock)
    }

    func testIsNotPendingUnlockWhenNeitherSet() {
        let m = makeMilestone(achievedAt: nil, unlockedAt: nil)
        XCTAssertFalse(m.isPendingUnlock)
    }

    // MARK: - progress

    func testProgressZeroWhenNoProgress() {
        let m = makeMilestone(currentValue: 0, targetValue: 10)
        XCTAssertEqual(m.progress, 0)
    }

    func testProgressHalfway() {
        let m = makeMilestone(currentValue: 5, targetValue: 10)
        XCTAssertEqual(m.progress, 0.5)
    }

    func testProgressCappedAtOne() {
        let m = makeMilestone(currentValue: 15, targetValue: 10)
        XCTAssertEqual(m.progress, 1.0)
    }

    func testProgressExactlyOne() {
        let m = makeMilestone(currentValue: 10, targetValue: 10)
        XCTAssertEqual(m.progress, 1.0)
    }

    func testProgressZeroWhenTargetIsZero() {
        let m = makeMilestone(currentValue: 5, targetValue: 0)
        XCTAssertEqual(m.progress, 0)
    }
}
