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

// Wrapper to inject modelContext
struct ActiveWorkoutView: View {
    let routine: Routine
    let routineExercises: [RoutineExercise]
    let exercises: [Exercise]
    let scheduledWorkoutId: UUID?
    let workoutSessionId: UUID?
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ActiveWorkoutViewContent(
            routine: routine,
            routineExercises: routineExercises,
            exercises: exercises,
            scheduledWorkoutId: scheduledWorkoutId,
            workoutSessionId: workoutSessionId,
            modelContext: modelContext
        )
    }
}

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
    
    init(routine: Routine, routineExercises: [RoutineExercise], exercises: [Exercise], scheduledWorkoutId: UUID? = nil, workoutSessionId: UUID? = nil, modelContext: ModelContext) {
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
            modelContext: modelContext
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack {
                        // Offline Status Banner
                        OfflineStatusBanner()
                            .animation(.easeInOut, value: syncService.isOnline)
                    }
                    .padding(.bottom, 20)
                        
                    // Workout Timer Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Workout Time")
                                .font(.caption)
                                .foregroundStyle(Color.appText.opacity(0.7))
                            Text(viewModel.formatElapsedTime())
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appAccent)
                        }
                        
                        Spacer()
                        
                        // Offline indicator
                        if viewModel.isOfflineMode {
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
                    .padding()
                    .background(Color.appSurface)
                    
                    // Rest Timer Banner (shown when active)
                    if viewModel.isRestTimerActive {
                        RestTimerBanner(
                            timeRemaining: viewModel.restTimeRemaining,
                            onSkip: {
                                viewModel.stopRestTimer()
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Exercise List
                    List {
                        ForEach(routineExercises) { routineExercise in
                            if let exercise = exercises.first(where: { $0.id == routineExercise.exerciseId }) {
                                Section {
                                    OfflineExerciseSetSection(
                                        viewModel: viewModel,
                                        routineExercise: routineExercise,
                                        exercise: exercise
                                    )
                                } header: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundStyle(Color.appText)
                                        if let reps = routineExercise.repsTarget {
                                            Text("\(routineExercise.sets) sets × \(reps) reps • \(routineExercise.restSeconds)s rest")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                        } else if let durationSeconds = routineExercise.durationSeconds {
                                            // Format duration in minutes and seconds
                                            let minutes = durationSeconds / 60
                                            let seconds = durationSeconds % 60
                                            let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                                            Text("\(routineExercise.sets) sets × \(durationText) • \(routineExercise.restSeconds)s rest")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                        }
                                    }
                                    .textCase(nil)
                                }
                                .listRowBackground(Color.appSurface)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
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
                        .cornerRadius(10)
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
        .padding()
        .background(Color.appSurface.opacity(0.95))
        .overlay(
            Rectangle()
                .fill(Color.appAccent)
                .frame(height: 3),
            alignment: .bottom
        )
    }
    
    func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct OfflineExerciseSetSection: View {
    @ObservedObject var viewModel: OfflineActiveWorkoutViewModel
    let routineExercise: RoutineExercise
    let exercise: Exercise
    
    var sets: [LocalWorkoutSet] {
        viewModel.sets.filter { $0.exerciseId == exercise.id }
    }
    
    var body: some View {
        ForEach(sets) { set in
            OfflineExerciseSetRow(
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

struct OfflineExerciseSetRow: View {
    @ObservedObject var viewModel: OfflineActiveWorkoutViewModel
    let set: LocalWorkoutSet
    let exercise: Exercise
    let routineExercise: RoutineExercise
    
    var body: some View {
        HStack(spacing: 16) {
            // Set number
            Text("\(set.setNumber)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appText)
                .frame(width: 30)
            
            if exercise.exerciseType == "strength" {
                // Display weight
                HStack(spacing: 4) {
                    Text("\(routineExercise.targetWeight ?? 0, specifier: "%.1f")")
                        .font(.body)
                        .foregroundStyle(Color.appText)
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
                .frame(width: 60, alignment: .leading)
                
                // Display reps
                HStack(spacing: 4) {
                    Text(routineExercise.repsTarget ?? "—")
                        .font(.body)
                        .foregroundStyle(Color.appText)
                    Text("reps")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
            } else {
                // Display duration for cardio
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
            
            Spacer()
            
            // Checkmark button
            Button {
                // Auto-fill with target values when completing
                let targetReps = routineExercise.repsTarget.flatMap { Int($0) }
                let targetWeight = routineExercise.targetWeight
                let targetDuration = routineExercise.durationSeconds
                
                viewModel.updateSet(
                    set: set,
                    reps: targetReps,
                    weight: targetWeight,
                    durationSeconds: targetDuration,
                    completed: !set.completed
                )
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.completed ? Color.green : Color.gray)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
        .opacity(set.completed ? 0.6 : 1.0)
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
                        get: { set.weight ?? 0 },
                        set: { newValue in
                            Task {
                                await viewModel.updateSet(
                                    id: set.id,
                                    reps: set.reps,
                                    weight: newValue,
                                    durationSeconds: nil,
                                    completed: set.completed
                                )
                            }
                        }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    
                    Text("kg")
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
