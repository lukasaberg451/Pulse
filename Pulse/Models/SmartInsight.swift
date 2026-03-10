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
    let isSystemImage: Bool
    let text: String
    let accentColor: Color
    
    init(type: InsightType, icon: String, isSystemImage: Bool = false, text: String, accentColor: Color) {
        self.type = type
        self.icon = icon
        self.isSystemImage = isSystemImage
        self.text = text
        self.accentColor = accentColor
    }
}
