//
//  WorkoutSummaryView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-08.
//

import SwiftUI
import UIKit
import PostHog

struct WorkoutSummaryView: View {
    let routineName: String
    let elapsedTime: TimeInterval
    let sets: [LocalWorkoutSet]
    let exercises: [Exercise]
    let onDismiss: () -> Void
    
    @EnvironmentObject var unitManager: UnitManager
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    
    // MARK: - Computed Stats
    
    private var completedSets: [LocalWorkoutSet] {
        sets.filter { $0.completed }
    }
    
    private var totalSets: Int {
        completedSets.count
    }
    
    private var totalVolume: Double {
        completedSets.reduce(0) { total, set in
            let weight = set.weight ?? 0
            let reps = Double(set.reps ?? 0)
            return total + (weight * reps)
        }
    }
    
    private var exerciseCount: Int {
        Set(completedSets.map { $0.exerciseId }).count
    }
    
    private var groupedSets: [(exercise: Exercise, sets: [LocalWorkoutSet])] {
        var seen: [UUID] = []
        for set in sets {
            if !seen.contains(set.exerciseId) {
                seen.append(set.exerciseId)
            }
        }
        return seen.compactMap { exerciseId in
            guard let exercise = exercises.first(where: { $0.id == exerciseId }) else { return nil }
            let exerciseSets = sets.filter { $0.exerciseId == exerciseId }.sorted { $0.setNumber < $1.setNumber }
            return (exercise: exercise, sets: exerciseSets)
        }
    }
    
    private var formattedDuration: String {
        let totalSeconds = Int(elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds)s") }
        return parts.joined(separator: " ")
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.green)
                            
                            Text("Workout Complete")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                            
                            Text(routineName)
                                .font(.subheadline)
                                .foregroundStyle(Color.appText.opacity(0.6))
                        }
                        .padding(.top, 32)
                        
                        // Stats Grid
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                statCard(
                                    icon: "clock.fill",
                                    title: "Duration",
                                    value: formattedDuration
                                )
                                
                                statCard(
                                    icon: "flame.fill",
                                    title: "Total Sets",
                                    value: "\(totalSets)"
                                )
                            }
                            
                            HStack(spacing: 16) {
                                statCard(
                                    icon: "scalemass.fill",
                                    title: "Volume",
                                    value: String(format: "%.0f %@", unitManager.displayWeight(totalVolume), unitManager.weightUnit)
                                )
                                
                                statCard(
                                    icon: "figure.strengthtraining.traditional",
                                    title: "Exercises",
                                    value: "\(exerciseCount)"
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Exercise Breakdown
                        exercisesSection
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        shareWorkout()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 54, height: 54)
                            .background(Color.appSurface)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        onDismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                .padding(.top, 8)
            }
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showShareSheet) {
            shareImage = nil
        } content: {
            if let shareImage {
                SharePreviewSheet(image: shareImage)
            }
        }
    }
    
    // MARK: - Share
    
    private func shareWorkout() {
        let card = ShareableWorkoutCard(
            routineName: routineName,
            formattedDuration: formattedDuration,
            totalVolume: String(format: "%.0f %@", unitManager.displayWeight(totalVolume), unitManager.weightUnit),
            exerciseCount: exerciseCount
        )
        
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
    
    // MARK: - Exercises Section
    
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.headline)
                .foregroundStyle(Color.appText)
            
            ForEach(groupedSets, id: \.exercise.id) { group in
                exerciseCard(
                    name: group.exercise.name,
                    sets: group.sets,
                    isCardio: group.exercise.exerciseType == "cardio"
                )
            }
        }
    }
    
    private func exerciseCard(name: String, sets: [LocalWorkoutSet], isCardio: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(name)
                .font(.headline)
                .foregroundStyle(Color.appText)
            
            VStack(spacing: 8) {
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
                    
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.clear)
                        .frame(width: 30)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appText.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground)
                .cornerRadius(12)
                
                ForEach(sets, id: \.id) { set in
                    setRow(set: set, isCardio: isCardio)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
    
    private func setRow(set: LocalWorkoutSet, isCardio: Bool) -> some View {
        HStack {
            Text("\(set.setNumber)")
                .font(.body)
                .foregroundStyle(Color.appText.opacity(0.8))
                .frame(width: 50, alignment: .leading)
            
            if isCardio {
                if let duration = set.durationSeconds {
                    Text(formattedSetDuration(duration))
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
    
    private func formattedSetDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds)s") }
        return parts.joined(separator: " ")
    }
    
    // MARK: - Stat Card
    
    private func statCard(icon: String, title: String, value: String) -> some View {
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
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

// MARK: - Shareable Workout Card

struct ShareableWorkoutCard: View {
    let routineName: String
    let formattedDuration: String
    let totalVolume: String
    let exerciseCount: Int
    
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.green)
                    
                    Text("Workout Completed")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text(routineName)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                // Stats
                VStack(spacing: 24) {
                    shareStatItem(icon: "clock.fill", value: formattedDuration, label: "Duration")
                    
                    Divider()
                        .background(.white.opacity(0.15))
                    
                    shareStatItem(icon: "scalemass.fill", value: totalVolume, label: "Volume")
                    
                    Divider()
                        .background(.white.opacity(0.15))
                    
                    shareStatItem(icon: "figure.strengthtraining.traditional", value: "\(exerciseCount)", label: "Exercises")
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Branding
            HStack(spacing: 6) {
                Text("Pulse")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accentColor)
                Text("Workout Tracker")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.bottom, 48)
        }
        // 1080x1920 at 3x scale = 360x640pt
        .frame(width: 360, height: 640)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
    }
    
    private func shareStatItem(icon: String, value: String, label: String) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Share Preview Sheet

struct SharePreviewSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Share Preview")
                    .font(.headline)
                    .foregroundStyle(Color.appText)
                    .padding(.top, 20)
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        presentShareSheet()
                        PostHogSDK.shared.capture("workout_shared")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func presentShareSheet() {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        activityVC.excludedActivityTypes = [.saveToCameraRoll]
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.keyWindow?.rootViewController else { return }
        
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(activityVC, animated: true)
    }
}
