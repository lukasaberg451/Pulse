//
//  ActiveWorkoutView.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import SwiftUI
import WatchConnectivity

enum WorkoutAlertType {
    case cancel, finish
}

struct ActiveWorkoutView: View {
    let routine: Routine
    let routineExercises: [RoutineExercise]
    let exercises: [Exercise]
    let scheduledWorkoutId: UUID?
    
    @StateObject private var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) var dismiss
    @State private var alertType: WorkoutAlertType?
    
    init(routine: Routine, routineExercises: [RoutineExercise], exercises: [Exercise], scheduledWorkoutId: UUID? = nil) {
        self.routine = routine
        self.routineExercises = routineExercises
        self.exercises = exercises
        self.scheduledWorkoutId = scheduledWorkoutId
        _viewModel = StateObject(wrappedValue: ActiveWorkoutViewModel(
            routine: routine,
            routineExercises: routineExercises,
            scheduledWorkoutId: scheduledWorkoutId,
            exercises: exercises
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Workout Timer Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Workout Time")
                                .font(.caption)
                                .foregroundColor(.appText.opacity(0.7))
                            Text(viewModel.formatElapsedTime())
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                        }
                        
                        Spacer()
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
                                    ExerciseSetSection(
                                        viewModel: viewModel,
                                        routineExercise: routineExercise,
                                        exercise: exercise
                                    )
                                } header: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundColor(.appText)
                                        if let reps = routineExercise.repsTarget {
                                            Text("\(routineExercise.sets) sets × \(reps) reps • \(routineExercise.restSeconds)s rest")
                                                .font(.caption)
                                                .foregroundColor(.appText.opacity(0.6))
                                        } else if let durationSeconds = routineExercise.durationSeconds {
                                            // Format duration in minutes and seconds
                                            let minutes = durationSeconds / 60
                                            let seconds = durationSeconds % 60
                                            let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                                            Text("\(routineExercise.sets) sets × \(durationText) • \(routineExercise.restSeconds)s rest")
                                                .font(.caption)
                                                .foregroundColor(.appText.opacity(0.6))
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
            }
            .navigationTitle(routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        alertType = .cancel
                    }
                    .foregroundColor(.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        alertType = .finish
                    }
                    .foregroundColor(.appAccent)
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
                    Text("Are you sure you want to finish this workout?")
                }
            }
            .task {
                await viewModel.startWorkout()
            }
            .onAppear {
                print("=== WATCH CONNECTIVITY DEBUG ===")
                print("Watch reachable: \(WorkoutSyncManager.shared.isReachable)")
                print("WCSession supported: \(WCSession.isSupported())")
                if let session = WCSession.default as WCSession? {
                    print("WCSession state: \(session.activationState.rawValue)")
                    #if os(iOS)
                    print("WCSession isPaired: \(session.isPaired)")
                    print("WCSession isWatchAppInstalled: \(session.isWatchAppInstalled)")
                    #endif
                }
                print("===============================")
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
                    .foregroundColor(.appText.opacity(0.7))
                Text(formatTime(timeRemaining))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.appAccent)
            }
            
            Spacer()
            
            Button("Skip") {
                onSkip()
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.appAccent)
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
                .foregroundColor(.appAccent)
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
                .foregroundColor(.appText)
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
                        .foregroundColor(.appText.opacity(0.6))
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
                        .foregroundColor(.appText.opacity(0.6))
                    
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
                        .foregroundColor(.appText.opacity(0.6))
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
                    .foregroundColor(set.completed ? .green : .gray)
                    .font(.title2)
            }
        }
        .opacity(set.completed ? 0.6 : 1.0)
    }
}
