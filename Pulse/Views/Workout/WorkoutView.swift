//
//  WorkoutView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI

struct WorkoutView: View {
    @State private var selectedTab = 0
    @State private var routineToNavigateTo: Routine?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom tab slider
                CustomTabView(selectedTab: $selectedTab, tabs: ["Schedule", "Routines"])
                    .padding(.top, 30)
                
                // Content based on selection
                TabView(selection: $selectedTab) {
                    ScheduleContentView()
                        .tag(0)
                    
                    RoutineContentView(routineToNavigateTo: $routineToNavigateTo)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .navigationDestination(item: $routineToNavigateTo) { routine in
                RoutineDetailView(routine: routine)
            }
        }
    }
}

// Schedule tab content
struct ScheduleContentView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @StateObject private var exerciseViewModel = ExerciseListViewModel()
    @State private var selectedDate = Date()
    @State private var showingRoutinePicker = false
    @State private var isEditMode = false
    @State private var scheduledToDelete: ScheduledWorkout?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Month/Year selector
                HStack {
                    Button {
                        viewModel.previousMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.appText)
                    }
                    
                    Spacer()
                    
                    Text(viewModel.currentMonthYear)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    
                    Spacer()
                    
                    Button {
                        viewModel.nextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.appText)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 30)
                .padding(.bottom, 16)
                
                // Calendar Grid
                CalendarGridView(
                    viewModel: viewModel,
                    selectedDate: $selectedDate,
                    onDateSelected: { date in
                        selectedDate = date
                    }
                )
                
                Divider()
                    .background(Color.appSurface)
                
                // Scheduled workouts for selected date
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Scheduled for \(selectedDate, style: .date)")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        Spacer()
                        
                        // Show Edit button only if there are non-completed workouts
                        if !viewModel.scheduledWorkouts(for: selectedDate).isEmpty &&
                           viewModel.scheduledWorkouts(for: selectedDate).contains(where: { !$0.completed }) {
                            Button {
                                withAnimation {
                                    isEditMode.toggle()
                                }
                            } label: {
                                Text(isEditMode ? "Done" : "Edit")
                                    .foregroundStyle(Color.appAccent)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if viewModel.scheduledWorkouts(for: selectedDate).isEmpty {
                        VStack(spacing: 12) {
                            Text("No workouts scheduled")
                                .foregroundStyle(Color.appText.opacity(0.6))
                                .padding(.top, 20)
                            
                            Button {
                                // Exit edit mode if active
                                if isEditMode {
                                    withAnimation {
                                        isEditMode = false
                                    }
                                }
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
                                showingRoutinePicker = true
                            } label: {
                                Text("Add Workout")
                                    .foregroundStyle(Color.appText)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.appAccent)
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(viewModel.scheduledWorkouts(for: selectedDate)) { scheduled in
                                    if let routineId = scheduled.routineId,
                                       let routine = viewModel.routine(for: routineId) {
                                        ScheduledWorkoutCard(
                                            routine: routine,
                                            scheduled: scheduled,
                                            isEditMode: isEditMode,
                                            exerciseCount: viewModel.exerciseCount(for: routine.id),
                                            viewModel: viewModel,
                                            onDelete: {
                                                scheduledToDelete = scheduled
                                                showingDeleteAlert = true
                                            }
                                        )
                                    } else if scheduled.routineDeleted == true || scheduled.routineId == nil {
                                        DeletedRoutineWorkoutCard(
                                            scheduled: scheduled,
                                            viewModel: viewModel,
                                            isEditMode: isEditMode,
                                            onDelete: {
                                                scheduledToDelete = scheduled
                                                showingDeleteAlert = true
                                            }
                                        )
                                    }
                                }
                                
                                // Add button below the cards
                                Button {
                                    // Exit edit mode if active
                                    if isEditMode {
                                        withAnimation {
                                            isEditMode = false
                                        }
                                    }
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingRoutinePicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                        Text("Add Workout")
                                            .font(.headline)
                                    }
                                    .foregroundStyle(Color.appAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.appSurface)
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                    }
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingRoutinePicker) {
            RoutinePickerSheet(
                viewModel: viewModel,
                selectedDate: selectedDate
            )
        }
        .alert("Remove Workout", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let scheduled = scheduledToDelete {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.warning)
                    Task {
                        await viewModel.deleteScheduled(scheduled)
                        
                        // Exit edit mode if no non-completed workouts remain
                        if !viewModel.scheduledWorkouts(for: selectedDate).contains(where: { !$0.completed }) {
                            withAnimation {
                                isEditMode = false
                            }
                        }
                    }
                }
            }
        } message: {
            if let scheduled = scheduledToDelete,
               let routineId = scheduled.routineId,
               let routine = viewModel.routine(for: routineId) {
                Text("Are you sure you want to remove '\(routine.name)' from your schedule?")
            }
        }
        .task {
            await viewModel.loadData()
        }
        .onAppear {
            // Reload data when view appears (not just first time)
            Task {
                await viewModel.loadData()
            }
        }
    }
}
                   
struct ScheduledWorkoutCard: View {
    let routine: Routine
    let scheduled: ScheduledWorkout
    let isEditMode: Bool
    let exerciseCount: Int
    @ObservedObject var viewModel: ScheduleViewModel
    let onDelete: () -> Void
    
    @State private var showingActiveWorkout = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Delete button (only for non-completed workouts in edit mode)
            if isEditMode && !scheduled.completed {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.red)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            if scheduled.completed, let sessionId = scheduled.workoutSessionId,
               let session = viewModel.workoutSession(for: sessionId) {
                NavigationLink(destination: WorkoutDetailView(workoutSession: session)) {
                    scheduledWorkoutContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                scheduledWorkoutContent
            }
        }
        .animation(.spring(response: 0.3), value: isEditMode)
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(
                routine: routine,
                routineExercises: viewModel.routineExercises(for: routine.id),
                exercises: viewModel.exercises,
                scheduledWorkoutId: scheduled.id,
                workoutSessionId: scheduled.workoutSessionId
            )
        }
    }
    
    private var scheduledWorkoutContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.headline)
                    .foregroundStyle(Color.appText)
                
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appAccent)
                    Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
                
                if scheduled.completed {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                }
            }
            
            Spacer()
            
            if !scheduled.completed {
                Button {
                    showingActiveWorkout = true
                } label: {
                    Text("Start")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appAccent)
                        .cornerRadius(10)
                }
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.appText.opacity(0.3))
                    .font(.system(size: 14))
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(10)
    }
}

struct DeletedRoutineWorkoutCard: View {
    let scheduled: ScheduledWorkout
    @ObservedObject var viewModel: ScheduleViewModel
    let isEditMode: Bool
    let onDelete: () -> Void
    
    private var sessionName: String {
        if let sessionId = scheduled.workoutSessionId,
           let session = viewModel.workoutSession(for: sessionId) {
            return session.name
        }
        return "Deleted Routine"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if isEditMode && !scheduled.completed {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.red)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            if scheduled.completed, let sessionId = scheduled.workoutSessionId,
               let session = viewModel.workoutSession(for: sessionId) {
                NavigationLink(destination: WorkoutDetailView(workoutSession: session)) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
        .animation(.spring(response: 0.3), value: isEditMode)
    }
    
    private var cardContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionName)
                    .font(.headline)
                    .foregroundStyle(Color.appText)
                
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appText.opacity(0.4))
                    Text("Routine deleted")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.4))
                }
                
                if scheduled.completed {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                }
            }
            
            Spacer()
            
            if scheduled.completed {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.appText.opacity(0.3))
                    .font(.system(size: 14))
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(10)
    }
}

struct RoutinePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ScheduleViewModel
    let selectedDate: Date
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if viewModel.routines.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.appAccent.opacity(0.4))
                        Text("No Routines Yet")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        Text("Go to Routines tab to create your first routine")
                            .foregroundStyle(Color.appText.opacity(0.7))
                    }
                } else {
                    List(viewModel.routines) { routine in
                        RoutinePickerRow(
                            routine: routine,
                            exerciseCount: viewModel.exerciseCount(for: routine.id),
                            onSelect: {
                                Task {
                                    await viewModel.scheduleWorkout(routineId: routine.id, date: selectedDate)
                                    dismiss()
                                }
                            }
                        )
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select Routine")
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

struct RoutinePickerRow: View {
    let routine: Routine
    let exerciseCount: Int
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appAccent)
                        Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(Color.appText.opacity(0.6))
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.appSurface)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

// Routines tab content
struct RoutineContentView: View {
    @StateObject private var viewModel = RoutineListViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreateSheet = false
    @State private var isEditMode = false
    @State private var routineToDelete: Routine?
    @State private var showingDeleteAlert = false
    @Binding var routineToNavigateTo: Routine?
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading routines...")
                        .foregroundStyle(Color.appText)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        Text(error)
                            .foregroundStyle(Color.appText.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.loadRoutines() }
                        }
                        .foregroundStyle(Color.appAccent)
                    }
                    .padding()
                } else if viewModel.routines.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.appAccent.opacity(0.4))
                        Text("No Routines Yet")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        Text("Create your first workout routine")
                            .foregroundStyle(Color.appText.opacity(0.7))
                        Button("Create Routine") {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            showingCreateSheet = true
                        }
                        .foregroundStyle(Color.appText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .cornerRadius(10)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Header with edit and new routine buttons
                        HStack {
                            Button {
                                // Exit edit mode if active
                                if isEditMode {
                                    withAnimation {
                                        isEditMode = false
                                    }
                                }
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
                                showingCreateSheet = true
                            } label: {
                                Text("New Routine")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.appAccent)
                                    .cornerRadius(10)
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    isEditMode.toggle()
                                }
                            } label: {
                                Text(isEditMode ? "Done" : "Edit")
                                    .foregroundStyle(Color.appAccent)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 30)
                        .padding(.bottom, 12)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.routines) { routine in
                                    RoutineRow(
                                        routine: routine,
                                        isEditMode: isEditMode,
                                        exerciseCount: viewModel.exerciseCount(for: routine.id),
                                        onTap: {
                                            routineToNavigateTo = routine
                                        },
                                        onDelete: {
                                            routineToDelete = routine
                                            showingDeleteAlert = true
                                        }
                                    )
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateRoutineSheet(
                viewModel: viewModel,
                onRoutineCreated: { routine in
                    routineToNavigateTo = routine
                }
            )
        }
        .alert("Delete Routine", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let routine = routineToDelete {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.warning)
                    Task {
                        await viewModel.deleteRoutine(routine)
                        
                        // Exit edit mode if no routines remain
                        if viewModel.routines.isEmpty {
                            withAnimation {
                                isEditMode = false
                            }
                        }
                    }
                }
            }
        } message: {
            if let routine = routineToDelete {
                Text("Are you sure you want to delete '\(routine.name)'? This action cannot be undone.")
            }
        }
        .task {
            await viewModel.loadRoutines()
        }
    }
}

struct CreateRoutineSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: RoutineListViewModel
    let onRoutineCreated: (Routine) -> Void
    @State private var name = ""
    @State private var description = ""
    
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
            .navigationTitle("Create Routine")
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
                    Button("Create") {
                        Task {
                            if let newRoutine = await viewModel.createRoutine(name: name, description: description) {
                                onRoutineCreated(newRoutine)
                                    dismiss()
                            }
                        }
                    }
                    .foregroundStyle(Color(name.isEmpty ? Color.appText.opacity(0.3) : Color.appAccent))
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
}

struct RoutineCard: View {
    let routine: Routine
    let exerciseCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.headline)
                    .foregroundStyle(Color.appText)
                
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appAccent)
                    Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.appText.opacity(0.3))
                .font(.system(size: 14))
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(10)
    }
}

struct RoutineRow: View {
    let routine: Routine
    let isEditMode: Bool
    let exerciseCount: Int
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Delete button in edit mode
            if isEditMode {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.red)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Card - always the same structure, just disable tap in edit mode
            Button {
                if !isEditMode {
                    onTap()
                }
            } label: {
                RoutineCard(
                    routine: routine,
                    exerciseCount: exerciseCount
                )
            }
            .buttonStyle(PlainButtonStyle())
            .allowsHitTesting(!isEditMode)
        }
        .animation(.spring(response: 0.3), value: isEditMode)
    }
}

import SwiftUI

struct CalendarGridView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let daysOfWeek = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    
    // Create identifiable calendar items
    private var calendarItems: [CalendarItem] {
        viewModel.calendarDays.enumerated().map { index, date in
            CalendarItem(id: index, date: date)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Day headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
            }
            
            // Calendar days
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(calendarItems) { item in
                    if let date = item.date {
                        CalendarDayView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            hasWorkout: viewModel.hasScheduledWorkout(on: date),
                            isCompleted: viewModel.isWorkoutCompleted(on: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                            onDateSelected(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding()
    }
}

// Helper struct for calendar items with stable identity
private struct CalendarItem: Identifiable {
    let id: Int
    let date: Date?
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkout: Bool
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appAccent)
            } else if isToday {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.appAccent, lineWidth: 2)
            }
            
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.appText : Color.appText)
                
                if hasWorkout {
                    Circle()
                        .fill(isCompleted ? Color.green : Color.appAccent)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 44)
    }
}
