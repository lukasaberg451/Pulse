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
    let unlockedAt: Date?
    let name: String
    let description: String
    let icon: String
    let type: String
    let targetValue: Double
    let sortOrder: Int
    let localizationKey: String?

    enum CodingKeys: String, CodingKey {
        case id = "out_id"
        case milestoneDefinitionId = "out_milestone_definition_id"
        case currentValue = "out_current_value"
        case achievedAt = "out_achieved_at"
        case unlockedAt = "out_unlocked_at"
        case name = "out_name"
        case description = "out_description"
        case icon = "out_icon"
        case type = "out_type"
        case targetValue = "out_target_value"
        case sortOrder = "out_sort_order"
        case localizationKey = "out_localization_key"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        milestoneDefinitionId = try container.decode(UUID.self, forKey: .milestoneDefinitionId)
        currentValue = try container.decode(Double.self, forKey: .currentValue)
        achievedAt = try container.decodeIfPresent(Date.self, forKey: .achievedAt)
        unlockedAt = try container.decodeIfPresent(Date.self, forKey: .unlockedAt)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        icon = try container.decode(String.self, forKey: .icon)
        type = try container.decode(String.self, forKey: .type)
        targetValue = try container.decode(Double.self, forKey: .targetValue)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        localizationKey = try container.decodeIfPresent(String.self, forKey: .localizationKey)
    }

    init(id: UUID, milestoneDefinitionId: UUID, currentValue: Double, achievedAt: Date?, unlockedAt: Date?, name: String, description: String, icon: String, type: String, targetValue: Double, sortOrder: Int, localizationKey: String? = nil) {
        self.id = id
        self.milestoneDefinitionId = milestoneDefinitionId
        self.currentValue = currentValue
        self.achievedAt = achievedAt
        self.unlockedAt = unlockedAt
        self.name = name
        self.description = description
        self.icon = icon
        self.type = type
        self.targetValue = targetValue
        self.sortOrder = sortOrder
        self.localizationKey = localizationKey
    }

    var localizedName: String {
        guard let key = localizationKey else { return name }
        let nameKey = "milestone.\(key).name"
        let localized = NSLocalizedString(nameKey, comment: "")
        return localized == nameKey ? name : localized
    }

    var localizedDescription: String {
        guard let key = localizationKey else { return description }
        let descKey = "milestone.\(key).description"
        let localized = NSLocalizedString(descKey, comment: "")
        return localized == descKey ? description : localized
    }
    
    /// Target value has been reached
    var isAchieved: Bool {
        achievedAt != nil
    }
    
    /// User has manually unlocked the achievement
    var isUnlocked: Bool {
        unlockedAt != nil
    }
    
    /// Achieved but not yet unlocked by the user
    var isPendingUnlock: Bool {
        isAchieved && !isUnlocked
    }
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }
}
