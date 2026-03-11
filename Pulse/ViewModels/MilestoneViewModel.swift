//
//  MilestoneViewModel.swift
//  Pulse
//

import Foundation
import Combine

@MainActor
class MilestoneViewModel: ObservableObject {
    @Published var allMilestones: [UserMilestone] = []
    @Published var isLoading = false
    @Published var newlyAchieved: [UserMilestone] = []
    
    private(set) var hasLoaded = false
    private let repository = MilestoneRepository()
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Dashboard: next upcoming milestone (closest to completion)
    
    var nextMilestone: UserMilestone? {
        inProgressMilestones
            .sorted { $0.progress > $1.progress }
            .first
    }
    
    // MARK: - Progress tab: grouped lists
    
    var achievedMilestones: [UserMilestone] {
        allMilestones
            .filter { $0.isAchieved }
            .sorted { ($0.achievedAt ?? .distantPast) > ($1.achievedAt ?? .distantPast) }
    }
    
    var inProgressMilestones: [UserMilestone] {
        allMilestones
            .filter { !$0.isAchieved }
            .sorted { $0.sortOrder < $1.sortOrder }
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
    
    // MARK: - Load (read existing data)
    
    func loadMilestones() async {
        loadTask?.cancel()
        
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
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
