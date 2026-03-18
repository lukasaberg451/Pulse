//
//  WorkoutParserService.swift
//  Pulse
//

import Foundation

// MARK: - Parser Error

enum ParserError: LocalizedError {
    case offTopic(String)
    case rateLimitExceeded(String)
    case upgradeRequired
    case unauthorized
    case networkError(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .offTopic(let message):
            return message
        case .rateLimitExceeded(let message):
            return message
        case .upgradeRequired:
            return "AI features are available on Pro and Coach plans."
        case .unauthorized:
            return "Please sign in to use this feature."
        case .networkError(let error):
            return error.localizedDescription
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Workout Parser Service

final class WorkoutParserService {
    static let shared = WorkoutParserService()
    
    private let baseURL: String
    private let anonKey: String
    
    private init() {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            fatalError("Missing SUPABASE_URL in Info.plist")
        }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String else {
            fatalError("Missing SUPABASE_KEY in Info.plist")
        }
        baseURL = url
        anonKey = key
    }
    
    func parse(text: String, accessToken: String) async throws -> ParsedWorkout {
        let endpoint = "\(baseURL)/functions/v1/parse-workout"
        debugLog("🤖 Calling: \(endpoint)")
        debugLog("🤖 Token empty: \(accessToken.isEmpty)")
        guard let url = URL(string: endpoint) else { throw ParserError.unknown }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 15
        
        let body = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            debugLog("🤖 Network error: \(error)")
            throw ParserError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParserError.unknown
        }
        
        debugLog("🤖 Parse workout response: \(httpResponse.statusCode)")
        if let bodyString = String(data: data, encoding: .utf8) {
            debugLog("🤖 Response body: \(bodyString)")
        }
        
        let decoder = JSONDecoder()
        
        switch httpResponse.statusCode {
        case 200:
            let parsed = try decoder.decode(ParseResponse.self, from: data)
            guard let workout = parsed.data else { throw ParserError.unknown }
            return workout
            
        case 401:
            throw ParserError.unauthorized
            
        case 403:
            throw ParserError.upgradeRequired
            
        case 422:
            let parsed = try? decoder.decode(ParseResponse.self, from: data)
            let message = parsed?.message ?? "Just describe your workout and I'll log it — e.g. Chest day, bench 4x8 at 80kg"
            throw ParserError.offTopic(message)
            
        case 429:
            let parsed = try? decoder.decode(ParseResponse.self, from: data)
            let message = parsed?.message ?? "You've reached your daily AI limit. Try again tomorrow."
            throw ParserError.rateLimitExceeded(message)
            
        default:
            throw ParserError.unknown
        }
    }
}
