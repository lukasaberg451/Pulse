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
                        .foregroundStyle(Color.appText)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.appText)
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
                            Text(viewModel.routine.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Description,  if exists
                            if let description = viewModel.routine.description, !description.isEmpty {
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
                                .foregroundStyle(viewModel.routineExercises.isEmpty ? Color.appText.opacity(0.7) : Color.appText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(viewModel.routineExercises.isEmpty ? Color.appAccent.opacity(0.5) : Color.appAccent)
                                .cornerRadius(10)
                            }
                            .disabled(viewModel.routineExercises.isEmpty)
                            
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
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appSurface)
                                .cornerRadius(10)
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
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appSurface)
                                .cornerRadius(10)
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
                                        .foregroundStyle(Color.appText.opacity(0.3))
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundStyle(Color.appText)
                                        
                                        if let reps = routineExercise.repsTarget {
                                            Text("\(routineExercise.sets) sets × \(reps) reps")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                        } else if let durationSeconds = routineExercise.durationSeconds {
                                            let minutes = durationSeconds / 60
                                            let seconds = durationSeconds % 60
                                            let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                                            Text("\(routineExercise.sets) sets × \(durationText)")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                        }
                                        
                                        Text("\(routineExercise.restSeconds)s rest")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.6))
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
                                            .foregroundStyle(Color.appText.opacity(0.6))
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
            EditRoutineSheet(viewModel: viewModel, onSaved: {
            })
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
                routine: viewModel.routine,
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
    @ObservedObject var routineViewModel: RoutineDetailViewModel
    @StateObject private var viewModel = ExerciseListViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var selectedEquipment: String? = nil
    @State private var selectedMuscle: String? = nil
    @State private var showingConfigSheet = false
    @State private var selectedExercise: Exercise?
    
    // Search debounce
    @State private var searchTask: Task<Void, Never>?
    
    let equipmentOptions = [
        ("Barbell", "Barbell"),
        ("EZ Bar", "EZ Bar"),
        ("Dumbbell", "Dumbbell"),
        ("Machine", "Machine"),
        ("Cable", "Cable"),
        ("Bodyweight", "Bodyweight"),
        ("Bench", "Bench"),
        ("Bar", "Bar"),
        ("Box", "Box"),
        ("Battle Rope", "Battle Rope"),
        ("Sled", "Sled"),
        ("Medicine Ball", "Medicine Ball"),
        ("Kettlebell", "Kettlebell"),
        ("Treadmill", "Treadmill"),
        ("Rowing Machine", "Rowing Machine"),
        ("Air Bike", "Air Bike"),
        ("Bike", "Bike"),
        ("Stairmill", "Stairmill"),
        ("Elliptical", "Elliptical"),
        ("SkiErg", "SkiErg")
    ]
    
    let muscleOptions = [
        ("Quads", "Quads"),
        ("Hamstrings", "Hamstrings"),
        ("Glutes", "Glutes"),
        ("Back", "Back"),
        ("Upper Back", "Upper Back"),
        ("Lower Back", "Lower Back"),
        ("Calves", "Calves"),
        ("Chest", "Chest"),
        ("Triceps", "Triceps"),
        ("Shoulders", "Shoulders"),
        ("Biceps", "Biceps"),
        ("Traps", "Traps"),
        ("Forearms", "Forearms"),
        ("Core", "Core"),
        ("Adductors", "Adductors"),
        ("Obliques", "Obliques"),
        ("Full Body", "Full Body"),
        ("Cardio", "Cardio")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.appText.opacity(0.5))
                        TextField("Search exercises...", text: $searchText)
                            .foregroundStyle(Color.appText)
                            .onChange(of: searchText) { _, newValue in
                                // Debounce search
                                searchTask?.cancel()
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                                    if !Task.isCancelled {
                                        await viewModel.resetAndLoad(
                                            equipment: selectedEquipment,
                                            muscle: selectedMuscle,
                                            search: newValue
                                        )
                                    }
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.appText.opacity(0.5))
                            }
                        }
                    }
                    .padding()
                    .background(Color.appSurface)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Equipment filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: selectedEquipment == nil) {
                                selectedEquipment = nil
                                Task { await viewModel.resetAndLoad(equipment: nil, muscle: selectedMuscle, search: searchText) }
                            }

                            ForEach(equipmentOptions, id: \.0) { value, label in
                                FilterChip(title: label, isSelected: selectedEquipment == value) {
                                    selectedEquipment = selectedEquipment == value ? nil : value
                                    let newEquipment = selectedEquipment  // Capture AFTER update
                                    Task { await viewModel.resetAndLoad(equipment: newEquipment, muscle: selectedMuscle, search: searchText) }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    // Muscle filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All Muscles", isSelected: selectedMuscle == nil) {
                                selectedMuscle = nil
                                Task { await viewModel.resetAndLoad(equipment: selectedEquipment, muscle: nil, search: searchText) }
                            }

                            ForEach(muscleOptions, id: \.0) { value, label in
                                FilterChip(title: value.capitalized, isSelected: selectedMuscle == value) {
                                    selectedMuscle = selectedMuscle == value ? nil : value
                                    let newMuscle = selectedMuscle  // Capture AFTER update
                                    Task { await viewModel.resetAndLoad(equipment: selectedEquipment, muscle: newMuscle, search: searchText) }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    // Results count
                    HStack {
                        Text("\(viewModel.exercises.count) exercises")
                            .font(.caption)
                            .foregroundStyle(Color.appText.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    
                    // Exercise list
                    List {
                        ForEach(viewModel.exercises) { exercise in
                            Button {
                                selectedExercise = exercise
                                showingConfigSheet = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundStyle(Color.appText)
                                        
                                        HStack(spacing: 8) {
                                            if let equipment = exercise.equipment {
                                                Text(equipment.capitalized)
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Color.appAccent.opacity(0.2))
                                                    .foregroundStyle(Color.appAccent)
                                                    .cornerRadius(10)
                                            }
                                            
                                            if let muscle = exercise.muscleGroup {
                                                Text(muscle.capitalized)
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Color.appSurface)
                                                    .foregroundStyle(Color.appText.opacity(0.6))
                                                    .cornerRadius(10)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .listRowBackground(Color.appSurface)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .task {
                                // Load more when reaching end of list
                                await viewModel.loadMoreIfNeeded(currentExercise: exercise)
                            }
                        }
                        
                        // Loading more indicator
                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    Color.appBackground.opacity(0.8)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
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
            .sheet(isPresented: $showingConfigSheet) {
                if let exercise = selectedExercise {
                    ExerciseConfigSheet(
                        exercise: exercise,
                        viewModel: routineViewModel
                    )
                }
            }
            .task {
                await viewModel.resetAndLoad()
            }
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appAccent : Color.appSurface)
                .foregroundStyle(isSelected ? Color.white : Color.appText)
                .cornerRadius(10)
        }
    }
}

struct ExerciseConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    let exercise: Exercise
    @ObservedObject var viewModel: RoutineDetailViewModel
    
    @State private var sets = 3
    @State private var repsTarget = "10"
    @State private var targetWeight = "0"
    @State private var durationMinutes = 5
    @State private var durationSeconds = 0
    @State private var restSeconds = 60
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Exercise").foregroundStyle(Color.appText)) {
                        Text(exercise.name)
                            .foregroundStyle(Color.appText)
                        if let muscle = exercise.exerciseType {
                            Text(muscle)
                                .font(.caption)
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .listRowBackground(Color.appSurface)
                    
                    Section(header: Text("Configuration").foregroundStyle(Color.appText)) {
                        Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                            .foregroundStyle(Color.appText)
                        
                        if exercise.exerciseType == "strength" {
                            // Reps
                            HStack {
                                Text("Reps")
                                    .foregroundStyle(Color.appText)
                                Spacer()
                                TextField("", text: $repsTarget)
                                    .foregroundStyle(Color.appText)
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
                                    .foregroundStyle(Color.appText)
                                Spacer()
                                TextField("0", text: $targetWeight)
                                    .foregroundStyle(Color.appText)
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
                                    .foregroundStyle(Color.appText)
                                Spacer()
                                Picker("Minutes", selection: $durationMinutes) {
                                    ForEach(0..<61) { mins in
                                        Text("\(mins)").tag(mins)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60)
                                Text("min")
                                    .foregroundStyle(Color.appText)
                                
                                Picker("Seconds", selection: $durationSeconds) {
                                    ForEach(0..<60) { secs in
                                        Text("\(secs)").tag(secs)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60)
                                Text("sec")
                                    .foregroundStyle(Color.appText)
                            }
                        }
                        
                        Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...300, step: 15)
                            .foregroundStyle(Color.appText)
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
                    .foregroundStyle(Color.appText)
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
                    .foregroundStyle(Color.appAccent)
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
    let onSaved: () -> Void
        
    init(viewModel: RoutineDetailViewModel, onSaved: @escaping () -> Void) {
            self.viewModel = viewModel
            self.onSaved = onSaved
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
                    .foregroundStyle(Color.appText)
                }
                    
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.updateRoutine(name: name, description: description)
                            onSaved()
                            dismiss()
                            }
                        }
                    .foregroundStyle(Color.appAccent)
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
                    Section(header: Text("Exercise").foregroundStyle(Color.appText)) {
                        Text(exercise.name)
                            .foregroundStyle(Color.appText)
                        if let muscle = exercise.exerciseType {
                            Text(muscle)
                                .font(.caption)
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .listRowBackground(Color.appSurface)
                    
                    Section(header: Text("Configuration").foregroundStyle(Color.appText)) {
                        Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                            .foregroundStyle(Color.appText)
                        
                        if exercise.exerciseType == "strength" {
                            HStack {
                                Text("Reps")
                                    .foregroundStyle(Color.appText)
                                Spacer()
                                TextField("", text: $repsTarget)
                                    .foregroundStyle(Color.appText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .padding(8)
                                    .background(Color.appBackground)
                                    .cornerRadius(10)
                            }
                            
                            HStack {
                                Text("Weight (kg)")
                                    .foregroundStyle(Color.appText)
                                Spacer()
                                TextField("0", text: $targetWeight)
                                    .foregroundStyle(Color.appText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .padding(8)
                                    .background(Color.appBackground)
                                    .cornerRadius(10)
                            }
                        } else {
                            HStack {
                                Text("Duration")
                                    .foregroundStyle(Color.appText)
                                Spacer()
                                Picker("Minutes", selection: $durationMinutes) {
                                    ForEach(0..<61) { mins in
                                        Text("\(mins)").tag(mins)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60)
                                Text("min")
                                    .foregroundStyle(Color.appText)
                                
                                Picker("Seconds", selection: $durationSeconds) {
                                    ForEach(0..<60) { secs in
                                        Text("\(secs)").tag(secs)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60)
                                Text("sec")
                                    .foregroundStyle(Color.appText)
                            }
                        }
                        
                        Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...300, step: 15)
                            .foregroundStyle(Color.appText)
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
                    .foregroundStyle(Color.appText)
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
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
    }
}
