//
//  MilestoneViewModel.swift
//  Pulse
//

import Foundation
import Combine
import Supabase

@MainActor
class MilestoneViewModel: ObservableObject {
    @Published var allMilestones: [UserMilestone] = []
    @Published var isLoading = false
    @Published var newlyAchieved: [UserMilestone] = []
    @Published var celebratingMilestone: UserMilestone?
    
    private(set) var hasLoaded = false
    private let repository = MilestoneRepository()
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var userProfile: Profile?
    
    // MARK: - Dashboard: show pending unlock first, then next in-progress
    
    var dashboardMilestone: UserMilestone? {
        if let pending = pendingUnlockMilestones.first {
            return pending
        }
        return inProgressMilestones
            .sorted { $0.progress > $1.progress }
            .first
    }
    
    /// Keep for backward compatibility
    var nextMilestone: UserMilestone? {
        dashboardMilestone
    }
    
    // MARK: - Three-state milestone groups
    
    /// Achieved but NOT yet unlocked by the user
    var pendingUnlockMilestones: [UserMilestone] {
        allMilestones
            .filter { $0.isPendingUnlock }
            .sorted { ($0.achievedAt ?? .distantPast) < ($1.achievedAt ?? .distantPast) }
    }
    
    /// Not yet achieved - still working toward the target, sorted by closest to completion
    var inProgressMilestones: [UserMilestone] {
        allMilestones
            .filter { !$0.isAchieved }
            .sorted { $0.progress > $1.progress }
    }
    
    /// Achieved AND unlocked
    var unlockedMilestones: [UserMilestone] {
        allMilestones
            .filter { $0.isUnlocked }
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
    }
    
    /// Legacy computed property - now returns only unlocked milestones
    var achievedMilestones: [UserMilestone] {
        unlockedMilestones
    }
    
    init() {
        NotificationCenter.default.publisher(for: .workoutDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshMilestones()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Profile

    private func fetchUserProfile() async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        do {
            let profile: Profile = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            userProfile = profile
        } catch {
            debugLog("Failed to fetch user profile for milestone timezone: \(error)")
        }
    }

    // MARK: - Load (read existing data)

    func loadMilestones() async {
        loadTask?.cancel()
        await fetchUserProfile()

        let task = Task {
            isLoading = true
            do {
                let milestones = try await repository.fetchUserMilestones()
                if !Task.isCancelled {
                    allMilestones = milestones
                    hasLoaded = true
                }
            } catch is CancellationError {
                // Ignore cancellation
            } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                // Ignore URL session cancellation
            } catch {
                debugLog("Failed to load milestones: \(error)")
            }
            if !Task.isCancelled {
                isLoading = false
            }
        }
        loadTask = task
        await task.value
    }
    
    // MARK: - Refresh (recompute server-side)
    
    func refreshMilestones() async {
        loadTask?.cancel()
        
        let previouslyAchievedIds = Set(
            allMilestones.filter { $0.isAchieved }.map { $0.id }
        )
        
        let task = Task {
            do {
                let updated = try await repository.refreshMilestones()
                if !Task.isCancelled {
                    allMilestones = updated
                    
                    newlyAchieved = updated.filter { milestone in
                        milestone.isAchieved && !previouslyAchievedIds.contains(milestone.id)
                    }
                }
            } catch is CancellationError {
                // Ignore cancellation
            } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                // Ignore URL session cancellation
            } catch {
                debugLog("Failed to refresh milestones: \(error)")
            }
        }
        loadTask = task
        await task.value
    }
    
    func clearNewlyAchieved() {
        newlyAchieved = []
    }
    
    // MARK: - Unlock a milestone
    
    /// Persists unlock to server without updating local state.
    /// Call `commitUnlock(_:)` when ready to update the UI (e.g. after animation).
    func unlockMilestone(_ milestone: UserMilestone) async {
        do {
            try await repository.unlockMilestone(milestoneId: milestone.id)
        } catch {
            debugLog("Failed to unlock milestone: \(error)")
        }
    }
    
    /// Updates local state to reflect a milestone as unlocked.
    /// Call this after the unlock animation finishes and the user is ready to move on.
    func commitUnlock(_ milestone: UserMilestone) {
        if let index = allMilestones.firstIndex(where: { $0.id == milestone.id }) {
            let updated = UserMilestone(
                id: milestone.id,
                milestoneDefinitionId: milestone.milestoneDefinitionId,
                currentValue: milestone.currentValue,
                achievedAt: milestone.achievedAt,
                unlockedAt: Date(),
                name: milestone.name,
                description: milestone.description,
                icon: milestone.icon,
                type: milestone.type,
                targetValue: milestone.targetValue,
                sortOrder: milestone.sortOrder,
                localizationKey: milestone.localizationKey
            )
            allMilestones[index] = updated
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = SharedFormatters.mediumDate
        formatter.timeZone = userProfile?.resolvedTimeZone ?? TimeZone.current
        return formatter.string(from: date)
    }
}
