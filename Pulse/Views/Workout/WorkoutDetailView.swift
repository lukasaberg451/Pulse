//
//  WorkoutDetailView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-21.
//

import SwiftUI
import UIKit

struct WorkoutDetailView: View {
    @StateObject private var viewModel: WorkoutDetailViewModel
    @EnvironmentObject var unitManager: UnitManager
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    
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
                    VStack(alignment: .leading, spacing: 24) {
                        // Title rendered manually to avoid SwiftUI bug where
                        // the navigation title turns blue on cancelled swipe-back
                        Text(viewModel.workoutSession.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                        
                        // Header Stats
                        statsSection
                        
                        // Exercises
                        exercisesSection
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareWorkout()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.appAccent)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red)
                }
            }
        }
        .alert("Delete Workout", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    let success = await viewModel.deleteWorkout()
                    if success {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this workout? This action cannot be undone.")
        }
        .task {
            await viewModel.loadWorkoutDetails()
        }
        .sheet(isPresented: $showShareSheet) {
            shareImage = nil
        } content: {
            if let shareImage {
                SharePreviewSheet(image: shareImage)
            }
        }
    }
    
    private func shareWorkout() {
        let exerciseCount = Set(viewModel.groupedSets.map { $0.exerciseId }).count
        
        let card = ShareableWorkoutCard(
            routineName: viewModel.workoutSession.name,
            formattedDuration: viewModel.formattedDuration,
            totalVolume: String(format: "%.0f %@", unitManager.displayWeight(viewModel.totalVolume), unitManager.weightUnit),
            exerciseCount: exerciseCount
        )
        
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
    
    // MARK: - Stats Section
    var statsSection: some View {
        VStack(spacing: 16) {
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.appAccent)
                Text(viewModel.formattedDate(viewModel.workoutSession.startedAt))
                    .foregroundStyle(Color.appText)
                Spacer()
                Text(viewModel.formattedTime(viewModel.workoutSession.completedAt ?? viewModel.workoutSession.startedAt))
                    .foregroundStyle(Color.appText.opacity(0.6))
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
                    value: String(format: "%.0f %@", unitManager.displayWeight(viewModel.totalVolume), unitManager.weightUnit)
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
                .foregroundStyle(Color.appAccent)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.appText)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Exercises Section
    var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.headline)
                .foregroundStyle(Color.appText)
            
            ForEach(viewModel.groupedSets, id: \.exerciseId) { exercise in
                exerciseCard(
                    name: exercise.exerciseName,
                    sets: exercise.sets,
                    isCardio: exercise.exerciseType == "cardio"
                )
            }
        }
    }
    
    func exerciseCard(name: String, sets: [WorkoutSet], isCardio: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name
            Text(name)
                .font(.headline)
                .foregroundStyle(Color.appText)
            
            // Sets table
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("SET")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appText.opacity(0.6))
                        .frame(width: 50, alignment: .leading)
                    
                    if isCardio {
                        Text("DURATION")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.appText.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("WEIGHT")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.appText.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("REPS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.appText.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(Color.clear)
                        .frame(width: 30)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground)
                .cornerRadius(12)
                
                // Sets
                ForEach(sets) { set in
                    setRow(set: set, isCardio: isCardio)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
    
    func setRow(set: WorkoutSet, isCardio: Bool) -> some View {
        HStack {
            // Set number
            Text("\(set.setNumber)")
                .font(.body)
                .foregroundStyle(Color.appText.opacity(0.8))
                .frame(width: 50, alignment: .leading)
            
            if isCardio {
                // Duration for cardio
                if let duration = set.durationSeconds {
                    Text(formattedDuration(duration))
                        .font(.body)
                        .foregroundStyle(Color.appText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("-")
                        .font(.body)
                        .foregroundStyle(Color.appText.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                // Weight
                if let weight = set.weight {
                    Text(String(format: "%.1f %@", unitManager.displayWeight(weight), unitManager.weightUnit))
                        .font(.body)
                        .foregroundStyle(Color.appText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("-")
                        .font(.body)
                        .foregroundStyle(Color.appText.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Reps
                if let reps = set.reps {
                    Text("\(reps)")
                        .font(.body)
                        .foregroundStyle(Color.appText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("-")
                        .font(.body)
                        .foregroundStyle(Color.appText.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
            // Checkmark
            if set.completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .frame(width: 30)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(Color.appText.opacity(0.3))
                    .frame(width: 30)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Duration Formatting
    func formattedDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        var parts: [String] = []
        
        if hours > 0 {
            parts.append("\(hours)h")
        }
        if minutes > 0 {
            parts.append("\(minutes)m")
        }
        if seconds > 0 {
            parts.append("\(seconds)s")
        }
        
        return parts.isEmpty ? "0s" : parts.joined(separator: " ")
    }
}
