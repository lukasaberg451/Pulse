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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Offline Status Banner
                        OfflineStatusBanner()
                            .animation(.easeInOut, value: syncService.isOnline)
                        
                        // Workout Timer Header Card
                        TimerHeaderCard(
                            elapsedTimeText: viewModel.formatElapsedTime(),
                            isOfflineMode: viewModel.isOfflineMode
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
                        ForEach(routineExercises) { routineExercise in
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
                        HStack {
                            Image(systemName: "applewatch")
                                .foregroundStyle(Color.appAccent)
                            Text("Open Pulse on your Apple Watch to track along")
                                .font(.caption)
                                .foregroundStyle(Color.appText)
                            
                            Spacer()
                            
                            Button {
                                hasSeenWatchTip = true
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(Color.appText)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .padding()
                        
                        Spacer()
                    }
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
                    .foregroundStyle(Color.appText)
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
                            await viewModel.finishWorkout()
                            dismiss()
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
    let isOfflineMode: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Time")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.7))
                Text(elapsedTimeText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appAccent)
            }
            
            Spacer()
            
            if isOfflineMode {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "wifi.slash")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    
                    Text("Offline")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Rest Timer Banner
struct RestTimerBanner: View {
    let timeRemaining: Int
    let onSkip: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rest Time")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.7))
                Text(formatTime(timeRemaining))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appAccent)
            }
            
            Spacer()
            
            Button("Skip") {
                onSkip()
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.appAccent)
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appAccent, lineWidth: 2)
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
                    .background(Color.appText.opacity(0.1))
                    .padding(.horizontal)
                
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
                                .background(Color.appText.opacity(0.05))
                                .padding(.horizontal)
                        }
                    }
                    
                    // Add set button
                    Button {
                        Task {
                            await viewModel.addSet(exerciseId: exercise.id, targetSets: routineExercise.sets)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.subheadline)
                            Text("Add Set")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(status == .current ? 0.4 : 0.2), radius: status == .current ? 10 : 6, x: 0, y: status == .current ? 6 : 3)
    }
    
    private var exerciseHeader: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    
                    if status == .current {
                        Text("Current")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.appAccent)
                            .cornerRadius(6)
                    }
                }
                
                exerciseSubtitle
            }
            
            Spacer()
            
            // Expand/collapse chevron for completed exercises
            if status == .completed {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.4))
            }
        }
        .padding(16)
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
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.green)
        case .current:
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title3)
                .foregroundStyle(Color.appAccent)
        case .upcoming:
            Image(systemName: "circle.dotted")
                .font(.title2)
                .foregroundStyle(Color.appText.opacity(0.3))
        }
    }
    
    @ViewBuilder
    private var exerciseSubtitle: some View {
        switch status {
        case .completed:
            Text("\(completedSetsCount)/\(totalSetsCount) sets completed")
                .font(.caption)
                .foregroundStyle(Color.green.opacity(0.8))
        case .current:
            if let reps = routineExercise.repsTarget {
                Text("\(completedSetsCount)/\(totalSetsCount) sets \u{2022} \(reps) reps \u{2022} \(routineExercise.restSeconds)s rest")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.5))
            } else if let durationSeconds = routineExercise.durationSeconds {
                let minutes = durationSeconds / 60
                let seconds = durationSeconds % 60
                let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                Text("\(completedSetsCount)/\(totalSetsCount) sets \u{2022} \(durationText) \u{2022} \(routineExercise.restSeconds)s rest")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.5))
            }
        case .upcoming:
            if let reps = routineExercise.repsTarget {
                Text("\(routineExercise.sets) sets \u{00d7} \(reps) reps")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.5))
            } else if let durationSeconds = routineExercise.durationSeconds {
                let minutes = durationSeconds / 60
                let seconds = durationSeconds % 60
                let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                Text("\(routineExercise.sets) sets \u{00d7} \(durationText)")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.5))
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
            // Background revealed on swipe
            HStack {
                // Undo action (swipe right on completed sets)
                if set.completed {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline)
                            .fontWeight(.semibold)
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
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    .background(Color.green)
                }
            }
            
            // Foreground row content
            HStack(spacing: 16) {
                // Set number
                Text("\(set.setNumber)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(set.completed ? Color.green : Color.appText)
                    .frame(width: 30)
                
                if exercise.exerciseType == "strength" {
                    strengthContent
                } else {
                    cardioContent
                }
                
                Spacer()
                
                // Status indicator
                if set.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                        .font(.title3)
                } else if isFirstIncomplete && isCurrent {
                    // Swipe hint for the next set to complete
                    HStack(spacing: 4) {
                        Text("Swipe to complete")
                            .font(.caption2)
                            .foregroundStyle(Color.appAccent.opacity(0.7))
                        Image(systemName: "chevron.left")
                            .font(.caption2)
                            .foregroundStyle(Color.appAccent.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    Color.appSurface
                    if set.completed {
                        Color.green.opacity(0.05)
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
        .opacity(set.completed ? 1.0 : 1.0)
    }
    
    @ViewBuilder
    private var strengthContent: some View {
        HStack(spacing: 4) {
            Text("\(unitManager.displayWeight(routineExercise.targetWeight ?? 0), specifier: "%.1f")")
                .font(.body)
                .foregroundStyle(Color.appText)
            Text(unitManager.weightUnit)
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.6))
        }
        .frame(width: 70, alignment: .leading)
        
        HStack(spacing: 4) {
            Text(routineExercise.repsTarget ?? "—")
                .font(.body)
                .foregroundStyle(Color.appText)
            Text("reps")
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.6))
        }
    }
    
    @ViewBuilder
    private var cardioContent: some View {
        let totalSeconds = routineExercise.durationSeconds ?? 0
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        HStack(spacing: 4) {
            if minutes > 0 {
                Text("\(minutes)")
                    .font(.body)
                    .foregroundStyle(Color.appText)
                Text("m")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
            }
            if seconds > 0 {
                Text("\(seconds)")
                    .font(.body)
                    .foregroundStyle(Color.appText)
                Text("s")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
            }
        }
    }
}

// Keep the old versions for backwards compatibility if needed
struct ExerciseSetSection: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    let routineExercise: RoutineExercise
    let exercise: Exercise
    
    var sets: [WorkoutSet] {
        viewModel.sets.filter { $0.exerciseId == exercise.id }
    }
    
    var body: some View {
        ForEach(sets) { set in
            ExerciseSetRow(
                viewModel: viewModel,
                set: set,
                exercise: exercise,
                routineExercise: routineExercise
            )
        }
        
        // Add set button
        Button {
            Task {
                await viewModel.addSet(exerciseId: exercise.id, targetSets: routineExercise.sets)
            }
        } label: {
            Label("Add Set", systemImage: "plus.circle")
                .font(.caption)
                .foregroundStyle(Color.appAccent)
        }
    }
}

// ExerciseSetRow comes after this...

struct ExerciseSetRow: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    @EnvironmentObject var unitManager: UnitManager
    let set: WorkoutSet
    let exercise: Exercise
    let routineExercise: RoutineExercise
    
    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(Color.appText)
            if exercise.exerciseType == "strength" {
                // Weight and reps for strength
                HStack {
                    TextField("Weight", value: Binding(
                        get: { unitManager.displayWeight(set.weight ?? 0) },
                        set: { newValue in
                            Task {
                                await viewModel.updateSet(
                                    id: set.id,
                                    reps: set.reps,
                                    weight: unitManager.toKg(newValue),
                                    durationSeconds: nil,
                                    completed: set.completed
                                )
                            }
                        }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    
                    Text(unitManager.weightUnit)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
                
                HStack {
                    TextField("Reps", value: Binding(
                        get: { set.reps ?? 0 },
                        set: { newValue in
                            Task {
                                await viewModel.updateSet(
                                    id: set.id,
                                    reps: newValue,
                                    weight: set.weight,
                                    durationSeconds: nil,
                                    completed: set.completed
                                )
                            }
                        }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                }
            } else {
                // Duration for cardio - split into minutes and seconds
                HStack(spacing: 8) {
                    // Minutes
                    TextField("Min", value: Binding(
                        get: {
                            let totalSeconds = set.durationSeconds ?? routineExercise.durationSeconds ?? 0
                            return totalSeconds / 60
                        },
                        set: { newMinutes in
                            let currentSeconds = (set.durationSeconds ?? routineExercise.durationSeconds ?? 0) % 60
                            let totalSeconds = (newMinutes * 60) + currentSeconds
                            Task {
                                await viewModel.updateSet(
                                    id: set.id,
                                    reps: nil,
                                    weight: nil,
                                    durationSeconds: totalSeconds,
                                    completed: set.completed
                                )
                            }
                        }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    
                    Text("m")
                        .foregroundStyle(Color.appText.opacity(0.6))
                    
                    // Seconds
                    TextField("Sec", value: Binding(
                        get: {
                            let totalSeconds = set.durationSeconds ?? routineExercise.durationSeconds ?? 0
                            return totalSeconds % 60
                        },
                        set: { newSeconds in
                            let currentMinutes = (set.durationSeconds ?? routineExercise.durationSeconds ?? 0) / 60
                            let totalSeconds = (currentMinutes * 60) + newSeconds
                            Task {
                                await viewModel.updateSet(
                                    id: set.id,
                                    reps: nil,
                                    weight: nil,
                                    durationSeconds: totalSeconds,
                                    completed: set.completed
                                )
                            }
                        }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    
                    Text("s")
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Checkmark button
            Button {
                Task {
                    await viewModel.updateSet(
                        id: set.id,
                        reps: set.reps,
                        weight: set.weight,
                        durationSeconds: set.durationSeconds,
                        completed: !set.completed
                    )
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.completed ? Color.green : Color.gray)
                    .font(.title2)
            }
        }
        .opacity(set.completed ? 0.6 : 1.0)
    }
}
