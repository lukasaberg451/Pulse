//
//  SupabaseManager.swift
//  Pulse
//
//  Created by lukasaberg on 2/7/26.
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://cqftejpestclznbcuqnd.supabase.co")!,
            supabaseKey: "sb_publishable_kLwoRmJgzsr4IJF6VybfXQ_y8mwyJyz"
        )
    }
}
