//
//  WorkoutSummaryView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-08.
//

import SwiftUI
import UIKit
import PostHog

private struct ExerciseKey: Hashable {
    let exerciseId: UUID
    let orderIndex: Int?
}

struct WorkoutSummaryView: View {
    let routineName: String
    let elapsedTime: TimeInterval
    let sets: [LocalWorkoutSet]
    let exercises: [Exercise]
    let routineExercises: [RoutineExercise]
    let strength1RMHighlights: [Strength1RMHighlight]
    let onDismiss: () -> Void
    
    @EnvironmentObject var unitManager: UnitManager
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var show1RMShareSheet = false
    @State private var share1RMImage: UIImage?
    
    // MARK: - Animation State
    @State private var animationTrigger = false
    @State private var celebrationTrigger = 0
    
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
        Set(completedSets.map { ExerciseKey(exerciseId: $0.exerciseId, orderIndex: $0.orderIndex) }).count
    }
    
    private var groupedSets: [(exercise: Exercise, orderIndex: Int, sets: [LocalWorkoutSet])] {
        var seen: [(id: UUID, orderIndex: Int)] = []
        for set in sets {
            if !seen.contains(where: { $0.id == set.exerciseId && $0.orderIndex == (set.orderIndex ?? Int.max) }) {
                seen.append((id: set.exerciseId, orderIndex: set.orderIndex ?? Int.max))
            }
        }
        let sorted = seen.sorted { $0.orderIndex < $1.orderIndex }
        return sorted.compactMap { item in
            guard let exercise = exercises.first(where: { $0.id == item.id }) else { return nil }
            let exerciseSets = sets.filter { $0.exerciseId == item.id && $0.orderIndex == item.orderIndex }.sorted { $0.setNumber < $1.setNumber }
            return (exercise: exercise, orderIndex: item.orderIndex, sets: exerciseSets)
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
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        IconBadge(assetName: "check-circle", color: .green, size: 56)
                            .scaleEffect(animationTrigger ? 1.0 : 0.5)
                            .opacity(animationTrigger ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animationTrigger)
                            .keyframeAnimator(
                                initialValue: CelebrationValues(),
                                trigger: celebrationTrigger
                            ) { content, value in
                                content
                                    .scaleEffect(value.scale)
                                    .overlay {
                                        Circle()
                                            .fill(Color.green.opacity(value.glowOpacity))
                                            .blur(radius: 24)
                                            .scaleEffect(value.scale * 1.6)
                                            .allowsHitTesting(false)
                                    }
                            } keyframes: { _ in
                                KeyframeTrack(\.scale) {
                                    CubicKeyframe(1.18, duration: 0.45)
                                    CubicKeyframe(1.0, duration: 0.6)
                                }

                                KeyframeTrack(\.glowOpacity) {
                                    CubicKeyframe(0.3, duration: 0.4)
                                    CubicKeyframe(0.0, duration: 0.7)
                                }
                            }

                        Text("Workout Completed", comment: "Summary header")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                            .multilineTextAlignment(.center)
                            .opacity(animationTrigger ? 1 : 0)
                            .offset(y: animationTrigger ? 0 : 8)
                            .animation(.easeOut(duration: 0.35).delay(0.3), value: animationTrigger)

                        Text(routineName)
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .opacity(animationTrigger ? 1 : 0)
                            .offset(y: animationTrigger ? 0 : 8)
                            .animation(.easeOut(duration: 0.35).delay(0.3), value: animationTrigger)
                    }
                    .padding(.top, 32)

                    // Stats Grid
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            summaryStatCard(
                                icon: "clock",
                                title: "Duration",
                                value: formattedDuration
                            )

                            summaryStatCard(
                                icon: "flame",
                                title: "Total Sets",
                                value: "\(totalSets)"
                            )
                        }
                        .opacity(animationTrigger ? 1 : 0)
                        .offset(y: animationTrigger ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(0.4), value: animationTrigger)

                        HStack(spacing: 12) {
                            summaryStatCard(
                                icon: "volume",
                                title: "Volume",
                                value: String(format: "%.0f %@", unitManager.displayWeight(totalVolume), unitManager.weightUnit)
                            )

                            summaryStatCard(
                                icon: "exercises",
                                title: "Exercises",
                                value: "\(exerciseCount)"
                            )
                        }
                        .opacity(animationTrigger ? 1 : 0)
                        .offset(y: animationTrigger ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(0.55), value: animationTrigger)
                    }
                    .padding(.horizontal)

                    // Strength Highlights (only shown when there are new PRs)
                    if strength1RMHighlights.contains(where: { $0.isNewPr }) {
                        strengthHighlightsSection
                            .padding(.horizontal)
                            .opacity(animationTrigger ? 1 : 0)
                            .offset(y: animationTrigger ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.65), value: animationTrigger)
                    }

                    // Exercise Breakdown
                    exercisesSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        shareWorkout()
                    } label: {
                        Image("share")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 52, height: 52)
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                if colorScheme == .dark {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                }
                            }
                            .shadow(color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear, radius: 12, x: 0, y: 4)
                    }
                    .buttonStyle(ScalePressStyle())

                    PrimaryCTAButton("Done") {
                        onDismiss()
                    }
                }
                .opacity(animationTrigger ? 1 : 0)
                .offset(y: animationTrigger ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.85), value: animationTrigger)
                .padding(.horizontal)
                .padding(.bottom, 16)
                .padding(.top, 8)
                .background(
                    Color.appBackground.opacity(0.75)
                        .ignoresSafeArea()
                )
            }
        }
        .sentryScreen("WorkoutSummary")
        .interactiveDismissDisabled()
        .onAppear {
            animationTrigger = true
            
            // Fire celebration after the header fades in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                celebrationTrigger += 1
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            shareImage = nil
        } content: {
            if let shareImage {
                SharePreviewSheet(image: shareImage)
                    .sheetContentTransition()
            }
        }
        .sheet(isPresented: $show1RMShareSheet) {
            share1RMImage = nil
        } content: {
            if let share1RMImage {
                SharePreviewSheet(image: share1RMImage)
                    .sheetContentTransition()
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
    
    private func share1RM(_ highlight: Strength1RMHighlight) {
        let card = Shareable1RMCard(
            exerciseName: highlight.exerciseName,
            estimated1rm: String(format: "%.1f %@", unitManager.displayWeight(highlight.estimated1rm), unitManager.weightUnit),
            previousBest: highlight.previousBest > 0
                ? String(format: "%.1f %@", unitManager.displayWeight(highlight.previousBest), unitManager.weightUnit)
                : nil,
            improvement: highlight.previousBest > 0
                ? String(format: "+%.1f %@", unitManager.displayWeight(highlight.estimated1rm - highlight.previousBest), unitManager.weightUnit)
                : nil
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            share1RMImage = image
            show1RMShareSheet = true
        }
    }

    // MARK: - Strength Highlights Section
    
    private var strengthHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strength Highlights", comment: "Section header")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.appText)
            
            VStack(spacing: 10) {
                ForEach(strength1RMHighlights.filter { $0.isNewPr }) { highlight in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            IconBadge(assetName: "crown", color: .orange, size: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("New PR", comment: "Personal record badge")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.orange)

                                Text(highlight.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)

                                Text("Estimated 1RM", comment: "1RM label")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appTertiaryText.opacity(0.7))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(unitManager.displayWeight(highlight.estimated1rm), specifier: "%.1f") \(unitManager.weightUnit)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.appText)

                                if highlight.previousBest > 0 {
                                    let improvement = highlight.estimated1rm - highlight.previousBest
                                    Text("+\(unitManager.displayWeight(improvement), specifier: "%.1f") \(unitManager.weightUnit)")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.green)
                                }
                            }
                        }

                        Button {
                            share1RM(highlight)
                        } label: {
                            HStack(spacing: 6) {
                                Image("share")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 13, height: 13)
                                Text("Share PR", comment: "Share button")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(Color.orange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(ScalePressStyle())
                        .padding(.top, 10)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1.5)
                    }
                    .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 12, x: 0, y: 4)
                }
            }
        }
    }
    
    // MARK: - Exercises Section
    
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises", comment: "Section header")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.appText)
                .opacity(animationTrigger ? 1 : 0)
                .offset(y: animationTrigger ? 0 : 20)
                .animation(.easeOut(duration: 0.35).delay(0.7), value: animationTrigger)
            
            ForEach(Array(groupedSets.enumerated()), id: \.offset) { index, group in
                exerciseCard(
                    name: group.exercise.name,
                    sets: group.sets,
                    isCardio: group.exercise.exerciseType == "cardio"
                )
                .opacity(animationTrigger ? 1 : 0)
                .offset(y: animationTrigger ? 0 : 20)
                .animation(.easeOut(duration: 0.35).delay(0.7 + Double(index) * 0.15), value: animationTrigger)
            }
        }
    }
    
    private func exerciseCard(name: String, sets: [LocalWorkoutSet], isCardio: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(
                    assetName: isCardio ? "cardio" : "musclegroup",
                    size: 32
                )
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)
            }
            
            VStack(spacing: 4) {
                // Header
                HStack {
                    Text("SET", comment: "Column header")
                        .frame(width: 50, alignment: .leading)

                    if isCardio {
                        Text("DURATION", comment: "Column header")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("WEIGHT", comment: "Column header")
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("REPS", comment: "Column header")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Image("check")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Color.clear)
                        .frame(width: 30)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appTertiaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                ForEach(sets, id: \.id) { set in
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
    
    private func setRow(set: LocalWorkoutSet, isCardio: Bool) -> some View {
        let routineExercise = routineExercises.first(where: {
            $0.exerciseId == set.exerciseId && $0.orderIndex == (set.orderIndex ?? Int.max)
        })
        
        return HStack {
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
                    Text(formattedSetDuration(duration))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let targetDuration = routineExercise?.durationSeconds {
                    Text(formattedSetDuration(targetDuration))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appTertiaryText)
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
                        .foregroundStyle(set.completed ? Color.appText : Color.appTertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let targetWeight = routineExercise?.targetWeight {
                    Text(String(format: "%.1f %@", unitManager.displayWeight(targetWeight), unitManager.weightUnit))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appTertiaryText)
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
                        .foregroundStyle(set.completed ? Color.appText : Color.appTertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let targetReps = routineExercise?.repsTarget {
                    Text(targetReps)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appTertiaryText)
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
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.green)
                    .frame(width: 30)
            } else {
                Image("circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.appTertiaryText)
                    .frame(width: 30)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
    
    private func summaryStatCard(icon: String, title: LocalizedStringKey, value: String, isSystemImage: Bool = false) -> some View {
        VStack(spacing: 8) {
            if isSystemImage {
                IconBadge(systemName: icon, size: 36)
            } else {
                IconBadge(assetName: icon, size: 36)
            }
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.appText)
            
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appSecondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
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
                VStack(spacing: 14) {
                    Image("check-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(Color.green)
                    
                    Text("Workout Completed", comment: "Share card header")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }

                // Stats
                VStack(spacing: 0) {
                    shareStatItem(icon: "clock", value: formattedDuration, label: String(localized: "Duration"))
                        .padding(.vertical, 16)
                    
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(height: 1)
                    
                    shareStatItem(icon: "volume", value: totalVolume, label: String(localized: "Volume"))
                        .padding(.vertical, 16)
                    
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(height: 1)
                    
                    shareStatItem(icon: "list", value: "\(exerciseCount)", label: String(localized: "Exercises"))
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.06))
                )
            }
            .padding(.horizontal, 36)
            
            Spacer()
            
            // Branding
            HStack(spacing: 6) {
                Text(verbatim: "Pulse")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(verbatim: "Workout Tracker")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.bottom, 48)
        }
        // 1080x1920 at 3x scale = 360x640pt
        .frame(width: 360, height: 640)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.06, blue: 0.08), Color(red: 0.1, green: 0.1, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func shareStatItem(icon: String, value: String, label: String) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(accentColor)
                    .frame(width: 32, height: 32)
                    .background(accentColor.opacity(0.15), in: Circle())
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.55))
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Shareable 1RM Card

struct Shareable1RMCard: View {
    let exerciseName: String
    let estimated1rm: String
    let previousBest: String?
    let improvement: String?

    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 14) {
                    Image("crown")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(Color.orange)

                    Text("New Personal Record", comment: "Share card header")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }

                // Exercise name
                Text(exerciseName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                // 1RM value
                VStack(spacing: 12) {
                    Text("Estimated 1RM", comment: "1RM label on share card")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.45))

                    Text(estimated1rm)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if let improvement {
                        Text(improvement)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.green)
                    }

                    if let previousBest {
                        Text("Previous: \(previousBest)", comment: "Previous best 1RM")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.06))
                )
            }
            .padding(.horizontal, 36)

            Spacer()

            // Branding
            HStack(spacing: 6) {
                Text(verbatim: "Pulse")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(verbatim: "Workout Tracker")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.bottom, 48)
        }
        .frame(width: 360, height: 640)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.06, blue: 0.08), Color(red: 0.1, green: 0.1, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Share Preview Sheet

struct SharePreviewSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    IconBadge(assetName: "share", size: 48)
                        .padding(.top, 24)
                    
                    Text("Share Preview", comment: "Sheet title")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                }
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                if colorScheme == .dark {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(ScalePressStyle())
                    
                    PrimaryCTAButton("Share", icon: "share") {
                        presentShareSheet()
                        PostHogSDK.shared.capture("workout_shared")
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

// MARK: - Celebration Keyframe Values

private struct CelebrationValues {
    var scale = 1.0
    var glowOpacity = 0.0
}
