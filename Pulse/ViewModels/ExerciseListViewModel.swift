//
//  ExerciseListViewModel.swift
//  Pulse
//
//  Created by lukasberg on 2/7/26.
//

import Foundation
import Combine

@MainActor
class ExerciseListViewModel : ObservableObject {
    @Published var excercises: [Exercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository = ExcerciseRepository()
    
    func loadExercises() async {
        isLoading = true
        errorMessage = nil
        
        do{
            excercises = try await repository.fetchExercises()
        } catch {
            errorMessage = "Failed to load exercises: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
