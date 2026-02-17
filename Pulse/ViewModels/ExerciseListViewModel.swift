//
//  ExerciseListViewModel.swift
//  Pulse
//
//  Created by lukasberg on 2/7/26.
//

import Foundation
import Combine

@MainActor
class ExerciseListViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMoreExercises = true
    
    private let pageSize = 50  // Load 50 at a time
    private var currentPage = 0
    private let repository = ExerciseRepository()
    
    func loadExercises() async {
        isLoading = true
        errorMessage = nil
        currentPage = 0
        exercises = []
        hasMoreExercises = true
        
        do {
            let results = try await repository.fetchExercises(page: 0, pageSize: pageSize)
            exercises = results
            hasMoreExercises = results.count == pageSize
        } catch {
            errorMessage = "Failed to load exercises: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func loadMoreIfNeeded(currentExercise: Exercise) async {
        // Only load more when user reaches last 10 exercises
        guard let lastExercise = exercises.last,
              lastExercise.id == currentExercise.id,
              !isLoadingMore,
              hasMoreExercises else { return }
        
        await loadMore()
    }
    
    func loadMore() async {
        guard !isLoadingMore, hasMoreExercises else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let results = try await repository.fetchExercises(page: currentPage, pageSize: pageSize)
            exercises.append(contentsOf: results)
            hasMoreExercises = results.count == pageSize
        } catch {
            errorMessage = "Failed to load more exercises: \(error.localizedDescription)"
        }
        
        isLoadingMore = false
    }
    
    func resetAndLoad(equipment: String? = nil, muscle: String? = nil, search: String = "") async {
        isLoading = true
        errorMessage = nil
        currentPage = 0
        exercises = []
        hasMoreExercises = true
        
        do {
            let results = try await repository.fetchExercises(
                page: 0,
                pageSize: pageSize,
                equipment: equipment,
                muscleGroup: muscle,
                search: search
            )
            exercises = results
            hasMoreExercises = results.count == pageSize
        } catch {
            errorMessage = "Failed to load exercises: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
