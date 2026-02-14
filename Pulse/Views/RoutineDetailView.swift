//
//  RoutineDetailView.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import SwiftUI

struct RoutineDetailView: View {
    let routine: Routine
    @StateObject private var viewModel: RoutineDetailViewModel
    @State private var showingExercisePicker = false
    @State private var showingActiveWorkout = false
    @State private var showingEditSheet = false
    @State private var isEditMode = false
    
    init(routine: Routine) {
        self.routine = routine
        _viewModel = StateObject(wrappedValue: RoutineDetailViewModel(routine: routine))
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading routine...")
                        .foregroundColor(.appText)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.appText)
                        Text(error)
                            .foregroundColor(.appText.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.loadRoutineExercises() }
                        }
                        .foregroundColor(.appAccent)
                    }
                    .padding()
                } else if viewModel.routineExercises.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 60))
                            .foregroundColor(.appText.opacity(0.6))
                        Text("No Exercises Yet")
                            .font(.headline)
                            .foregroundColor(.appText)
                        Text("Add exercises to build your routine")
                            .foregroundColor(.appText.opacity(0.7))
                        Button("Add Exercise") {
                            showingExercisePicker = true
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .cornerRadius(10)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Edit button header
                        HStack {
                            Spacer()
                            Button {
                                withAnimation {
                                    isEditMode.toggle()
                                }
                            } label: {
                                Text(isEditMode ? "Done" : "Edit")
                                    .foregroundColor(.appAccent)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        
                        List {
                            ForEach(viewModel.routineExercises) { routineExercise in
                                if let exercise = viewModel.getExercise(for: routineExercise) {
                                    HStack(spacing: 12) {
                                        // Delete button in edit mode
                                        if isEditMode {
                                            Button {
                                                Task {
                                                    await viewModel.deleteExercise(routineExercise)
                                                    
                                                    // Exit edit mode if no exercises remain
                                                    if viewModel.routineExercises.isEmpty {
                                                        withAnimation {
                                                            isEditMode = false
                                                        }
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.title2)
                                                    .foregroundColor(.red)
                                            }
                                            .transition(.scale.combined(with: .opacity))
                                        }
                                        
                                        if isEditMode {
                                            // Non-tappable view in edit mode
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(exercise.name)
                                                    .font(.headline)
                                                    .foregroundColor(.appText)
                                                
                                                HStack(spacing: 16) {
                                                    Label("\(routineExercise.sets) sets", systemImage: "repeat")
                                                        .font(.caption)
                                                        .foregroundColor(.appText.opacity(0.6))
                                                    
                                                    if let reps = routineExercise.repsTarget {
                                                        Label("\(reps) reps", systemImage: "number")
                                                            .font(.caption)
                                                            .foregroundColor(.appText.opacity(0.6))
                                                    }
                                                    
                                                    Label("\(routineExercise.restSeconds)s rest", systemImage: "timer")
                                                        .font(.caption)
                                                        .foregroundColor(.appText.opacity(0.6))
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        } else {
                                            // NavigationLink in normal mode
                                            NavigationLink {
                                                EditRoutineExerciseView(
                                                    viewModel: viewModel,
                                                    routineExercise: routineExercise,
                                                    exercise: exercise
                                                )
                                            } label: {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text(exercise.name)
                                                        .font(.headline)
                                                        .foregroundColor(.appText)
                                                    
                                                    HStack(spacing: 16) {
                                                        Label("\(routineExercise.sets) sets", systemImage: "repeat")
                                                            .font(.caption)
                                                            .foregroundColor(.appText.opacity(0.6))
                                                        
                                                        if let reps = routineExercise.repsTarget {
                                                            Label("\(reps) reps", systemImage: "number")
                                                                .font(.caption)
                                                                .foregroundColor(.appText.opacity(0.6))
                                                        }
                                                        
                                                        Label("\(routineExercise.restSeconds)s rest", systemImage: "timer")
                                                            .font(.caption)
                                                            .foregroundColor(.appText.opacity(0.6))
                                                    }
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                    .listRowBackground(Color.appSurface)
                                    .animation(.spring(response: 0.3), value: isEditMode)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingActiveWorkout = true
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .foregroundColor(.appAccent)
                }
                .disabled(viewModel.routineExercises.isEmpty)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Routine", systemImage: "pencil")
                    }
                    
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.appAccent)
                }
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(routineViewModel : viewModel)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRoutineSheet(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(
                routine: routine,
                routineExercises: viewModel.routineExercises,
                exercises: viewModel.exercises
            )
        }
        .task {
            await viewModel.loadRoutineExercises()
            await viewModel.loadExercises()
        }
    }
}

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let routineViewModel: RoutineDetailViewModel
    @StateObject private var exerciseViewModel = ExerciseListViewModel()
    @State private var selectedExercises: Exercise?
    @State private var showingConfigSheet = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                Group {
                    if routineViewModel.isLoading {
                        ProgressView("Loading exercises...")
                            .foregroundStyle(Color.appText)
                    } else if let error = routineViewModel.errorMessage {
                        VStack {
                            Text("Error")
                                .font(.headline)
                                .foregroundStyle(Color.appText)
                            Text(error)
                                .foregroundStyle(Color.appText.opacity(0.7))
                            Button("Retry") {
                                Task { await routineViewModel.loadRoutineExercises() }
                            }
                            .foregroundStyle(Color.appAccent)
                        }
                    } else {
                        List(filteredExercises) { exercise in
                            Button {
                                selectedExercises = exercise
                                showingConfigSheet = true
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.headline)
                                        .foregroundStyle(Color.appText)
                                    Text(exercise.muscleGroup)
                                        .font(.caption)
                                        .foregroundStyle(Color.appText.opacity(0.6))
                                }
                            }
                            .listRowBackground(Color.appSurface)
                        }
                        .searchable(text: $searchText, prompt: "Search exercises")
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
            }
            .sheet(item: $selectedExercises) { exercise in
                ExerciseConfigSheet(
                    exercise: exercise,
                    viewModel: routineViewModel
                )
            }
            .task {
                await exerciseViewModel.loadExercises()
            }
        }
    }
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exerciseViewModel.excercises
        } else {
            return exerciseViewModel.excercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscleGroup.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct ExerciseConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    let exercise: Exercise
    @ObservedObject var viewModel: RoutineDetailViewModel
    
    @State private var sets = 3
    @State private var repsTarget = "10"
    @State private var targetWeight = "0"  // Add this
    @State private var durationMinutes = 5
    @State private var durationSeconds = 0
    @State private var restSeconds = 60
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Exercise").foregroundColor(.appText)) {
                        Text(exercise.name)
                            .foregroundColor(.appText)
                        Text(exercise.exerciseType.capitalized)
                            .font(.caption)
                            .foregroundColor(.appAccent)
                    }
                    .listRowBackground(Color.appSurface)
                    
                    Section(header: Text("Configuration").foregroundColor(.appText)) {
                        Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                            .foregroundColor(.appText)
                        
                        if exercise.exerciseType == "strength" {
                            // Reps
                            HStack {
                                Text("Reps")
                                    .foregroundColor(.appText)
                                Spacer()
                                TextField("", text: $repsTarget)
                                    .foregroundColor(.appText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .padding(8)
                                    .background(Color.appBackground)
                                    .cornerRadius(6)
                            }
                            
                            // Weight
                            HStack {
                                Text("Weight (kg)")
                                    .foregroundColor(.appText)
                                Spacer()
                                TextField("0", text: $targetWeight)
                                    .foregroundColor(.appText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .padding(8)
                                    .background(Color.appBackground)
                                    .cornerRadius(6)
                            }
                        } else {
                            // Cardio: Duration picker
                            HStack {
                                Text("Duration")
                                    .foregroundColor(.appText)
                                Spacer()
                                Picker("Minutes", selection: $durationMinutes) {
                                    ForEach(0..<61) { mins in
                                        Text("\(mins)").tag(mins)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60)
                                Text("min")
                                    .foregroundColor(.appText)
                                
                                Picker("Seconds", selection: $durationSeconds) {
                                    ForEach(0..<60) { secs in
                                        Text("\(secs)").tag(secs)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60)
                                Text("sec")
                                    .foregroundColor(.appText)
                            }
                        }
                        
                        Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...300, step: 15)
                            .foregroundColor(.appText)
                    }
                    .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Configure Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            if exercise.exerciseType == "strength" {
                                let weight = Double(targetWeight) ?? 0
                                await viewModel.addExercise(
                                    exerciseId: exercise.id,
                                    sets: sets,
                                    repsTarget: repsTarget,
                                    targetWeight: weight,
                                    durationSeconds: nil,
                                    restSeconds: restSeconds
                                )
                            } else {
                                let totalSeconds = (durationMinutes * 60) + durationSeconds
                                await viewModel.addExercise(
                                    exerciseId: exercise.id,
                                    sets: sets,
                                    repsTarget: nil,
                                    targetWeight: nil,
                                    durationSeconds: totalSeconds,
                                    restSeconds: restSeconds
                                )
                            }
                            dismiss()
                        }
                    }
                    .foregroundColor(.appAccent)
                }
            }
        }
    }
}

struct EditRoutineExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: RoutineDetailViewModel
    
    let routineExercise: RoutineExercise
    let exercise: Exercise
    
    @State private var sets: Int
    @State private var repsTarget: String
    @State private var restSeconds: Int
    
    init(viewModel: RoutineDetailViewModel, routineExercise: RoutineExercise, exercise: Exercise) {
        self.viewModel = viewModel
        self.routineExercise = routineExercise
        self.exercise = exercise
        
        // Initialize state from existing values
        _sets = State(initialValue: routineExercise.sets)
        _repsTarget = State(initialValue: routineExercise.repsTarget ?? "")
        _restSeconds = State(initialValue: routineExercise.restSeconds)
    }
    
    var body: some View {
        Form {
            Section("Exercise") {
                Text(exercise.name)
                    .font(.headline)
                Text(exercise.muscleGroup)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Section("Configuration") {
                Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                
                TextField("Reps (e.g., 10 or 8-12)", text: $repsTarget)
                
                Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...300, step: 15)
            }
            
            Section {
                Button("Delete Exercise", role: .destructive) {
                    Task {
                        await viewModel.deleteExercise(routineExercise)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.updateExercise(
                            routineExercise: routineExercise,
                            sets: sets,
                            repsTarget: repsTarget,
                            restSeconds: restSeconds
                        )
                        dismiss()
                    }
                }
                .disabled(repsTarget.isEmpty)
            }
        }
    }
}

struct EditRoutineSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: RoutineDetailViewModel
        
    @State private var name: String
    @State private var description: String
        
    init(viewModel: RoutineDetailViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.routine.name)
        _description = State(initialValue: viewModel.routine.description ?? "")
    }
        
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Routine Name")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("", text: $name)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("Optional", text: $description, axis: .vertical)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(8)
                            .lineLimit(3...6)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appText)
                }
                    
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.updateRoutineName(
                                name: name,
                                description: description.isEmpty ? nil : description
                            )
                            dismiss()
                        }
                    }
                    .foregroundColor(.appAccent)
                    .disabled(name.isEmpty)
                    }
                }
            }
        }
    }
