//
//  Routine.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/7/26.
//

import Foundation

struct Routine: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case createdAt = "created_at"
    }
    
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: Routine, rhs: Routine) -> Bool {
            lhs.id == rhs.id
        }
}
