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
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var animationTrigger = false
    
    init(workoutSession: WorkoutSession) {
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModel(workoutSession: workoutSession))
    }
    
    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title rendered manually to avoid SwiftUI bug where
                        // the navigation title turns blue on cancelled swipe-back
                        Text(viewModel.workoutSession.name)
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.appText)
                            .opacity(animationTrigger ? 1 : 0)
                            .offset(y: animationTrigger ? 0 : 16)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: animationTrigger)
                        
                        // Header Stats
                        statsSection
                            .opacity(animationTrigger ? 1 : 0)
                            .offset(y: animationTrigger ? 0 : 16)
                            .animation(.easeOut(duration: 0.4).delay(0.25), value: animationTrigger)
                        
                        // Exercises
                        exercisesSection
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LinearGradient.dashboardBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareWorkout()
                } label: {
                    Image("share")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.appAccent)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Image("trash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
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
            try? await Task.sleep(for: .milliseconds(50))
            animationTrigger = true
        }
        .sheet(isPresented: $showShareSheet) {
            shareImage = nil
        } content: {
            if let shareImage {
                SharePreviewSheet(image: shareImage)
                    .sheetContentTransition()
            }
        }
    }
    
    private func shareWorkout() {
        let exerciseCount = viewModel.groupedSets.count
        
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
            HStack(spacing: 10) {
                IconBadge(assetName: "calendar", size: 32)
                Text(viewModel.formattedDate(viewModel.workoutSession.startedAt))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appText)
                Spacer()
                Text(viewModel.formattedTime(viewModel.workoutSession.completedAt ?? viewModel.workoutSession.startedAt))
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondaryText)
            }
            
            Divider()
                .foregroundStyle(Color.appText.opacity(0.06))
            
            // Stats Grid
            HStack(spacing: 16) {
                detailStatCard(
                    icon: "clock",
                    title: "Duration",
                    value: viewModel.formattedDuration
                )
                
                detailStatCard(
                    icon: "flame",
                    title: "Total Sets",
                    value: "\(viewModel.totalSets)"
                )
                
                detailStatCard(
                    icon: "volume",
                    title: "Volume",
                    value: String(format: "%.0f %@", unitManager.displayWeight(viewModel.totalVolume), unitManager.weightUnit)
                )
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .shadow(color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear, radius: 16, x: 0, y: 6)
    }
    
    private func detailStatCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            IconBadge(assetName: icon, size: 36)
            
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Exercises Section
    var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.appText)
                .opacity(animationTrigger ? 1 : 0)
                .offset(y: animationTrigger ? 0 : 16)
                .animation(.easeOut(duration: 0.35).delay(0.4), value: animationTrigger)
            
            ForEach(Array(viewModel.groupedSets.enumerated()), id: \.element.orderIndex) { index, exercise in
                exerciseCard(
                    name: exercise.exerciseName,
                    sets: exercise.sets,
                    isCardio: exercise.exerciseType == "cardio"
                )
                .opacity(animationTrigger ? 1 : 0)
                .offset(y: animationTrigger ? 0 : 20)
                .animation(.easeOut(duration: 0.35).delay(0.5 + Double(index) * 0.1), value: animationTrigger)
            }
        }
    }
    
    func exerciseCard(name: String, sets: [WorkoutSet], isCardio: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name
            HStack(spacing: 10) {
                IconBadge(
                    assetName: isCardio ? "cardio" : "musclegroup",
                    size: 32
                )
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)
            }
            
            // Sets table
            VStack(spacing: 4) {
                // Header
                HStack {
                    Text("SET")
                        .frame(width: 50, alignment: .leading)
                    
                    if isCardio {
                        Text("DURATION")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("WEIGHT")
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("REPS")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Image("check")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.clear)
                        .frame(width: 30)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appTertiaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Sets
                ForEach(sets) { set in
                    setRow(set: set, isCardio: isCardio)
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .shadow(color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear, radius: 16, x: 0, y: 6)
    }
    
    func setRow(set: WorkoutSet, isCardio: Bool) -> some View {
        HStack {
            // Set number
            Text("\(set.setNumber)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(set.completed ? Color.appText : Color.appTertiaryText)
                .frame(width: 28, height: 28)
                .background(
                    set.completed ? Color.green.opacity(0.12) : Color.appBackground.opacity(0.5),
                    in: Circle()
                )
                .frame(width: 50, alignment: .leading)
            
            if isCardio {
                if let duration = set.durationSeconds {
                    Text(formattedDuration(duration))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("-")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                if let weight = set.weight {
                    Text(String(format: "%.1f %@", unitManager.displayWeight(weight), unitManager.weightUnit))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("-")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                if let reps = set.reps {
                    Text("\(reps)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("-")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
            if set.completed {
                Image("check-circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(Color.green)
                    .frame(width: 30)
            } else {
                Image("circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTertiaryText)
                    .frame(width: 30)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
