//
//  Milestone.swift
//  Pulse
//

import Foundation

struct UserMilestone: Codable, Identifiable {
    let id: UUID
    let milestoneDefinitionId: UUID
    let currentValue: Double
    let achievedAt: Date?
    let name: String
    let description: String
    let icon: String
    let type: String
    let targetValue: Double
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "out_id"
        case milestoneDefinitionId = "out_milestone_definition_id"
        case currentValue = "out_current_value"
        case achievedAt = "out_achieved_at"
        case name = "out_name"
        case description = "out_description"
        case icon = "out_icon"
        case type = "out_type"
        case targetValue = "out_target_value"
        case sortOrder = "out_sort_order"
    }
    
    var isAchieved: Bool {
        achievedAt != nil
    }
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }
}
