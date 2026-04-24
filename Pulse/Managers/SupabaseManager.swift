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
        #if DEBUG
        let urlKey = "DEV_SUPABASE_URL"
        let anonKey = "DEV_SUPABASE_KEY"
        #else
        let urlKey = "PROD_SUPABASE_URL"
        let anonKey = "PROD_SUPABASE_KEY"
        #endif

        guard let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: urlKey) as? String,
              let supabaseURL = URL(string: supabaseURLString),
              let supabaseKey = Bundle.main.object(forInfoDictionaryKey: anonKey) as? String else {
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
