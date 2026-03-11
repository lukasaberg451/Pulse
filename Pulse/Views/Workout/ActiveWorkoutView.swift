//
//  ActiveWorkoutView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import SwiftUI
import SwiftData
import WatchConnectivity

enum WorkoutAlertType {
    case cancel, finish
}

// MARK: - Wrapper to inject modelContext
struct ActiveWorkoutView: View {
    let routine: Routine
    let routineExercises: [RoutineExercise]
    let exercises: [Exercise]
    let scheduledWorkoutId: UUID?
    let workoutSessionId: UUID?
    var resumingSession: LocalWorkoutSession? = nil
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ActiveWorkoutViewContent(
            routine: routine,
            routineExercises: routineExercises,
            exercises: exercises,
            scheduledWorkoutId: scheduledWorkoutId,
            workoutSessionId: workoutSessionId,
            resumingSession: resumingSession,
            modelContext: modelContext
        )
    }
}

// MARK: - Main Content View
struct ActiveWorkoutViewContent: View {
    let routine: Routine
    let routineExercises: [RoutineExercise]
    let exercises: [Exercise]
    let scheduledWorkoutId: UUID?
    
    @StateObject private var viewModel: OfflineActiveWorkoutViewModel
    @EnvironmentObject var syncService: WorkoutSyncService
    @Environment(\.dismiss) var dismiss
    @State private var alertType: WorkoutAlertType?
    @State private var showWorkoutSummary = false
    @State private var summaryElapsedTime: TimeInterval = 0
    @State private var summarySets: [LocalWorkoutSet] = []
    @AppStorage("hasSeenWatchTip") private var hasSeenWatchTip = false
    @State private var expandedCompletedExercises: Set<UUID> = []
    
    init(routine: Routine, routineExercises: [RoutineExercise], exercises: [Exercise], scheduledWorkoutId: UUID? = nil, workoutSessionId: UUID? = nil, resumingSession: LocalWorkoutSession? = nil, modelContext: ModelContext) {
        self.routine = routine
        self.routineExercises = routineExercises
        self.exercises = exercises
        self.scheduledWorkoutId = scheduledWorkoutId
        _viewModel = StateObject(wrappedValue: OfflineActiveWorkoutViewModel(
            routine: routine,
            routineExercises: routineExercises,
            scheduledWorkoutId: scheduledWorkoutId,
            workoutSessionId: workoutSessionId,
            exercises: exercises,
            modelContext: modelContext,
            resumingSession: resumingSession
        ))
    }
    
    /// Determines the status of an exercise based on its sets
    private func exerciseStatus(_ routineExercise: RoutineExercise) -> ExerciseCardStatus {
        let setsForExercise = viewModel.sets.filter { $0.exerciseId == routineExercise.exerciseId }
        
        // If no sets exist yet, it's upcoming
        if setsForExercise.isEmpty {
            return .upcoming
        }
        
        let allCompleted = setsForExercise.allSatisfy { $0.completed }
        if allCompleted {
            return .completed
        }
        
        let hasAnyCompleted = setsForExercise.contains { $0.completed }
        let isCurrentInVM = viewModel.routineExercises.first?.exerciseId == routineExercise.exerciseId
        
        if isCurrentInVM || hasAnyCompleted {
            return .current
        }
        
        return .upcoming
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 14) {
                        // Offline Status Banner
                        OfflineStatusBanner()
                            .animation(.easeInOut, value: syncService.isOnline)
                        
                        // Workout Timer Header Card
                        TimerHeaderCard(
                            elapsedTimeText: viewModel.formatElapsedTime()
                        )
                        .padding(.horizontal)
                        
                        // Rest Timer Banner
                        if viewModel.isRestTimerActive {
                            RestTimerBanner(
                                timeRemaining: viewModel.restTimeRemaining,
                                onSkip: {
                                    viewModel.stopRestTimer()
                                }
                            )
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Exercise Cards
                        ForEach(viewModel.allWorkoutExercises) { routineExercise in
                            if let exercise = exercises.first(where: { $0.id == routineExercise.exerciseId }) {
                                let status = exerciseStatus(routineExercise)
                                
                                ExerciseCard(
                                    viewModel: viewModel,
                                    routineExercise: routineExercise,
                                    exercise: exercise,
                                    status: status,
                                    isExpanded: status == .current || expandedCompletedExercises.contains(routineExercise.id),
                                    onToggleExpand: {
                                        if status == .completed {
                                            withAnimation(.spring(response: 0.3)) {
                                                if expandedCompletedExercises.contains(routineExercise.id) {
                                                    expandedCompletedExercises.remove(routineExercise.id)
                                                } else {
                                                    expandedCompletedExercises.insert(routineExercise.id)
                                                }
                                            }
                                        }
                                    }
                                )
                                .padding(.horizontal)
                                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: status)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
                
                // Watch tip overlay
                if !hasSeenWatchTip {
                    VStack {
                        HStack(spacing: 12) {
                            IconBadge(systemName: "applewatch", size: 28)
                            
                            Text("Open Pulse on your Apple Watch to track along")
                                .font(.caption)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    hasSeenWatchTip = true
                                }
                            } label: {
                                Image("x-mark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 17, height: 17)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle(routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        alertType = .cancel
                    }
                    .foregroundStyle(Color.appSecondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        alertType = .finish
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
            .alert(alertType == .cancel ? "Cancel Workout?" : "Finish Workout?",
                   isPresented: Binding(
                       get: { alertType != nil },
                       set: { if !$0 { alertType = nil } }
                   )) {
                if alertType == .cancel {
                    Button("Continue Workout", role: .cancel) { }
                    Button("Discard", role: .destructive) {
                        Task {
                            await viewModel.cancelWorkout()
                            dismiss()
                        }
                    }
                } else {
                    Button("Cancel", role: .cancel) { }
                    Button("Finish") {
                        Task {
                            summaryElapsedTime = viewModel.elapsedTime
                            summarySets = viewModel.sets
                            await viewModel.finishWorkout()
                            showWorkoutSummary = true
                        }
                    }
                }
            } message: {
                if alertType == .cancel {
                    Text("This workout will not be saved.")
                } else {
                    Text(viewModel.isOfflineMode
                        ? "Your workout will be saved locally and synced when you're back online."
                        : "Are you sure you want to finish this workout?")
                }
            }
            .fullScreenCover(isPresented: $showWorkoutSummary) {
                WorkoutSummaryView(
                    routineName: routine.name,
                    elapsedTime: summaryElapsedTime,
                    sets: summarySets,
                    exercises: exercises,
                    onDismiss: {
                        showWorkoutSummary = false
                        dismiss()
                    }
                )
            }
            .task {
                await viewModel.startWorkout()
            }
        }
    }
}

// MARK: - Exercise Card Status
enum ExerciseCardStatus {
    case completed, current, upcoming
}

// MARK: - Timer Header Card
struct TimerHeaderCard: View {
    let elapsedTimeText: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("WORKOUT TIME")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.appSecondaryText)
                Text(elapsedTimeText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appAccent)
                    .contentTransition(.numericText())
            }
            
            Spacer()
        }
        .padding(18)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .shadow(
            color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear,
            radius: 16, x: 0, y: 6
        )
    }
}

// MARK: - Rest Timer Banner
struct RestTimerBanner: View {
    let timeRemaining: Int
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                // Pulsing rest icon
                Image(systemName: "bed.double.fill")
                    .font(.body)
                    .foregroundStyle(Color.appAccent)
                    .symbolEffect(.pulse, options: .repeating)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("REST TIME")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.appSecondaryText)
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appAccent)
                        .contentTransition(.numericText())
                }
            }
            
            Spacer()
            
            Button {
                onSkip()
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.appAccentSubtle)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScalePressStyle())
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(
            color: colorScheme == .light ? Color.appAccent.opacity(0.12) : Color.clear,
            radius: 12, x: 0, y: 4
        )
    }
    
    func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Exercise Card
struct ExerciseCard: View {
    @ObservedObject var viewModel: OfflineActiveWorkoutViewModel
    let routineExercise: RoutineExercise
    let exercise: Exercise
    let status: ExerciseCardStatus
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var sets: [LocalWorkoutSet] {
        viewModel.sets.filter { $0.exerciseId == exercise.id }
    }
    
    private var completedSetsCount: Int {
        sets.filter { $0.completed }.count
    }
    
    private var totalSetsCount: Int {
        sets.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            exerciseHeader
            
            // Expanded content (set rows)
            if isExpanded {
                Divider()
                    .background(Color.appText.opacity(0.06))
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    ForEach(sets) { set in
                        SwipeableSetRow(
                            viewModel: viewModel,
                            set: set,
                            exercise: exercise,
                            routineExercise: routineExercise,
                            isFirstIncomplete: isFirstIncompleteSet(set),
                            isCurrent: status == .current
                        )
                        
                        if set.id != sets.last?.id {
                            Divider()
                                .background(Color.appText.opacity(0.04))
                                .padding(.horizontal, 16)
                        }
                    }
                    
                    // Add set button
                    Button {
                        Task {
                            await viewModel.addSet(exerciseId: exercise.id, targetSets: routineExercise.sets, orderIndex: routineExercise.orderIndex)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image("plus-circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                            Text("Add Set")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(ScalePressStyle())
                }
            }
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if status == .current {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 1.5)
            } else if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .shadow(
            color: colorScheme == .light
                ? (status == .current ? Color.appAccent.opacity(0.15) : Color.black.opacity(0.08))
                : Color.clear,
            radius: status == .current ? 16 : 12,
            x: 0,
            y: status == .current ? 6 : 4
        )
    }
    
    private var exerciseHeader: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(status == .upcoming ? Color.appSecondaryText : Color.appText)
                    
                    if status == .current {
                        Text("Active")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(LinearGradient.accentGradient)
                            .clipShape(Capsule())
                    }
                }
                
                exerciseSubtitle
            }
            
            Spacer()
            
            if status == .completed {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appTertiaryText)
                    .padding(6)
                    .background(Color.appText.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            if status == .completed {
                onToggleExpand()
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .completed:
            IconBadge(assetName: "check", color: .green, size: 32)
        case .current:
            IconBadge(systemName: exercise.exerciseType == "cardio" ? "figure.run" : "figure.strengthtraining.traditional", size: 32)
        case .upcoming:
            ZStack {
                Circle()
                    .fill(Color.appText.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image(systemName: "circle.dotted")
                    .font(.caption)
                    .foregroundStyle(Color.appTertiaryText)
            }
        }
    }
    
    @ViewBuilder
    private var exerciseSubtitle: some View {
        switch status {
        case .completed:
            Text("\(completedSetsCount)/\(totalSetsCount) sets completed")
                .font(.caption)
                .foregroundStyle(.green)
        case .current:
            if let reps = routineExercise.repsTarget {
                Text("\(completedSetsCount)/\(totalSetsCount) sets \u{2022} \(reps) reps \u{2022} \(routineExercise.restSeconds)s rest")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            } else if let durationSeconds = routineExercise.durationSeconds {
                let minutes = durationSeconds / 60
                let seconds = durationSeconds % 60
                let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                Text("\(completedSetsCount)/\(totalSetsCount) sets \u{2022} \(durationText) \u{2022} \(routineExercise.restSeconds)s rest")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }
        case .upcoming:
            if let reps = routineExercise.repsTarget {
                Text("\(routineExercise.sets) sets \u{00d7} \(reps) reps")
                    .font(.caption)
                    .foregroundStyle(Color.appTertiaryText)
            } else if let durationSeconds = routineExercise.durationSeconds {
                let minutes = durationSeconds / 60
                let seconds = durationSeconds % 60
                let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                Text("\(routineExercise.sets) sets \u{00d7} \(durationText)")
                    .font(.caption)
                    .foregroundStyle(Color.appTertiaryText)
            }
        }
    }
    
    private func isFirstIncompleteSet(_ set: LocalWorkoutSet) -> Bool {
        guard let firstIncomplete = sets.first(where: { !$0.completed }) else { return false }
        return firstIncomplete.id == set.id
    }
}

// MARK: - Swipeable Set Row
struct SwipeableSetRow: View {
    @ObservedObject var viewModel: OfflineActiveWorkoutViewModel
    @EnvironmentObject var unitManager: UnitManager
    let set: LocalWorkoutSet
    let exercise: Exercise
    let routineExercise: RoutineExercise
    let isFirstIncomplete: Bool
    let isCurrent: Bool
    
    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    
    private let swipeThreshold: CGFloat = -80
    private let undoThreshold: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Background revealed on swipe - only render when actively dragging
            if dragOffset != 0 {
                HStack {
                    // Undo action (swipe right on completed sets)
                    if set.completed {
                        HStack(spacing: 6) {
                            Image("arrow-uturn-left")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                            Text("Undo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 20)
                        .background(Color.orange)
                    }
                    
                    Spacer()
                    
                    // Complete action (swipe left on incomplete sets)
                    if !set.completed {
                        HStack(spacing: 6) {
                            Text("Complete")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image("check-circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                        }
                        .foregroundStyle(.white)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 20)
                        .background(Color.green)
                    }
                }
            }
            
            // Foreground row content
            HStack(spacing: 14) {
                // Set number pill
                Text("\(set.setNumber)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(set.completed ? .white : Color.appText)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(set.completed ? Color.green : Color.appText.opacity(0.08))
                    )
                
                if exercise.exerciseType == "strength" {
                    strengthContent
                } else {
                    cardioContent
                }
                
                Spacer()
                
                // Status indicator
                if set.completed {
                    Image("check-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                        .foregroundStyle(Color.green)
                } else if isFirstIncomplete && isCurrent {
                    HStack(spacing: 4) {
                        Text("Swipe")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.appAccent.opacity(0.6))
                        Image("chevron-left")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(Color.appAccent.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    Color.appSurface
                    if set.completed {
                        Color.green.opacity(0.04)
                    }
                }
            )
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let translation = value.translation.width
                        
                        // Only allow swipe left on incomplete sets, swipe right on completed sets
                        if !set.completed && translation < 0 {
                            dragOffset = translation
                            if translation < swipeThreshold && !hasTriggeredHaptic {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                hasTriggeredHaptic = true
                            }
                        } else if set.completed && translation > 0 {
                            dragOffset = translation
                            if translation > undoThreshold && !hasTriggeredHaptic {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                hasTriggeredHaptic = true
                            }
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        
                        if !set.completed && translation < swipeThreshold {
                            // Complete the set — delay state update so the swipe animation finishes first
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = 0
                            }
                            
                            let targetReps = routineExercise.repsTarget.flatMap { Int($0) }
                            let targetWeight = routineExercise.targetWeight
                            let targetDuration = routineExercise.durationSeconds
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    viewModel.updateSet(
                                        set: set,
                                        reps: targetReps,
                                        weight: targetWeight,
                                        durationSeconds: targetDuration,
                                        completed: true
                                    )
                                }
                            }
                        } else if set.completed && translation > undoThreshold {
                            // Undo the set
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = 0
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    viewModel.updateSet(
                                        set: set,
                                        reps: set.reps,
                                        weight: set.weight,
                                        durationSeconds: set.durationSeconds,
                                        completed: false
                                    )
                                }
                            }
                        } else {
                            // Snap back
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = 0
                            }
                        }
                        
                        hasTriggeredHaptic = false
                    }
            )
        }
        .clipShape(Rectangle())
        .onChange(of: set.completed) {
            dragOffset = 0
        }
    }
    
    @ViewBuilder
    private var strengthContent: some View {
        HStack(spacing: 3) {
            Text("\(unitManager.displayWeight(routineExercise.targetWeight ?? 0), specifier: "%.1f")")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appText)
            Text(unitManager.weightUnit)
                .font(.caption2)
                .foregroundStyle(Color.appSecondaryText)
        }
        .frame(width: 70, alignment: .leading)
        
        HStack(spacing: 3) {
            Text(routineExercise.repsTarget ?? "—")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appText)
            Text("reps")
                .font(.caption2)
                .foregroundStyle(Color.appSecondaryText)
        }
    }
    
    @ViewBuilder
    private var cardioContent: some View {
        let totalSeconds = routineExercise.durationSeconds ?? 0
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        HStack(spacing: 3) {
            if minutes > 0 {
                Text("\(minutes)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appText)
                Text("m")
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondaryText)
            }
            if seconds > 0 {
                Text("\(seconds)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appText)
                Text("s")
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
    }
}


