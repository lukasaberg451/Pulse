//
//  WorkoutDetailView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-21.
//

import SwiftUI

struct WorkoutDetailView: View {
    @StateObject private var viewModel: WorkoutDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    init(workoutSession: WorkoutSession) {
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModel(workoutSession: workoutSession))
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Stats
                        statsSection
                        
                        // Exercises
                        exercisesSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(viewModel.workoutSession.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .task {
            await viewModel.loadWorkoutDetails()
        }
    }
    
    // MARK: - Stats Section
    var statsSection: some View {
        VStack(spacing: 16) {
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.appAccent)
                Text(viewModel.workoutSession.startedAt, style: .date)
                    .foregroundColor(.appText)
                Spacer()
                Text(viewModel.workoutSession.startedAt, style: .time)
                    .foregroundColor(.appText.opacity(0.6))
            }
            .font(.subheadline)
            
            Divider()
                .background(Color.appText.opacity(0.1))
            
            // Stats Grid
            HStack(spacing: 20) {
                statCard(
                    icon: "clock.fill",
                    title: "Duration",
                    value: viewModel.formattedDuration
                )
                
                statCard(
                    icon: "flame.fill",
                    title: "Total Sets",
                    value: "\(viewModel.totalSets)"
                )
                
                statCard(
                    icon: "scalemass.fill",
                    title: "Volume",
                    value: String(format: "%.0f kg", viewModel.totalVolume)
                )
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
    
    func statCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.appAccent)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.appText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.appText.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Exercises Section
    var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.headline)
                .foregroundColor(.appText)
            
            ForEach(viewModel.groupedSets, id: \.exerciseId) { exercise in
                exerciseCard(
                    name: exercise.exerciseName,
                    sets: exercise.sets
                )
            }
        }
    }
    
    func exerciseCard(name: String, sets: [WorkoutSet]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name
            Text(name)
                .font(.headline)
                .foregroundColor(.appText)
            
            // Sets table
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("SET")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText.opacity(0.6))
                        .frame(width: 50, alignment: .leading)
                    
                    Text("WEIGHT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("REPS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.clear)
                        .frame(width: 30)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground)
                .cornerRadius(8)
                
                // Sets
                ForEach(sets) { set in
                    setRow(set: set)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
    
    func setRow(set: WorkoutSet) -> some View {
        HStack {
            // Set number
            Text("\(set.setNumber)")
                .font(.body)
                .foregroundColor(.appText.opacity(0.8))
                .frame(width: 50, alignment: .leading)
            
            // Weight
            if let weight = set.weight {
                Text(String(format: "%.1f kg", weight))
                    .font(.body)
                    .foregroundColor(.appText)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("-")
                    .font(.body)
                    .foregroundColor(.appText.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Reps or Duration
            if let reps = set.reps {
                Text("\(reps)")
                    .font(.body)
                    .foregroundColor(.appText)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let duration = set.durationSeconds {
                Text("\(duration)s")
                    .font(.body)
                    .foregroundColor(.appText)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("-")
                    .font(.body)
                    .foregroundColor(.appText.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Checkmark
            if set.completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .frame(width: 30)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.appText.opacity(0.3))
                    .frame(width: 30)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
