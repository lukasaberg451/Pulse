//
//  ProfileViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-15.
//

import Foundation
import Combine
import Supabase

extension Notification.Name {
    static let customExerciseCreated = Notification.Name("customExerciseCreated")
    static let profileUpdated = Notification.Name("profileUpdated")
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var isSubmittingFeedback = false
    @Published var feedbackError: String?
    @Published var startWeightKg: Double?
    @Published var weightHistory: [WeightHistory] = []
    @Published var customExercises: [Exercise] = []
    
    private let supabase = SupabaseManager.shared.client
    private let weightHistoryRepo = WeightHistoryRepository()
    private let exerciseRepo = ExerciseRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: .customExerciseCreated)
            .compactMap { $0.object as? Exercise }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] exercise in
                self?.customExercises.append(exercise)
                self?.customExercises.sort { $0.name < $1.name }
            }
            .store(in: &cancellables)
    }
    
    var initials: String {
        guard let profile = profile else { return "?" }
        let first = profile.firstName?.prefix(1) ?? ""
        let last = profile.lastName?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
    
    func loadProfile() async {
        // Only show full loading spinner on initial load
        if profile == nil {
            isLoading = true
        }
        
        do {
            guard let userId = supabase.auth.currentUser?.id else {
                isLoading = false
                return
            }
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            self.profile = profile
            
            // Load start weight from history
            if let startEntry = try? await weightHistoryRepo.fetchStartWeight() {
                self.startWeightKg = startEntry.weightKg
            } else {
                self.startWeightKg = nil
            }
            
            // Sync unit system preference
            if let unitRaw = profile.unitSystem,
               let unit = UnitSystem(rawValue: unitRaw) {
                UnitManager.shared.unitSystem = unit
            }
            
            // Auto-detect timezone on first load if not set
            if profile.timezone == nil {
                await updateTimezone(TimeZone.current.identifier)
            }
            
            // Load custom exercises
            if let exercises = try? await exerciseRepo.fetchCustomExercises() {
                self.customExercises = exercises
            }
        } catch {
            debugLog("Failed to load profile: \(error)")
        }
        
        isLoading = false
    }
    
    func updateTimezone(_ timezoneIdentifier: String) async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            struct UpdateTimezone: Encodable {
                let timezone: String
            }
            
            try await supabase
                .from("profiles")
                .update(UpdateTimezone(timezone: timezoneIdentifier))
                .eq("id", value: userId.uuidString)
                .execute()
            
            // Reload profile to pick up the new timezone
            let updatedProfile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            self.profile = updatedProfile
        } catch {
            debugLog("Failed to update timezone: \(error)")
        }
    }
    
    func updateUnitSystem(_ system: UnitSystem) async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            struct UpdateUnitSystem: Encodable {
                let unit_system: String
            }
            
            try await supabase
                .from("profiles")
                .update(UpdateUnitSystem(unit_system: system.rawValue))
                .eq("id", value: userId.uuidString)
                .execute()
            
            UnitManager.shared.unitSystem = system
            
            await loadProfile()
        } catch {
            debugLog("Failed to update unit system: \(error)")
        }
    }
    
    func updateProfile(firstName: String, lastName: String) async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            
            struct UpdateProfile: Encodable {
                let first_name: String
                let last_name: String
            }
            
            try await supabase
                .from("profiles")
                .update(UpdateProfile(first_name: firstName, last_name: lastName))
                .eq("id", value: userId.uuidString)
                .execute()
            
            // Reload profile
            await loadProfile()
            
            NotificationCenter.default.post(name: .profileUpdated, object: nil)
        } catch {
            debugLog("Failed to update profile: \(error)")
        }
    }
    
    func submitFeedback(type: String, title: String, description: String, isChecked: Bool) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        
        do {
            guard let userId = supabase.auth.currentUser?.id else {
                errorMessage = String(localized: "User not authenticated")
                isSubmitting = false
                return false
            }
            
            struct Feedback: Encodable {
                let user_id: String
                let type: String
                let title: String
                let description: String
                let isChecked: Bool
            }
            
            let feedback = Feedback(
                user_id: userId.uuidString,
                type: type,
                title: title,
                description: description,
                isChecked: isChecked
            )
            
            try await supabase
                .from("feedback")
                .insert(feedback)
                .execute()
            
            isSubmitting = false
            return true
        } catch {
            errorMessage = String(localized: "Failed to submit feedback: \(error.localizedDescription)")
            isSubmitting = false
            return false
        }
    }
    
    func deleteCustomExercise(_ exercise: Exercise) async {
        do {
            try await exerciseRepo.deleteCustomExercise(id: exercise.id)
            customExercises.removeAll { $0.id == exercise.id }
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
        } catch {
            debugLog("Failed to delete custom exercise: \(error)")
        }
    }
    
    func loadWeightHistory() async {
        do {
            weightHistory = try await weightHistoryRepo.fetchAllWeightHistory()
        } catch {
            debugLog("Failed to load weight history: \(error)")
        }
    }
    
    func clearBodyMetrics() async -> Bool {
        isSubmitting = true
        errorMessage = nil
        
        do {
            guard let userId = supabase.auth.currentUser?.id else {
                errorMessage = String(localized: "User not authenticated")
                isSubmitting = false
                return false
            }
            
            // Use custom encoding to ensure nil is sent as JSON null
            struct ClearHealthMetrics: Encodable {
                enum CodingKeys: String, CodingKey {
                    case weightKg = "weight_kg"
                    case heightCm = "height_cm"
                    case targetWeightKg = "target_weight_kg"
                }
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encodeNil(forKey: .weightKg)
                    try container.encodeNil(forKey: .heightCm)
                    try container.encodeNil(forKey: .targetWeightKg)
                }
            }
            
            // Clear profile metrics
            try await supabase
                .from("profiles")
                .update(ClearHealthMetrics())
                .eq("id", value: userId.uuidString)
                .execute()
            
            // Delete all weight history
            try await weightHistoryRepo.deleteAllWeightHistory()
            
            // Reset local state
            startWeightKg = nil
            weightHistory = []
            
            // Reload profile
            await loadProfile()
            isSubmitting = false
            return true
        } catch {
            errorMessage = String(localized: "Failed to clear body metrics: \(error.localizedDescription)")
            isSubmitting = false
            return false
        }
    }
    
    func updateHealthMetrics(
        weightKg: Double?, heightCm: Double?, targetWeightKg: Double?,
        weightChanged: Bool, heightChanged: Bool, targetWeightChanged: Bool
    ) async -> Bool {
        // If nothing changed, just return success
        guard weightChanged || heightChanged || targetWeightChanged else {
            return true
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            guard let userId = supabase.auth.currentUser?.id else {
                errorMessage = String(localized: "User not authenticated")
                isSubmitting = false
                return false
            }
            
            // Only encode fields that actually changed
            struct SelectiveHealthMetrics: Encodable {
                let weightKg: Double?
                let heightCm: Double?
                let targetWeightKg: Double?
                let includeWeight: Bool
                let includeHeight: Bool
                let includeTargetWeight: Bool
                
                enum CodingKeys: String, CodingKey {
                    case weightKg = "weight_kg"
                    case heightCm = "height_cm"
                    case targetWeightKg = "target_weight_kg"
                }
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    if includeWeight {
                        try container.encode(weightKg, forKey: .weightKg)
                    }
                    if includeHeight {
                        try container.encode(heightCm, forKey: .heightCm)
                    }
                    if includeTargetWeight {
                        try container.encode(targetWeightKg, forKey: .targetWeightKg)
                    }
                }
            }
            
            try await supabase
                .from("profiles")
                .update(SelectiveHealthMetrics(
                    weightKg: weightKg,
                    heightCm: heightCm,
                    targetWeightKg: targetWeightKg,
                    includeWeight: weightChanged,
                    includeHeight: heightChanged,
                    includeTargetWeight: targetWeightChanged
                ))
                .eq("id", value: userId.uuidString)
                .execute()
            
            // Log weight to history only if weight actually changed
            if weightChanged, let weightKg {
                try? await weightHistoryRepo.logWeight(weightKg)
            }
            
            // Reload profile
            await loadProfile()
            isSubmitting = false
            return true
        } catch {
            errorMessage = String(localized: "Failed to update health metrics: \(error.localizedDescription)")
            isSubmitting = false
            return false
        }
    }
}
