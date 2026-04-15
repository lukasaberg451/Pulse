//
//  ActiveWorkoutView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import SwiftUI
import SwiftData
import StoreKit
import WatchConnectivity

enum WorkoutAlertType {
    case cancel, finish, emptyFinish
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
    @Environment(\.requestReview) private var requestReview
    @State private var alertType: WorkoutAlertType?
    @State private var showWorkoutSummary = false
    @State private var summaryElapsedTime: TimeInterval = 0
    @State private var summarySets: [LocalWorkoutSet] = []
    @State private var summary1RMHighlights: [Strength1RMHighlight] = []
    @AppStorage("hasSeenWatchTip") private var hasSeenWatchTip = false
    @State private var expandedCompletedExercises: Set<UUID> = []

    /// Tracks the ID of the current (active) exercise for auto-scrolling
    private var currentExerciseId: UUID? {
        viewModel.allWorkoutExercises.first(where: { exerciseStatus($0) == .current })?.id
    }
    
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
        let setsForExercise = viewModel.sets.filter { $0.exerciseId == routineExercise.exerciseId && $0.orderIndex == routineExercise.orderIndex }
        
        // If no sets exist yet, it's upcoming
        if setsForExercise.isEmpty {
            return .upcoming
        }
        
        let allCompleted = setsForExercise.allSatisfy { $0.completed }
        if allCompleted {
            return .completed
        }
        
        let hasAnyCompleted = setsForExercise.contains { $0.completed }
        let isCurrentInVM = viewModel.routineExercises.first?.exerciseId == routineExercise.exerciseId && viewModel.routineExercises.first?.orderIndex == routineExercise.orderIndex
        
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
                
                ScrollViewReader { scrollProxy in
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
                                    .id(routineExercise.id)
                                    .padding(.horizontal)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: status)
                                }
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.top, 8)
                    }
                    .onChange(of: currentExerciseId) { _, newId in
                        guard let newId else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            scrollProxy.scrollTo(newId, anchor: .center)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                
                // Watch tip overlay
                if !hasSeenWatchTip {
                    VStack {
                        HStack(spacing: 12) {
                            IconBadge(assetName: "watch", size: 28)
                            
                            Text("Use Pulse on your Apple Watch to track along")
                                .font(.caption)
                                .foregroundStyle(Color.appText)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    hasSeenWatchTip = true
                                }
                            } label: {
                                Image("xmark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 17, height: 17)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                        }
                        .padding(14)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.appText.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .accessibilityIdentifier("activeWorkoutView")
            .sentryScreen("ActiveWorkout")
            .navigationTitle(routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        alertType = .cancel
                    }
                    .foregroundStyle(Color.appSecondaryText)
                    .disabled(viewModel.isFinishing)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isFinishing {
                        ProgressView()
                            .tint(Color.appAccent)
                    } else {
                        Button("Finish") {
                            let hasCompletedSets = viewModel.sets.contains { $0.completed }
                            alertType = hasCompletedSets ? .finish : .emptyFinish
                        }
                        .accessibilityIdentifier("finishWorkoutButton")
                        .foregroundStyle(Color.appAccent)
                        .fontWeight(.semibold)
                    }
                }
            }
            .alert(alertType == .emptyFinish ? "No Sets Completed" : (alertType == .cancel ? "Cancel Workout?" : "Finish Workout?"),
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
                } else if alertType == .emptyFinish {
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
                            summary1RMHighlights = viewModel.strength1RMHighlights
                            showWorkoutSummary = true
                        }
                    }
                }
            } message: {
                if alertType == .cancel {
                    Text("This workout will not be saved.")
                } else if alertType == .emptyFinish {
                    Text("Complete at least one set before finishing your workout. Would you like to continue or discard?")
                } else if viewModel.isOfflineMode {
                    Text("Your workout will be saved locally and synced when you're back online.")
                } else {
                    Text("Are you sure you want to finish this workout?")
                }
            }
            .fullScreenCover(isPresented: $showWorkoutSummary) {
                WorkoutSummaryView(
                    routineName: routine.name,
                    elapsedTime: summaryElapsedTime,
                    sets: summarySets,
                    exercises: exercises,
                    routineExercises: routineExercises,
                    strength1RMHighlights: summary1RMHighlights,
                    onDismiss: {
                        showWorkoutSummary = false
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            requestReview()
                        }
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
                Image("stopwatch")
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

// MARK: - Hold to Add Set Button
struct HoldToAddSetButton: View {
    let onAdd: () -> Void
    
    @State private var isPressed = false
    @State private var holdProgress: CGFloat = 0
    @State private var holdCompleted = false
    @GestureState private var isDetectingLongPress = false
    
    private let holdDuration: Double = 0.5
    
    var body: some View {
        HStack(spacing: 6) {
            Image("plus")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
            Text("Hold to Add Set")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.appAccent.opacity(isDetectingLongPress ? 0.5 : 1.0))
        .scaleEffect(isDetectingLongPress ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDetectingLongPress)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(alignment: .leading) {
            GeometryReader { geo in
                Color.appAccent.opacity(0.08)
                    .frame(width: geo.size.width * holdProgress)
                    .animation(.linear(duration: holdDuration), value: holdProgress)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: holdDuration)
                .updating($isDetectingLongPress) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { _ in
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onAdd()
                }
        )
        .onChange(of: isDetectingLongPress) { _, pressing in
            holdProgress = pressing ? 1.0 : 0.0
        }
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
        viewModel.sets.filter { $0.exerciseId == exercise.id && $0.orderIndex == routineExercise.orderIndex }
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
                        SetRow(
                            viewModel: viewModel,
                            set: set,
                            exercise: exercise,
                            routineExercise: routineExercise,
                            isFirstIncomplete: isFirstIncompleteSet(set),
                            isCurrent: status == .current,
                            isLocked: status == .completed
                        )
                        
                        if set.id != sets.last?.id {
                            Divider()
                                .background(Color.appText.opacity(0.04))
                                .padding(.horizontal, 16)
                        }
                    }
                    
                    // Add set button (hidden for completed exercises)
                    if status != .completed {
                        HoldToAddSetButton {
                            Task {
                                await viewModel.addSet(exerciseId: exercise.id, targetSets: routineExercise.sets, orderIndex: routineExercise.orderIndex)
                            }
                        }
                    }
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
                
                if exercise.exerciseType != "cardio",
                   let lastWeight = viewModel.lastWeights[exercise.id] {
                    let displayWeight = UnitManager.shared.displayWeight(lastWeight)
                    let unit = UnitManager.shared.weightUnit
                    let formatted = displayWeight.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", displayWeight)
                        : String(format: "%.1f", displayWeight)
                    Text("Last session best: \(formatted) \(unit)")
                        .font(.caption)
                        .foregroundStyle(Color.appAccent)
                }
            }
            
            Spacer()
            
            if status == .completed {
                Image(isExpanded ? "chevron-up" : "chevron-down")
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
            IconBadge(assetName: exercise.exerciseType == "cardio" ? "cardio" : "musclegroup", size: 32)
        case .upcoming:
            ZStack {
                Circle()
                    .fill(Color.appText.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image("circle-dashed")
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

// MARK: - Set Row
struct SetRow: View {
    @ObservedObject var viewModel: OfflineActiveWorkoutViewModel
    @EnvironmentObject var unitManager: UnitManager
    let set: LocalWorkoutSet
    let exercise: Exercise
    let routineExercise: RoutineExercise
    let isFirstIncomplete: Bool
    let isCurrent: Bool
    var isLocked: Bool = false
    
    @State private var weightText: String = ""
    @State private var hasInitializedWeight = false
    
    var body: some View {
        // Foreground row content
        HStack(spacing: 14) {
            // Set number pill — tap target for complete/undo
            Button {
                toggleSetCompletion()
            } label: {
                ZStack {
                    Color.clear
                        .frame(width: 44, height: 44)
                    
                    Text("\(set.setNumber)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(set.completed ? .white : Color.appText)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(set.completed ? Color.green : Color.appText.opacity(0.08))
                        )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if exercise.exerciseType == "strength" {
                strengthContent
            } else {
                cardioContent
            }
            
            Spacer()
            
            // Status indicator — primary tap target for complete/undo
            Button {
                toggleSetCompletion()
            } label: {
                ZStack {
                    // Invisible hit area for minimum 44pt touch target
                    Color.clear
                        .frame(width: 44, height: 44)
                    
                    if set.completed {
                        Image("check-circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(Color.green)
                    } else {
                        Circle()
                            .strokeBorder(isFirstIncomplete && isCurrent ? Color.appAccent.opacity(0.5) : Color.appText.opacity(0.15), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        .onAppear {
            if !hasInitializedWeight {
                let target = routineExercise.targetWeight ?? 0
                let display = unitManager.displayWeight(target)
                weightText = formatWeight(display)
                hasInitializedWeight = true
            }
        }
    }
    
    private func toggleSetCompletion() {
        // Prevent undoing sets on completed/locked exercises
        if isLocked && set.completed { return }
        
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        if set.completed {
            // Undo — light haptic
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                viewModel.updateSet(
                    set: set,
                    reps: set.reps,
                    weight: set.weight,
                    durationSeconds: set.durationSeconds,
                    completed: false
                )
            }
        } else {
            // Complete — medium haptic
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            let targetReps = routineExercise.repsTarget.flatMap { Int($0) }
            let actualWeight = exercise.exerciseType == "strength" ? (enteredWeight ?? routineExercise.targetWeight) : routineExercise.targetWeight
            let targetDuration = routineExercise.durationSeconds
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                viewModel.updateSet(
                    set: set,
                    reps: targetReps,
                    weight: actualWeight,
                    durationSeconds: targetDuration,
                    completed: true
                )
            }
        }
    }
    
    /// The weight value entered by the user, converted back to kg for storage.
    private var enteredWeight: Double? {
        let cleaned = weightText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let displayValue = Double(cleaned) else { return nil }
        return unitManager.toKg(displayValue)
    }
    
    /// Sanitizes weight input to allow only digits and a single decimal separator (comma or dot).
    /// Caps the value at 1000 kg (or the display-unit equivalent).
    private func sanitizeWeightInput(_ newValue: String) -> String {
        // Replace comma with dot for consistent handling
        var sanitized = newValue.replacingOccurrences(of: ",", with: ".")
        
        // Allow only digits and dots
        sanitized = String(sanitized.filter { $0.isNumber || $0 == "." })
        
        // Ensure only one decimal point
        if sanitized.filter({ $0 == "." }).count > 1 {
            let parts = sanitized.split(separator: ".", omittingEmptySubsequences: false)
            sanitized = parts[0] + "." + parts.dropFirst().joined()
        }
        
        // Cap at 1000 kg (converted to display unit)
        let maxDisplay = unitManager.displayWeight(1000)
        if let value = Double(sanitized), value > maxDisplay {
            sanitized = formatWeight(maxDisplay)
        }
        
        return sanitized
    }
    
    @ViewBuilder
    private var strengthContent: some View {
        HStack(spacing: 3) {
            if set.completed {
                Text("\(unitManager.displayWeight(set.weight ?? 0), specifier: "%.1f")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appText)
            } else {
                SelectAllTextField(text: $weightText, placeholder: "0", identifier: "weightField_\(set.setNumber)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appText)
                    .frame(width: 50, height: 24)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.appText.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .onChange(of: weightText) { _, newValue in
                        let sanitized = sanitizeWeightInput(newValue)
                        if sanitized != newValue {
                            weightText = sanitized
                        }
                    }
            }
            Text(unitManager.weightUnit)
                .font(.caption2)
                .foregroundStyle(Color.appSecondaryText)
        }
        .frame(width: 80, alignment: .leading)
        
        HStack(spacing: 3) {
            Text(routineExercise.repsTarget ?? "—")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appText)
            Text("reps")
                .font(.caption2)
                .foregroundStyle(Color.appSecondaryText)
        }
    }
    
    private func formatWeight(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
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

// MARK: - Select All TextField
struct SelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var identifier: String?
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.font = .preferredFont(forTextStyle: .subheadline)
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        textField.setContentHuggingPriority(.required, for: .horizontal)
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.accessibilityIdentifier = identifier
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = UIColor(Color.appText)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Delay selectAll so it runs after the field is fully active
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }
        
        @objc func textChanged(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}
