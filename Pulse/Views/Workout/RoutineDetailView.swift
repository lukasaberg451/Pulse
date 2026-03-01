//
//  RoutineDetailView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import SwiftUI

struct RoutineDetailView: View {
    let routine: Routine
    @StateObject private var viewModel: RoutineDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showingExercisePicker = false
    @State private var showingActiveWorkout = false
    @State private var showingEditSheet = false
    @State private var editingExercise: RoutineExercise?
    @State private var editMode: EditMode = .inactive
    @State private var reorderedExercises: [RoutineExercise] = []
    
    init(routine: Routine) {
        self.routine = routine
        _viewModel = StateObject(wrappedValue: RoutineDetailViewModel(routine: routine))
    }
    
    // Helper function to cancel edit mode
    private func cancelEditMode() {
        if editMode == .active {
            withAnimation {
                editMode = .inactive
                reorderedExercises = []
            }
        }
    }
    
    // Helper function to handle moving items
    private func moveItems(from source: IndexSet, to destination: Int) {
        reorderedExercises.move(fromOffsets: source, toOffset: destination)
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
                                cancelEditMode()
                                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                                impactMed.impactOccurred()
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
                                cancelEditMode()
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
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
                                cancelEditMode()
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
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
                    
                    // Edit Order button (only show if there are exercises)
                    if !viewModel.routineExercises.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                if editMode == .active {
                                    // Save the reordered exercises when done
                                    let notificationFeedback = UINotificationFeedbackGenerator()
                                    notificationFeedback.notificationOccurred(.success)
                                    Task {
                                        await viewModel.saveExerciseOrder(reorderedExercises)
                                        // Exit edit mode after save completes
                                        withAnimation {
                                            editMode = .inactive
                                            reorderedExercises = []
                                        }
                                    }
                                } else {
                                    // Initialize reordered exercises when entering edit mode
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    withAnimation {
                                        reorderedExercises = viewModel.routineExercises
                                        editMode = .active
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: editMode == .active ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                                        .font(.subheadline)
                                    Text(editMode == .active ? "Done" : "Reorder Exercises")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(editMode == .active ? Color.green : Color.appAccent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(editMode == .active ? Color.green.opacity(0.1) : Color.appAccent.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.appBackground)
                    }
                    
                    // Exercises list
                    List {
                        ForEach(editMode == .active ? reorderedExercises : viewModel.routineExercises) { routineExercise in
                            if let exercise = viewModel.exercises.first(where: { $0.id == routineExercise.exerciseId }) {
                                HStack(spacing: 12) {
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
                                        
                                        // Always show rest line to maintain consistent card height
                                        if routineExercise.restSeconds > 0 {
                                            Text("\(routineExercise.restSeconds)s rest")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                        } else {
                                            Text(" ")
                                                .font(.caption)
                                                .foregroundStyle(Color.clear)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Three-dot menu - hide in edit mode
                                    if editMode != .active {
                                        Menu {
                                            Button {
                                                editingExercise = routineExercise
                                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                                impactLight.impactOccurred()
                                            } label: {
                                                Label("Edit Exercise", systemImage: "pencil")
                                            }
                                            
                                            Button(role: .destructive) {
                                                let notificationFeedback = UINotificationFeedbackGenerator()
                                                notificationFeedback.notificationOccurred(.warning)
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
                                }
                                .padding()
                                .background(Color.appSurface)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(editMode == .active ? Color.appAccent.opacity(0.3) : Color.clear, lineWidth: 2)
                                )
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                            }
                        }
                        .onMove { source, destination in
                            if editMode == .active {
                                moveItems(from: source, to: destination)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                    .environment(\.editMode, $editMode)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .sheet(isPresented: $showingExercisePicker, onDismiss: {
            Task {
                await viewModel.loadRoutineExercises(forceRefresh: true)
            }
        }) {
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
                exercises: viewModel.exercises,
                scheduledWorkoutId: nil,
                workoutSessionId: nil
            )
        }
        .task {
            // Inject modelContext for offline support
            viewModel.modelContext = modelContext
            
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
    @State private var selectedMuscle: String? = nil
    @State private var selectedEquipment: String? = nil
    @State private var showingFilterSheet = false
    @State private var showingConfigSheet = false
    @State private var selectedExercise: Exercise?
    
    // Search debounce
    @State private var searchTask: Task<Void, Never>?
    
    let muscleOptions = [
        "Back", "Biceps", "Calves", "Cardio", "Chest", "Core",
        "Forearms", "Full Body", "Glutes", "Hamstrings",
        "Upper Back", "Lower Back", "Quads", "Shoulders", "Traps", "Triceps"
    ]
    
    let equipmentOptions = [
        "Barbell", "Bike", "Bodyweight", "Cable", "Dumbbell",
        "Kettlebell", "Machine", "Medicine Ball", "Resistance Band",
        "Sandbag", "Sled", "Smith Machine", "Treadmill", "TRX"
    ]
    
    var filteredExercises: [Exercise] {
        // Filtering is now handled server-side via resetAndLoad()
        return viewModel.exercises
    }
    
    var activeFilterCount: Int {
        var count = 0
        if selectedMuscle != nil { count += 1 }
        if selectedEquipment != nil { count += 1 }
        return count
    }
    
    private func applyFilters() {
        Task {
            await viewModel.resetAndLoad(
                equipment: selectedEquipment,
                muscle: selectedMuscle,
                search: searchText
            )
        }
    }
    
    private func equipmentIcon(for equipment: String) -> String {
        switch equipment.lowercased() {
        case "barbell":
            return "dumbbell.fill"
        case "dumbbell":
            return "dumbbell.fill"
        case "kettlebell":
            return "figure.cooldown"
        case "cable":
            return "cable.connector"
        case "machine":
            return "gearshape.fill"
        case "bodyweight":
            return "figure.arms.open"
        case "resistance band":
            return "arrow.left.and.right.circle"
        case "medicine ball":
            return "sportscourt.fill"
        case "bike":
            return "bicycle"
        case "treadmill":
            return "figure.run"
        case "trx":
            return "triangle.fill"
        case "smith machine":
            return "square.stack.3d.up.fill"
        case "sled":
            return "arrow.forward.circle.fill"
        case "sandbag":
            return "bag.fill"
        default:
            return "dumbbell.fill"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar with filter button
                    HStack(spacing: 12) {
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.appText.opacity(0.5))
                            TextField("Search exercises...", text: $searchText)
                                .foregroundStyle(Color.appText)
                                .onChange(of: searchText) { _, newValue in
                                    searchTask?.cancel()
                                    searchTask = Task {
                                        try? await Task.sleep(nanoseconds: 300_000_000)
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
                        
                        // Filter button
                        Button {
                            showingFilterSheet = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.title2)
                                    .foregroundStyle(activeFilterCount > 0 ? Color.appAccent : Color.appText)
                                
                                if activeFilterCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Text("\(activeFilterCount)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Color.white)
                                        )
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    // Active filters display
                    if activeFilterCount > 0 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if let muscle = selectedMuscle {
                                    ActiveFilterChip(title: muscle, icon: "figure.arms.open") {
                                        selectedMuscle = nil
                                    }
                                }
                                
                                if let equipment = selectedEquipment {
                                    ActiveFilterChip(title: equipment, icon: "dumbbell.fill") {
                                        selectedEquipment = nil
                                    }
                                }
                                
                                Button {
                                    selectedMuscle = nil
                                    selectedEquipment = nil
                                } label: {
                                    Text("Clear all")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                    
                    // Results count
                    HStack {
                        Text("\(filteredExercises.count) exercises")
                            .font(.caption)
                            .foregroundStyle(Color.appText.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Exercise list
                    if filteredExercises.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.appText.opacity(0.3))
                            
                            Text("No exercises found")
                                .font(.headline)
                                .foregroundStyle(Color.appText)
                            
                            Text("Try adjusting your filters")
                                .font(.caption)
                                .foregroundStyle(Color.appText.opacity(0.6))
                        }
                        .frame(maxHeight: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredExercises) { exercise in
                                    Button {
                                        selectedExercise = exercise
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        showingConfigSheet = true
                                    } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(exercise.name)
                                                    .font(.headline)
                                                    .foregroundStyle(Color.appText)
                                                
                                                HStack(spacing: 8) {
                                                    if let muscle = exercise.muscleGroup {
                                                        Label(muscle.capitalized, systemImage: "figure.arms.open")
                                                            .font(.caption)
                                                            .foregroundStyle(Color.appText.opacity(0.6))
                                                    }
                                                    
                                                    if let equipment = exercise.equipment {
                                                        Label(equipment.capitalized, systemImage: equipmentIcon(for: equipment))
                                                            .font(.caption)
                                                            .foregroundStyle(Color.appAccent.opacity(0.8))
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color.appAccent)
                                        }
                                        .padding()
                                        .background(Color.appSurface)
                                        .cornerRadius(10)
                                    }
                                    .task {
                                        await viewModel.loadMoreIfNeeded(currentExercise: exercise)
                                    }
                                }
                                
                                if viewModel.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
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
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    selectedMuscle: $selectedMuscle,
                    selectedEquipment: $selectedEquipment,
                    muscleOptions: muscleOptions,
                    equipmentOptions: equipmentOptions
                )
            }
            .onChange(of: selectedMuscle) { _, _ in
                applyFilters()
            }
            .onChange(of: selectedEquipment) { _, _ in
                applyFilters()
            }
            .task {
                await viewModel.resetAndLoad()
            }
        }
        .presentationBackground(Color.appBackground)
    }
}

// MARK: - Active Filter Chip
struct ActiveFilterChip: View {
    let title: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.appAccent)
        .cornerRadius(10)
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedMuscle: String?
    @Binding var selectedEquipment: String?
    let muscleOptions: [String]
    let equipmentOptions: [String]
    
    @State private var tempMuscle: String?
    @State private var tempEquipment: String?
    
    init(selectedMuscle: Binding<String?>, selectedEquipment: Binding<String?>, muscleOptions: [String], equipmentOptions: [String]) {
        _selectedMuscle = selectedMuscle
        _selectedEquipment = selectedEquipment
        self.muscleOptions = muscleOptions
        self.equipmentOptions = equipmentOptions
        _tempMuscle = State(initialValue: selectedMuscle.wrappedValue)
        _tempEquipment = State(initialValue: selectedEquipment.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Muscle Group Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("Muscle Group", systemImage: "figure.arms.open")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                if tempMuscle != nil {
                                    Button("Clear") {
                                        tempMuscle = nil
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appAccent)
                                }
                            }
                            
                            // Muscle options in flowing layout
                            FlowLayout(spacing: 8) {
                                ForEach(muscleOptions, id: \.self) { muscle in
                                    Button {
                                        tempMuscle = tempMuscle == muscle ? nil : muscle
                                    } label: {
                                        Text(muscle)
                                            .font(.subheadline)
                                            .foregroundStyle(tempMuscle == muscle ? Color.white : Color.appText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(tempMuscle == muscle ? Color.appAccent : Color.appSurface)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.appSurface.opacity(0.3))
                        .cornerRadius(10)
                        
                        // Equipment Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("Equipment", systemImage: "dumbbell.fill")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                if tempEquipment != nil {
                                    Button("Clear") {
                                        tempEquipment = nil
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appAccent)
                                }
                            }
                            
                            // Equipment options in flowing layout
                            FlowLayout(spacing: 8) {
                                ForEach(equipmentOptions, id: \.self) { equipment in
                                    Button {
                                        tempEquipment = tempEquipment == equipment ? nil : equipment
                                    } label: {
                                        Text(equipment)
                                            .font(.subheadline)
                                            .foregroundStyle(tempEquipment == equipment ? Color.white : Color.appText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(tempEquipment == equipment ? Color.appAccent : Color.appSurface)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.appSurface.opacity(0.3))
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        selectedMuscle = tempMuscle
                        selectedEquipment = tempEquipment
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Muscle Pill
struct MusclePill: View {
    let muscle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(muscle)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.appAccent : Color.appSurface)
                .foregroundStyle(isSelected ? Color.white : Color.appText)
                .cornerRadius(10)
        }
    }
}

// MARK: - Filter Chip (Legacy - kept for other parts of app if needed)
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
    
    // Cardio-specific
    @State private var cardioMode: CardioMode = .continuous
    
    enum CardioMode: String, CaseIterable {
        case continuous = "Continuous"
        case intervals = "Intervals"
    }
    
    var isCardio: Bool {
        exercise.exerciseType == "cardio"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Exercise Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exercise")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appText.opacity(0.6))
                                .textCase(.uppercase)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.appText)
                                
                                if let muscle = exercise.muscleGroup {
                                    Text(muscle.capitalized)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(10)
                        }
                        
                        // Configuration Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Configuration")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appText.opacity(0.6))
                                .textCase(.uppercase)
                            
                            VStack(spacing: 12) {
                                if isCardio {
                                    // Cardio mode picker
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Mode")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.appText)
                                        
                                        Picker("Mode", selection: $cardioMode) {
                                            ForEach(CardioMode.allCases, id: \.self) { mode in
                                                Text(mode.rawValue).tag(mode)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                    .padding()
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Only show intervals count if in interval mode
                                    if cardioMode == .intervals {
                                        VStack(spacing: 0) {
                                            HStack {
                                                Text("Intervals")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(Color.appText)
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 12) {
                                                    Button {
                                                        if sets > 1 {
                                                            sets -= 1
                                                        }
                                                    } label: {
                                                        Image(systemName: "minus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundStyle(sets > 1 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(sets <= 1)
                                                    
                                                    Text("\(sets)")
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(Color.appText)
                                                        .frame(minWidth: 40)
                                                    
                                                    Button {
                                                        if sets < 20 {
                                                            sets += 1
                                                        }
                                                    } label: {
                                                        Image(systemName: "plus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundStyle(sets < 20 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(sets >= 20)
                                                }
                                            }
                                            .padding()
                                        }
                                        .background(Color.appSurface)
                                        .cornerRadius(10)
                                    }
                                    
                                    // Duration picker
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(cardioMode == .intervals ? "Duration (per interval)" : "Duration")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.appText)
                                        
                                        HStack(spacing: 16) {
                                            Picker("Minutes", selection: $durationMinutes) {
                                                ForEach(0..<61) { mins in
                                                    Text("\(mins)").tag(mins)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            
                                            Text("min")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                            
                                            Picker("Seconds", selection: $durationSeconds) {
                                                ForEach(0..<60) { secs in
                                                    Text("\(secs)").tag(secs)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            
                                            Text("sec")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                        }
                                        .frame(height: 120)
                                    }
                                    .padding()
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Only show rest for intervals
                                    if cardioMode == .intervals {
                                        VStack(spacing: 0) {
                                            HStack {
                                                Text("Rest Between Intervals")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(Color.appText)
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 12) {
                                                    Button {
                                                        if restSeconds > 0 {
                                                            restSeconds -= 15
                                                        }
                                                    } label: {
                                                        Image(systemName: "minus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundStyle(restSeconds > 0 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(restSeconds <= 0)
                                                    
                                                    Text("\(restSeconds)s")
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(Color.appText)
                                                        .frame(minWidth: 60)
                                                    
                                                    Button {
                                                        if restSeconds < 300 {
                                                            restSeconds += 15
                                                        }
                                                    } label: {
                                                        Image(systemName: "plus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundStyle(restSeconds < 300 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(restSeconds >= 300)
                                                }
                                            }
                                            .padding()
                                        }
                                        .background(Color.appSurface)
                                        .cornerRadius(10)
                                    }
                                } else {
                                    // Strength training UI
                                    // Sets
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Sets")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 12) {
                                                Button {
                                                    if sets > 1 {
                                                        sets -= 1
                                                    }
                                                } label: {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(sets > 1 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(sets <= 1)
                                                
                                                Text("\(sets)")
                                                    .font(.title3)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(Color.appText)
                                                    .frame(minWidth: 40)
                                                
                                                Button {
                                                    if sets < 10 {
                                                        sets += 1
                                                    }
                                                } label: {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(sets < 10 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(sets >= 10)
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Reps
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Reps")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            TextField("10", text: $repsTarget)
                                                .foregroundStyle(Color.appText)
                                                .keyboardType(.numberPad)
                                                .multilineTextAlignment(.trailing)
                                                .frame(width: 80)
                                                .padding(10)
                                                .background(Color.appBackground)
                                                .cornerRadius(10)
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Weight
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Weight (kg)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            TextField("0", text: $targetWeight)
                                                .foregroundStyle(Color.appText)
                                                .keyboardType(.decimalPad)
                                                .multilineTextAlignment(.trailing)
                                                .frame(width: 80)
                                                .padding(10)
                                                .background(Color.appBackground)
                                                .cornerRadius(10)
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Rest
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Rest Between Sets")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 12) {
                                                Button {
                                                    if restSeconds > 0 {
                                                        restSeconds -= 15
                                                    }
                                                } label: {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(restSeconds > 0 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(restSeconds <= 0)
                                                
                                                Text("\(restSeconds)s")
                                                    .font(.title3)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(Color.appText)
                                                    .frame(minWidth: 60)
                                                
                                                Button {
                                                    if restSeconds < 300 {
                                                        restSeconds += 15
                                                    }
                                                } label: {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(restSeconds < 300 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(restSeconds >= 300)
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Configure Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        Task {
                            if isCardio {
                                let totalSeconds = (durationMinutes * 60) + durationSeconds
                                // For continuous mode, use 1 set; for intervals, use the selected count
                                let actualSets = cardioMode == .continuous ? 1 : sets
                                // For continuous mode, no rest between sets
                                let actualRest = cardioMode == .continuous ? 0 : restSeconds
                                
                                await viewModel.addExercise(
                                    exerciseId: exercise.id,
                                    sets: actualSets,
                                    repsTarget: nil,
                                    targetWeight: nil,
                                    durationSeconds: totalSeconds,
                                    restSeconds: actualRest
                                )
                            } else {
                                let weight = Double(targetWeight) ?? 0
                                await viewModel.addExercise(
                                    exerciseId: exercise.id,
                                    sets: sets,
                                    repsTarget: repsTarget,
                                    targetWeight: weight,
                                    durationSeconds: nil,
                                    restSeconds: restSeconds
                                )
                            }
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Color.appBackground)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                    
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
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
        .presentationBackground(Color.appBackground)
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
    
    // Cardio-specific
    @State private var cardioMode: CardioMode
    
    enum CardioMode: String, CaseIterable {
        case continuous = "Continuous"
        case intervals = "Intervals"
    }
    
    var isCardio: Bool {
        exercise.exerciseType == "cardio"
    }
    
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
        
        // Determine cardio mode based on sets count
        // If it's cardio and has only 1 set, it's continuous
        let mode: CardioMode = (exercise.exerciseType == "cardio" && routineExercise.sets == 1) ? .continuous : .intervals
        _cardioMode = State(initialValue: mode)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Exercise Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exercise")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appText.opacity(0.6))
                                .textCase(.uppercase)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.appText)
                                
                                if let muscle = exercise.muscleGroup {
                                    Text(muscle.capitalized)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(10)
                        }
                        
                        // Configuration Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Configuration")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appText.opacity(0.6))
                                .textCase(.uppercase)
                            
                            VStack(spacing: 12) {
                                if isCardio {
                                    // Cardio mode picker
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Mode")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.appText)
                                        
                                        Picker("Mode", selection: $cardioMode) {
                                            ForEach(CardioMode.allCases, id: \.self) { mode in
                                                Text(mode.rawValue).tag(mode)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                    .padding()
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Only show intervals count if in interval mode
                                    if cardioMode == .intervals {
                                        VStack(spacing: 0) {
                                            HStack {
                                                Text("Intervals")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(Color.appText)
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 12) {
                                                    Button {
                                                        if sets > 1 {
                                                            sets -= 1
                                                        }
                                                    } label: {
                                                        Image(systemName: "minus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundStyle(sets > 1 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(sets <= 1)
                                                    
                                                    Text("\(sets)")
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(Color.appText)
                                                        .frame(minWidth: 40)
                                                    
                                                    Button {
                                                        if sets < 20 {
                                                            sets += 1
                                                        }
                                                    } label: {
                                                        Image(systemName: "plus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundStyle(sets < 20 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(sets >= 20)
                                                }
                                            }
                                            .padding()
                                        }
                                        .background(Color.appSurface)
                                        .cornerRadius(10)
                                    }
                                    
                                    // Duration picker
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(cardioMode == .intervals ? "Duration (per interval)" : "Duration")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.appText)
                                        
                                        HStack(spacing: 16) {
                                            Picker("Minutes", selection: $durationMinutes) {
                                                ForEach(0..<61) { mins in
                                                    Text("\(mins)").tag(mins)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            
                                            Text("min")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                            
                                            Picker("Seconds", selection: $durationSeconds) {
                                                ForEach(0..<60) { secs in
                                                    Text("\(secs)").tag(secs)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            
                                            Text("sec")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                        }
                                        .frame(height: 120)
                                    }
                                    .padding()
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Only show rest for intervals
                                    if cardioMode == .intervals {
                                        VStack(spacing: 0) {
                                            HStack {
                                                Text("Rest Between Intervals")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(Color.appText)
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 12) {
                                                    Button {
                                                        if restSeconds > 0 {
                                                            restSeconds -= 15
                                                        }
                                                    } label: {
                                                        Image(systemName: "minus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundStyle(restSeconds > 0 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(restSeconds <= 0)
                                                    
                                                    Text("\(restSeconds)s")
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(Color.appText)
                                                        .frame(minWidth: 60)
                                                    
                                                    Button {
                                                        if restSeconds < 300 {
                                                            restSeconds += 15
                                                        }
                                                    } label: {
                                                        Image(systemName: "plus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundStyle(restSeconds < 300 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(restSeconds >= 300)
                                                }
                                            }
                                            .padding()
                                        }
                                        .background(Color.appSurface)
                                        .cornerRadius(10)
                                    }
                                } else {
                                    // Strength training UI
                                    // Sets
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Sets")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 12) {
                                                Button {
                                                    if sets > 1 {
                                                        sets -= 1
                                                    }
                                                } label: {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(sets > 1 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(sets <= 1)
                                                
                                                Text("\(sets)")
                                                    .font(.title3)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(Color.appText)
                                                    .frame(minWidth: 40)
                                                
                                                Button {
                                                    if sets < 10 {
                                                        sets += 1
                                                    }
                                                } label: {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(sets < 10 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(sets >= 10)
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Reps
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Reps")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            TextField("10", text: $repsTarget)
                                                .foregroundStyle(Color.appText)
                                                .keyboardType(.numberPad)
                                                .multilineTextAlignment(.trailing)
                                                .frame(width: 80)
                                                .padding(10)
                                                .background(Color.appBackground)
                                                .cornerRadius(10)
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Weight
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Weight (kg)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            TextField("0", text: $targetWeight)
                                                .foregroundStyle(Color.appText)
                                                .keyboardType(.decimalPad)
                                                .multilineTextAlignment(.trailing)
                                                .frame(width: 80)
                                                .padding(10)
                                                .background(Color.appBackground)
                                                .cornerRadius(10)
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                    
                                    // Rest
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Rest Between Sets")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 12) {
                                                Button {
                                                    if restSeconds > 0 {
                                                        restSeconds -= 15
                                                    }
                                                } label: {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(restSeconds > 0 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(restSeconds <= 0)
                                                
                                                Text("\(restSeconds)s")
                                                    .font(.title3)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(Color.appText)
                                                    .frame(minWidth: 60)
                                                
                                                Button {
                                                    if restSeconds < 300 {
                                                        restSeconds += 15
                                                    }
                                                } label: {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(restSeconds < 300 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(restSeconds >= 300)
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        Task {
                            if isCardio {
                                let totalSeconds = (durationMinutes * 60) + durationSeconds
                                // For continuous mode, use 1 set; for intervals, use the selected count
                                let actualSets = cardioMode == .continuous ? 1 : sets
                                // For continuous mode, no rest between sets
                                let actualRest = cardioMode == .continuous ? 0 : restSeconds
                                
                                await viewModel.updateExercise(
                                    id: routineExercise.id,
                                    sets: actualSets,
                                    repsTarget: nil,
                                    targetWeight: nil,
                                    durationSeconds: totalSeconds,
                                    restSeconds: actualRest
                                )
                            } else {
                                let weight = Double(targetWeight) ?? 0
                                await viewModel.updateExercise(
                                    id: routineExercise.id,
                                    sets: sets,
                                    repsTarget: repsTarget,
                                    targetWeight: weight,
                                    durationSeconds: nil,
                                    restSeconds: restSeconds
                                )
                            }
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
            .presentationBackground(Color.appBackground)
        }
    }
}
