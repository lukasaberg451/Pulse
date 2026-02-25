//
//  ExerciseListView.swift
//  Pulse
//
//  Created by lukasaberg on 2/7/26.
//

import SwiftUI

struct ExerciseListView: View {
    @StateObject private var viewModel = ExerciseListViewModel()
    var body: some View {
        NavigationStack{
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading exercises...")
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .foregroundStyle(Color.appText)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await viewModel.loadExercises() }
                        }
                    }
                    .padding()
                } else {
                    List(viewModel.exercises) { exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                            HStack{
                                if let muscle = exercise.muscleGroup {
                                    Text(muscle)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                                if let equipment = exercise.equipment {
                                    Text(".")
                                        .foregroundStyle(Color.secondary)
                                    Text(equipment)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Exercises")
            .task {
                await viewModel.loadExercises()
            }
        }
    }
}
