//
//  SupabaseManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/7/26.
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        guard let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let supabaseURL = URL(string: supabaseURLString),
              let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String else {
            fatalError("Missing Supabase configuration in Info.plist. Ensure Secrets.xcconfig is set up correctly.")
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
