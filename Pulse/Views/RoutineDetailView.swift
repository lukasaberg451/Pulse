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
    @State private var editingExercise: RoutineExercise?
    
    init(routine: Routine) {
        self.routine = routine
        _viewModel = StateObject(wrappedValue: RoutineDetailViewModel(routine: routine))
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                VStack {
                    Text("Error")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                    Button("Retry") {
                        Task {
                            await viewModel.loadRoutineExercises()
                            await viewModel.loadExercises()
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    // Fixed header
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(routine.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.appText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Description,  if exists
                            if let description = routine.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appText.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            // Start Workout
                            Button {
                                showingActiveWorkout = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.title2)
                                    Text("Start")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appAccent)
                                .cornerRadius(8)
                            }
                            
                            // Edit Routine
                            Button {
                                showingEditSheet = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.title2)
                                    Text("Edit")
                                        .font(.caption)
                                }
                                .foregroundColor(.appText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appSurface)
                                .cornerRadius(8)
                            }
                            
                            // Add Exercise
                            Button {
                                showingExercisePicker = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                    Text("Add")
                                        .font(.caption)
                                }
                                .foregroundColor(.appText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appSurface)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color.appBackground)
                    
                    // Exercises list
                    List {
                        ForEach(viewModel.routineExercises) { routineExercise in
                            if let exercise = viewModel.exercises.first(where: { $0.id == routineExercise.exerciseId }) {
                                HStack(spacing: 12) {
                                    // Drag handle
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.appText.opacity(0.3))
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundColor(.appText)
                                        
                                        if let reps = routineExercise.repsTarget {
                                            Text("\(routineExercise.sets) sets × \(reps) reps")
                                                .font(.caption)
                                                .foregroundColor(.appText.opacity(0.6))
                                        } else if let durationSeconds = routineExercise.durationSeconds {
                                            let minutes = durationSeconds / 60
                                            let seconds = durationSeconds % 60
                                            let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                                            Text("\(routineExercise.sets) sets × \(durationText)")
                                                .font(.caption)
                                                .foregroundColor(.appText.opacity(0.6))
                                        }
                                        
                                        Text("\(routineExercise.restSeconds)s rest")
                                            .font(.caption)
                                            .foregroundColor(.appText.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    // Three-dot menu
                                    Menu {
                                        Button {
                                            editingExercise = routineExercise
                                        } label: {
                                            Label("Edit Exercise", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteExercise(routineExercise)
                                            }
                                        } label: {
                                            Label("Delete Exercise", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.title3)
                                            .foregroundColor(.appText.opacity(0.6))
                                            .frame(width: 44, height: 44)
                                    }
                                }
                                .padding()
                                .background(Color.appSurface)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                            }
                        }
                        .onMove { source, destination in
                            Task {
                                await viewModel.moveExercise(from: source, to: destination)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(routineViewModel: viewModel)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRoutineSheet(viewModel: viewModel)
        }
        .sheet(item: $editingExercise) { routineExercise in
            if let exercise = viewModel.exercises.first(where: { $0.id == routineExercise.exerciseId }) {
                EditExerciseSheet(
                    routineExercise: routineExercise,
                    exercise: exercise,
                    viewModel: viewModel
                )
            }
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
                                    .cornerRadius(10)
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
                                    .cornerRadius(10)
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
                            .cornerRadius(10)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("", text: $description, axis: .vertical)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
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

struct EditExerciseSheet: View {
    @Environment(\.dismiss) var dismiss
    let routineExercise: RoutineExercise
    let exercise: Exercise
    @ObservedObject var viewModel: RoutineDetailViewModel
    
    @State private var sets: Int
    @State private var repsTarget: String
    @State private var targetWeight: String
    @State private var durationMinutes: Int
    @State private var durationSeconds: Int
    @State private var restSeconds: Int
    
    init(routineExercise: RoutineExercise, exercise: Exercise, viewModel: RoutineDetailViewModel) {
        self.routineExercise = routineExercise
        self.exercise = exercise
        self.viewModel = viewModel
        
        _sets = State(initialValue: routineExercise.sets)
        _repsTarget = State(initialValue: routineExercise.repsTarget ?? "")
        _targetWeight = State(initialValue: String(routineExercise.targetWeight ?? 0))
        _restSeconds = State(initialValue: routineExercise.restSeconds)
        
        let totalSeconds = routineExercise.durationSeconds ?? 0
        _durationMinutes = State(initialValue: totalSeconds / 60)
        _durationSeconds = State(initialValue: totalSeconds % 60)
    }
    
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
            .navigationTitle("Edit Exercise")
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
                            if exercise.exerciseType == "strength" {
                                let weight = Double(targetWeight) ?? 0
                                await viewModel.updateExercise(
                                    id: routineExercise.id,
                                    sets: sets,
                                    repsTarget: repsTarget,
                                    targetWeight: weight,
                                    durationSeconds: nil,
                                    restSeconds: restSeconds
                                )
                            } else {
                                let totalSeconds = (durationMinutes * 60) + durationSeconds
                                await viewModel.updateExercise(
                                    id: routineExercise.id,
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
