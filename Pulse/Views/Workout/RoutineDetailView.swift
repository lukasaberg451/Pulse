//
//  RoutineDetailView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/8/26.
//

import SwiftUI
import PostHog

struct RoutineDetailView: View {
    let routine: Routine
    @StateObject private var viewModel: RoutineDetailViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @State private var showingExercisePicker = false
    @State private var showingActiveWorkout = false
    @State private var showingEditSheet = false
    @State private var showingPaywall = false
    @State private var editingExercise: RoutineExercise?
    @State private var editMode: EditMode = .inactive
    @State private var reorderedExercises: [RoutineExercise] = []
    @State private var showingCopySuccess = false
    @State private var isCopying = false
    @State private var routineCount = 0
    @State private var hasExercisesAppeared = false
    
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
    
    // MARK: - Exercise List
    
    private var exerciseList: some View {
        let exercises = editMode == .active ? reorderedExercises : viewModel.routineExercises
        return List {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, routineExercise in
                if let exercise = viewModel.exercises.first(where: { $0.id == routineExercise.exerciseId }) {
                    exerciseRow(routineExercise: routineExercise, exercise: exercise, index: index)
                }
            }
            .onMove { source, destination in
                if editMode == .active {
                    moveItems(from: source, to: destination)
                }
            }
            .onAppear {
                if !hasExercisesAppeared {
                    DispatchQueue.main.async {
                        hasExercisesAppeared = true
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }
    
    @ViewBuilder
    private func exerciseRow(routineExercise: RoutineExercise, exercise: Exercise, index: Int) -> some View {
        StaggeredItem(
            delay: 0.1 + Double(index) * 0.08,
            animate: !hasExercisesAppeared
        ) {
            HStack(spacing: 12) {
                IconBadge(
                    assetName: exercise.exerciseType == "cardio" ? "cardio" : "musclegroup",
                    color: .appAccent,
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)
                    
                    if let reps = routineExercise.repsTarget {
                        Text("\(routineExercise.sets) sets × \(reps) reps")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    } else if let durationSeconds = routineExercise.durationSeconds {
                        let minutes = durationSeconds / 60
                        let seconds = durationSeconds % 60
                        let durationText = seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
                        Text("\(routineExercise.sets) sets × \(durationText)")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                    
                    if routineExercise.restSeconds > 0 {
                        Text("\(routineExercise.restSeconds)s rest")
                            .font(.caption)
                            .foregroundStyle(Color.appTertiaryText)
                    }
                }
                
                Spacer()
                
                if editMode != .active {
                    Menu {
                        Button {
                            editingExercise = routineExercise
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                        } label: {
                            Label { Text("Edit Exercise") } icon: { Image("pencil").resizable().scaledToFit().frame(width: 16, height: 16) }
                        }
                        
                        Button(role: .destructive) {
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.warning)
                            Task {
                                await viewModel.deleteExercise(routineExercise)
                            }
                        } label: {
                            Label { Text("Delete Exercise") } icon: { Image("trash").resizable().scaledToFit().frame(width: 16, height: 16) }
                        }
                    } label: {
                        Image("ellipsis-horizontal")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                            .foregroundStyle(Color.appTertiaryText)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay {
                        if editMode == .active {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1.5)
                        }
                    }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowSeparator(.hidden)
    }
    
    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.appAccent)
                    Text("Loading routine...")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 14) {
                    IconBadge(assetName: "error", color: .red, size: 48)
                    Text("Something went wrong")
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                        .multilineTextAlignment(.center)
                    PrimaryCTAButton("Retry", icon: "refresh") {
                        Task {
                            await viewModel.loadRoutineExercises()
                            await viewModel.loadExercises()
                        }
                    }
                    .frame(width: 160)
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    // Fixed header
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(viewModel.routine.name)
                                .font(.title.weight(.bold))
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Description, if exists
                            if let description = viewModel.routine.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Exercise count pill
                            Text("\(viewModel.routineExercises.count) exercise\(viewModel.routineExercises.count == 1 ? "" : "s")")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)
                                .padding(.top, 2)
                        }
                        
                        // Action buttons - 2x2 grid
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                // Start Workout
                                Button {
                                    cancelEditMode()
                                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                                    impactMed.impactOccurred()
                                    showingActiveWorkout = true
                                    PostHogSDK.shared.capture("workout​_started")
                                } label: {
                                    HStack(spacing: 8) {
                                        Image("play")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 12, height: 12)
                                        Text("Start Workout")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        viewModel.routineExercises.isEmpty
                                            ? AnyShapeStyle(LinearGradient.accentGradient.opacity(0.5))
                                            : AnyShapeStyle(LinearGradient.accentGradient),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                                }
                                .buttonStyle(ScalePressStyle())
                                .disabled(viewModel.routineExercises.isEmpty)
                                
                                // Edit Routine
                                DetailActionButton(
                                    icon: "pencil",
                                    title: "Edit Routine"
                                ) {
                                    cancelEditMode()
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingEditSheet = true
                                }
                            }
                            
                            HStack(spacing: 10) {
                                // Add Exercise
                                DetailActionButton(
                                    icon: "plus",
                                    title: "Add Exercise"
                                ) {
                                    cancelEditMode()
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingExercisePicker = true
                                }
                                
                                // Copy Routine
                                Button {
                                    cancelEditMode()
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    if subscriptionManager.isProUser || routineCount < SubscriptionManager.freeRoutineLimit {
                                        isCopying = true
                                        Task {
                                            if let _ = await viewModel.duplicateRoutine() {
                                                routineCount += 1
                                                showingCopySuccess = true
                                            }
                                            isCopying = false
                                        }
                                    } else {
                                        showingPaywall = true
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isCopying {
                                            ProgressView()
                                                .tint(Color.appText)
                                        } else {
                                            Image("copy")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 12, height: 12)
                                        }
                                        Text("Copy Routine")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .foregroundStyle(Color.appText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(ScalePressStyle())
                                .disabled(isCopying)
                            }
                        }
                    }
                    .padding()
                    
                    // Edit Order button (only show if there are exercises)
                    if !viewModel.routineExercises.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                if editMode == .active {
                                    let notificationFeedback = UINotificationFeedbackGenerator()
                                    notificationFeedback.notificationOccurred(.success)
                                    Task {
                                        await viewModel.saveExerciseOrder(reorderedExercises)
                                        withAnimation {
                                            editMode = .inactive
                                            reorderedExercises = []
                                            hasExercisesAppeared = false
                                        }
                                    }
                                } else {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    withAnimation {
                                        reorderedExercises = viewModel.routineExercises
                                        editMode = .active
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if editMode == .active {
                                        Image("check-circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 12, height: 12)
                                    } else {
                                        Image("updown")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 12, height: 12)
                                    }
                                    Text(editMode == .active ? "Done" : "Reorder")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(editMode == .active ? Color.green : Color.appAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    (editMode == .active ? Color.green.opacity(0.1) : Color.appAccentSubtle),
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(ScalePressStyle())
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    // Exercises list
                    if viewModel.routineExercises.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            IconBadge(
                                assetName: "clipboard-text",
                                size: 56
                            )
                            Text("No Exercises Yet")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.appText)
                            Text("Add exercises to build your routine")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        exerciseList
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(routineViewModel: viewModel)
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRoutineSheet(viewModel: viewModel, onSaved: {
            })
            .sheetContentTransition()
        }
        .sheet(item: $editingExercise) { routineExercise in
            if let exercise = viewModel.exercises.first(where: { $0.id == routineExercise.exerciseId }) {
                EditExerciseSheet(
                    routineExercise: routineExercise,
                    exercise: exercise,
                    viewModel: viewModel
                )
                .sheetContentTransition()
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
        .alert("Routine Copied", isPresented: $showingCopySuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A copy of '\(viewModel.routine.name)' has been created. You can find it in your routine list.")
        }
        .task {
            // Inject modelContext for offline support
            viewModel.modelContext = modelContext
            
            await viewModel.loadRoutineExercises()
            await viewModel.loadExercises()
            
            if let routines = try? await RoutineRepository().fetchRoutines() {
                routineCount = routines.count
            }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
                .sheetContentTransition()
        }
    }
}

struct ExercisePickerSheet: View {
    @ObservedObject var routineViewModel: RoutineDetailViewModel
    @StateObject private var viewModel = ExerciseListViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var pickerColorScheme
    
    @State private var searchText = ""
    @State private var selectedMuscle: String? = nil
    @State private var selectedEquipment: String? = nil
    @State private var showingFilterSheet = false
    @State private var showingConfigSheet = false
    @State private var showingCreateCustomSheet = false
    @State private var selectedExercise: Exercise?
    @State private var showMyExercises = true
    @State private var addedExerciseName: String?
    
    @State private var isInitialLoad = true
    
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
        "Sandbag", "Sled", "Smith Machine", "Treadmill", "TRX", "Outdoors", "Stairmaster"
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
                search: searchText.trimmingCharacters(in: .whitespaces)
            )
        }
    }
    
    private func equipmentIcon(for equipment: String) -> String {
        switch equipment.lowercased() {
        case "barbell":
            return "barbell"
        case "dumbbell":
            return "dumbbell"
        case "kettlebell":
            return "kettlebell"
        case "cable":
            return "cable"
        case "machine":
            return "machine"
        case "bodyweight":
            return "bodyweight"
        case "resistance band":
            return "band"
        case "medicine ball":
            return "ball"
        case "bike":
            return "bike"
        case "stairmaster":
            return "stairmaster"
        case "treadmill":
            return "treadmill"
        case "trx":
            return "band"
        case "smith machine":
            return "smithmachine"
        case "sled":
            return "sled"
        case "sandbag":
            return "sandbag"
        case "outdoors":
            return "outdoors"
        default:
            return "barbell"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar with filter button
                    HStack(spacing: 10) {
                        // Search field
                        HStack(spacing: 10) {
                            Image("search")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .foregroundStyle(Color.appTertiaryText)
                            TextField("Search exercises...", text: $searchText)
                                .font(.subheadline)
                                .foregroundStyle(Color.appText)
                                .onChange(of: searchText) { _, newValue in
                                    searchTask?.cancel()
                                    searchTask = Task {
                                        try? await Task.sleep(nanoseconds: 300_000_000)
                                        if !Task.isCancelled {
                                            await viewModel.resetAndLoad(
                                                equipment: selectedEquipment,
                                                muscle: selectedMuscle,
                                                search: newValue.trimmingCharacters(in: .whitespaces)
                                            )
                                        }
                                    }
                                }
                            
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image("xmark")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 15, height: 15)
                                        .foregroundStyle(Color.appTertiaryText)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            if pickerColorScheme == .dark {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                            }
                        }
                        
                        // Filter button
                        Button {
                            showingFilterSheet = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image("filter")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    .foregroundStyle(activeFilterCount > 0 ? Color.appAccent : Color.appSecondaryText)
                                    .frame(width: 48, height: 48)
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        if pickerColorScheme == .dark {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                        }
                                    }
                                
                                if activeFilterCount > 0 {
                                    Text("\(activeFilterCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Color.appAccent, in: Circle())
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .buttonStyle(ScalePressStyle())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    // Active filters display
                    if activeFilterCount > 0 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if let muscle = selectedMuscle {
                                    ActiveFilterChip(title: muscle, icon: "musclegroup") {
                                        selectedMuscle = nil
                                    }
                                }
                                
                                if let equipment = selectedEquipment {
                                    ActiveFilterChip(title: equipment, icon: "equipment") {
                                        selectedEquipment = nil
                                    }
                                }
                                
                                Button {
                                    selectedMuscle = nil
                                    selectedEquipment = nil
                                } label: {
                                    Text("Clear all")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.red.opacity(0.1), in: Capsule())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                    
                    // Results count
                    HStack {
                        Text("\(filteredExercises.count) exercises")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appTertiaryText)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    
                    // Exercise list
                    if filteredExercises.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 14) {
                            IconBadge(assetName: "search", size: 48)
                            
                            Text("No exercises found")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appText)
                            
                            Text("Try adjusting your search or filters, or create a custom exercise")
                                .font(.caption)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
                            
                            PrimaryCTAButton("Create Custom Exercise", systemIcon: "plus") {
                                showingCreateCustomSheet = true
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                        }
                        .frame(maxHeight: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                // My Exercises section - only when no search/filters active
                                if searchText.isEmpty && activeFilterCount == 0 && !viewModel.customExercises.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Button {
                                            withAnimation(.spring(response: 0.3)) {
                                                showMyExercises.toggle()
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image("profile")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 14, height: 14)
                                                    .foregroundStyle(Color.appAccent)
                                                Text("My Exercises")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Color.appText)
                                                
                                                Text("\(viewModel.customExercises.count)")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(Color.appAccent)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 2)
                                                    .background(Color.appAccentSubtle, in: Capsule())
                                                
                                                Spacer()
                                                
                                                Image("chevron-right")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(Color.appTertiaryText)
                                                    .rotationEffect(.degrees(showMyExercises ? 90 : 0))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if showMyExercises {
                                            ForEach(viewModel.customExercises) { exercise in
                                                exerciseRow(exercise)
                                            }
                                        }
                                    }
                                    .padding(.bottom, 8)
                                    
                                    // Divider between sections
                                    HStack {
                                        Text("All Exercises")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appText)
                                        Spacer()
                                    }
                                    .padding(.bottom, 4)
                                }
                                
                                ForEach(filteredExercises) { exercise in
                                    exerciseRow(exercise)
                                        .task {
                                            await viewModel.loadMoreIfNeeded(currentExercise: exercise)
                                        }
                                }
                                
                                if viewModel.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(Color.appAccent)
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                        .opacity(viewModel.isLoading ? 0 : 1)
                        .animation(.easeOut(duration: 0.25), value: viewModel.isLoading)
                    }
                }
                
                // Loading overlay - only show on initial load
                if viewModel.isLoading && isInitialLoad {
                    Color.appBackground.opacity(0.6)
                        .ignoresSafeArea()
                        .background(.ultraThinMaterial)
                    ProgressView()
                        .tint(Color.appAccent)
                }
            }
            .overlay(alignment: .top) {
                if let name = addedExerciseName {
                    HStack(spacing: 8) {
                        Image("check-circle")
                            .foregroundStyle(.green)
                        Text("\(name) added")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingCreateCustomSheet = true
                    } label: {
                        Text("Custom")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingConfigSheet) {
                if let exercise = selectedExercise {
                    ExerciseConfigSheet(
                        exercise: exercise,
                        viewModel: routineViewModel,
                        onAdded: {
                            withAnimation(.spring(response: 0.4)) {
                                addedExerciseName = exercise.name
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                withAnimation(.easeOut(duration: 0.3)) {
                                    addedExerciseName = nil
                                }
                            }
                        }
                    )
                    .sheetContentTransition()
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    selectedMuscle: $selectedMuscle,
                    selectedEquipment: $selectedEquipment,
                    muscleOptions: muscleOptions,
                    equipmentOptions: equipmentOptions
                )
                .sheetContentTransition()
            }
            .sheet(isPresented: $showingCreateCustomSheet) {
                CreateCustomExerciseSheet { exercise in
                    selectedExercise = exercise
                    showingConfigSheet = true
                    Task {
                        await viewModel.loadCustomExercises()
                    }
                }
                .sheetContentTransition()
            }
            .onChange(of: selectedMuscle) { _, _ in
                applyFilters()
            }
            .onChange(of: selectedEquipment) { _, _ in
                applyFilters()
            }
            .task {
                await viewModel.loadCustomExercises()
                await viewModel.resetAndLoad()
                isInitialLoad = false
            }
        }
        .presentationBackground(LinearGradient.dashboardBackground)
    }
    
    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            selectedExercise = exercise
            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
            showingConfigSheet = true
        } label: {
            HStack(spacing: 12) {
                IconBadge(
                    assetName: exercise.exerciseType == "cardio" ? "cardio" : "musclegroup",
                    size: 38
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appText)
                            .lineLimit(1)
                        
                        if exercise.isCustom == true {
                            Text("Custom")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.appAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.appAccentSubtle, in: Capsule())
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if let muscle = exercise.muscleGroup {
                            Text(muscle.capitalized)
                                .font(.caption)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        
                        if let equipment = exercise.equipment {
                            HStack(spacing: 3) {
                                Image(equipmentIcon(for: equipment))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 9, height: 9)
                                Text(equipment.capitalized)
                            }
                            .font(.caption)
                            .foregroundStyle(Color.appAccent)
                        }
                    }
                }
                
                Spacer()
                
                Image("plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.appAccent)
            }
            .padding(14)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if pickerColorScheme == .dark {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                }
            }
        }
        .buttonStyle(ScalePressStyle())
    }
}

// MARK: - Active Filter Chip
struct ActiveFilterChip: View {
    let title: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
            Text(title)
                .font(.caption.weight(.semibold))
            
            Button(action: onRemove) {
                Image("xmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(LinearGradient.accentGradient, in: Capsule())
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Muscle Group Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 8) {
                                    IconBadge(assetName: "musclegroup", size: 28)
                                    Text("Muscle Group")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appText)
                                }
                                
                                Spacer()
                                
                                if tempMuscle != nil {
                                    Button("Clear") {
                                        withAnimation(.spring(response: 0.3)) {
                                            tempMuscle = nil
                                        }
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appAccent)
                                }
                            }
                            
                            FlowLayout(spacing: 8) {
                                ForEach(muscleOptions, id: \.self) { muscle in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            tempMuscle = tempMuscle == muscle ? nil : muscle
                                        }
                                    } label: {
                                        Text(muscle)
                                            .font(.subheadline.weight(tempMuscle == muscle ? .semibold : .regular))
                                            .foregroundStyle(tempMuscle == muscle ? .white : Color.appText)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(
                                                tempMuscle == muscle
                                                    ? AnyShapeStyle(LinearGradient.accentGradient)
                                                    : AnyShapeStyle(Color.appSurface),
                                                in: Capsule()
                                            )
                                            .overlay {
                                                if tempMuscle != muscle && colorScheme == .dark {
                                                    Capsule()
                                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                                }
                                            }
                                    }
                                    .buttonStyle(ScalePressStyle())
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            if colorScheme == .dark {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 12, x: 0, y: 4)
                        
                        // Equipment Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 8) {
                                    IconBadge(assetName: "equipment", size: 28)
                                    Text("Equipment")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appText)
                                }
                                
                                Spacer()
                                
                                if tempEquipment != nil {
                                    Button("Clear") {
                                        withAnimation(.spring(response: 0.3)) {
                                            tempEquipment = nil
                                        }
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appAccent)
                                }
                            }
                            
                            FlowLayout(spacing: 8) {
                                ForEach(equipmentOptions, id: \.self) { equipment in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            tempEquipment = tempEquipment == equipment ? nil : equipment
                                        }
                                    } label: {
                                        Text(equipment)
                                            .font(.subheadline.weight(tempEquipment == equipment ? .semibold : .regular))
                                            .foregroundStyle(tempEquipment == equipment ? .white : Color.appText)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(
                                                tempEquipment == equipment
                                                    ? AnyShapeStyle(LinearGradient.accentGradient)
                                                    : AnyShapeStyle(Color.appSurface),
                                                in: Capsule()
                                            )
                                            .overlay {
                                                if tempEquipment != equipment && colorScheme == .dark {
                                                    Capsule()
                                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                                }
                                            }
                                    }
                                    .buttonStyle(ScalePressStyle())
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            if colorScheme == .dark {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 12, x: 0, y: 4)
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
                    .foregroundStyle(Color.appSecondaryText)
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
        .presentationBackground(LinearGradient.dashboardBackground)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Create Custom Exercise Sheet
struct CreateCustomExerciseSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var exerciseName = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    let onCreated: (Exercise) -> Void
    
    private let repository = ExerciseRepository.shared
    
    enum ExerciseType: String, CaseIterable {
        case strength = "Strength"
        case cardio = "Cardio"
        
        var databaseValue: String {
            switch self {
            case .strength: return "strength"
            case .cardio: return "cardio"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Exercise name
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Exercise Name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appText)
                        
                        TextField("e.g. Reverse Nordic Curl", text: $exerciseName)
                            .font(.subheadline)
                            .foregroundStyle(Color.appText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                if colorScheme == .dark {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                }
                            }
                    }
                    
                    // Exercise type
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Type")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appText)
                        
                        Picker("Type", selection: $exerciseType) {
                            ForEach(ExerciseType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Text("To delete custom exercises, go to your profile.")
                        .font(.footnote)
                        .foregroundStyle(Color.appSecondaryText.opacity(0.8))
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Spacer()
                    
                    // Create button
                    Button {
                        createExercise()
                    } label: {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image("plus")
                                    .font(.subheadline)
                            }
                            Text("Create Exercise")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            exerciseName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AnyShapeStyle(LinearGradient.accentGradient.opacity(0.5))
                                : AnyShapeStyle(LinearGradient.accentGradient),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(ScalePressStyle())
                    .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
                .padding()
            }
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appSecondaryText)
                }
            }
        }
        .presentationBackground(LinearGradient.dashboardBackground)
        .presentationDetents([.medium])
    }
    
    private func createExercise() {
        let name = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let exercise = try await repository.createCustomExercise(
                    name: name,
                    exerciseType: exerciseType.databaseValue
                )
                NotificationCenter.default.post(name: .customExerciseCreated, object: exercise)
                dismiss()
                onCreated(exercise)
            } catch {
                errorMessage = "Failed to create exercise. Please try again."
            }
            isCreating = false
        }
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
                .cornerRadius(12)
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
                .cornerRadius(12)
        }
    }
}

// MARK: - Exercise 1RM Banner
/// Shows the estimated 1RM for an exercise if one exists. Hidden for cardio.
struct Exercise1RMBanner: View {
    let exerciseId: UUID
    let isCardio: Bool
    @EnvironmentObject var unitManager: UnitManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var stat: Exercise1RMRow?

    var body: some View {
        VStack(spacing: 0) {
            if !isCardio, let stat {
                HStack(spacing: 12) {
                    IconBadge(assetName: "crown", color: .orange, size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estimated 1RM")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                        Text("\(unitManager.displayWeight(stat.bestEstimated1rm), specifier: "%.1f") \(unitManager.weightUnit)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Based on")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.appTertiaryText)
                        Text("\(unitManager.displayWeight(stat.bestWeight), specifier: "%.1f") \(unitManager.weightUnit) × \(stat.bestReps)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                .padding(14)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 12, x: 0, y: 4)
            }
        }
        .task(id: exerciseId) {
            guard !isCardio else { return }
            debugLog("Exercise1RMBanner .task fired for exerciseId: \(exerciseId)")
            do {
                let result = try await WorkoutRepository().fetchSingleExercise1RMForCurrentUser(exerciseId: exerciseId)
                debugLog("Exercise1RMBanner fetch result: \(String(describing: result))")
                stat = result
            } catch {
                debugLog("Failed to load 1RM for exercise: \(error)")
            }
        }
    }
}

struct ExerciseConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
    let exercise: Exercise
    @ObservedObject var viewModel: RoutineDetailViewModel
    var onAdded: (() -> Void)?
    
    @State private var sets = 3
    @State private var repsTarget = "8"
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
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Exercise Info Card
                        HStack(spacing: 14) {
                            IconBadge(
                                assetName: isCardio ? "cardio" : "musclegroup",
                                size: 44
                            )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                    
                                    if exercise.isCustom == true {
                                        Text("Custom")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color.appAccent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.appAccentSubtle, in: Capsule())
                                    }
                                }
                                
                                if let muscle = exercise.muscleGroup {
                                    Text(muscle.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            if colorScheme == .dark {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 12, x: 0, y: 4)
                        
                        // Estimated 1RM Banner
                        Exercise1RMBanner(exerciseId: exercise.id, isCardio: isCardio)
                        
                        // Configuration Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CONFIGURATION")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.appTertiaryText)
                                .tracking(0.5)
                            
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
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
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
                                                        Image("minus-circle")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 22, height: 22)
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
                                                        Image("plus")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 22, height: 22)
                                                            .foregroundStyle(sets < 20 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(sets >= 20)
                                                }
                                            }
                                            .padding()
                                        }
                                        .background(Color.appSurface)
                                        .cornerRadius(12)
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
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
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
                                                        Image("minus-circle")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 22, height: 22)
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
                                                        Image("plus")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 22, height: 22)
                                                            .foregroundStyle(restSeconds < 300 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(restSeconds >= 300)
                                                }
                                            }
                                            .padding()
                                        }
                                        .background(Color.appSurface)
                                        .cornerRadius(12)
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
                                                    Image("minus-circle")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
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
                                                    Image("plus")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
                                                        .foregroundStyle(sets < 10 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(sets >= 10)
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
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
                                                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
                                    // Weight
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Weight (\(unitManager.weightUnit))")
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
                                                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
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
                                                    Image("minus-circle")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
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
                                                    Image("plus")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
                                                        .foregroundStyle(restSeconds < 300 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(restSeconds >= 300)
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .foregroundStyle(Color.appSecondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        Task {
                            // Ensure the exercise is in the viewModel's exercises list
                            if !viewModel.exercises.contains(where: { $0.id == exercise.id }) {
                                viewModel.exercises.append(exercise)
                            }
                            
                            if isCardio {
                                let totalSeconds = (durationMinutes * 60) + durationSeconds
                                let actualSets = cardioMode == .continuous ? 1 : sets
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
                                let weight = unitManager.toKg(Double(targetWeight) ?? 0)
                                await viewModel.addExercise(
                                    exerciseId: exercise.id,
                                    sets: sets,
                                    repsTarget: repsTarget,
                                    targetWeight: weight,
                                    durationSeconds: nil,
                                    restSeconds: restSeconds
                                )
                            }
                            onAdded?()
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(LinearGradient.dashboardBackground)
    }
}

struct EditRoutineSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: RoutineDetailViewModel
    @State private var name: String
    @State private var description: String
    @State private var isSaving = false
    @FocusState private var focusedField: Field?
    let onSaved: () -> Void

    private enum Field { case name, notes }

    init(viewModel: RoutineDetailViewModel, onSaved: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSaved = onSaved
        _name = State(initialValue: viewModel.routine.name)
        _description = State(initialValue: viewModel.routine.description ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        IconBadge(assetName: "edit-pencil", color: .appAccent, size: 48)

                        Text("Edit Routine")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)

                        Text("Update your routine details")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                    .padding(.top, 20)

                    // Form fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Routine Name")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)
                                .padding(.horizontal, 4)

                            TextField("Push Day", text: $name)
                                .font(.body)
                                .padding(14)
                                .foregroundStyle(Color.appText)
                                .focused($focusedField, equals: .name)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.appSurface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(
                                                    focusedField == .name
                                                        ? Color.appAccent.opacity(0.5)
                                                        : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.clear),
                                                    lineWidth: 1
                                                )
                                        }
                                        .shadow(
                                            color: colorScheme == .light
                                                ? Color.black.opacity(0.04)
                                                : Color.clear,
                                            radius: 6,
                                            x: 0,
                                            y: 2
                                        )
                                }
                                .submitLabel(.next)
                                .onSubmit { focusedField = .notes }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (Optional)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)
                                .padding(.horizontal, 4)

                            TextField("Add a description or notes", text: $description, axis: .vertical)
                                .font(.body)
                                .padding(14)
                                .foregroundStyle(Color.appText)
                                .focused($focusedField, equals: .notes)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.appSurface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(
                                                    focusedField == .notes
                                                        ? Color.appAccent.opacity(0.5)
                                                        : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.clear),
                                                    lineWidth: 1
                                                )
                                        }
                                        .shadow(
                                            color: colorScheme == .light
                                                ? Color.black.opacity(0.04)
                                                : Color.clear,
                                            radius: 6,
                                            x: 0,
                                            y: 2
                                        )
                                }
                                .lineLimit(3...6)
                        }
                    }
                    .padding(.horizontal)

                    // CTA Button
                    PrimaryCTAButton("Save Changes", icon: "check") {
                        isSaving = true
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        Task {
                            await viewModel.updateRoutine(name: name, description: description)
                            onSaved()
                            dismiss()
                        }
                    }
                    .opacity(name.isEmpty ? 0.5 : 1.0)
                    .disabled(name.isEmpty || isSaving)
                    .padding(.horizontal)

                    Spacer()
                }
            }
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
        }
        .presentationBackground(Color.appBackground)
    }
}
    

struct EditExerciseSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
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
        let displayWeight = UnitManager.shared.displayWeight(routineExercise.targetWeight ?? 0)
        _targetWeight = State(initialValue: String(format: "%.1f", displayWeight))
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
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Exercise Info Card
                        HStack(spacing: 14) {
                            IconBadge(
                                assetName: isCardio ? "cardio" : "musclegroup",
                                size: 44
                            )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                    
                                    if exercise.isCustom == true {
                                        Text("Custom")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color.appAccent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.appAccentSubtle, in: Capsule())
                                    }
                                }
                                
                                if let muscle = exercise.muscleGroup {
                                    Text(muscle.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            if colorScheme == .dark {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 12, x: 0, y: 4)
                        
                        // Estimated 1RM Banner
                        Exercise1RMBanner(exerciseId: exercise.id, isCardio: isCardio)
                        
                        // Configuration Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CONFIGURATION")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.appTertiaryText)
                                .tracking(0.5)
                            
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
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
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
                                                        Image("minus-circle")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 22, height: 22)
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
                                                        Image("plus")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 22, height: 22)
                                                            .foregroundStyle(sets < 20 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(sets >= 20)
                                                }
                                            }
                                            .padding()
                                        }
                                        .background(Color.appSurface)
                                        .cornerRadius(12)
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
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
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
                                                        Image("minus-circle")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 22, height: 22)
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
                                                        Image("plus")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 22, height: 22)
                                                            .foregroundStyle(restSeconds < 300 ? Color.appAccent : Color.appText.opacity(0.3))
                                                    }
                                                    .disabled(restSeconds >= 300)
                                                }
                                            }
                                            .padding()
                                        }
                                        .background(Color.appSurface)
                                        .cornerRadius(12)
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
                                                    Image("minus-circle")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
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
                                                    Image("plus")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
                                                        .foregroundStyle(sets < 10 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(sets >= 10)
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
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
                                                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
                                    // Weight
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Weight (\(unitManager.weightUnit))")
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
                                                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
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
                                                    Image("minus-circle")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
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
                                                    Image("plus")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
                                                        .foregroundStyle(restSeconds < 300 ? Color.appAccent : Color.appText.opacity(0.3))
                                                }
                                                .disabled(restSeconds >= 300)
                                            }
                                        }
                                        .padding()
                                    }
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .foregroundStyle(Color.appSecondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        Task {
                            if isCardio {
                                let totalSeconds = (durationMinutes * 60) + durationSeconds
                                let actualSets = cardioMode == .continuous ? 1 : sets
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
                                let weight = unitManager.toKg(Double(targetWeight) ?? 0)
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
            .presentationBackground(LinearGradient.dashboardBackground)
        }
    }
}

// MARK: - Detail Action Button

private struct DetailActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Color.appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(ScalePressStyle())
    }
}
