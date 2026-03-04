//
//  SmartInsight.swift
//  Pulse
//

import SwiftUI

enum InsightType: CaseIterable {
    case consistencyPattern
    case streakProtection
    case progressiveOverload
    case recoveryIntelligence
    case momentumHighlight
    case habitTimeDetection
    case weakPointDetection
    case microGoalMotivation
    case performanceTrend
    case returnMotivation
}

struct SmartInsight: Identifiable, Equatable {
    let id = UUID()
    let type: InsightType
    let icon: String
    let text: String
    let accentColor: Color
}
