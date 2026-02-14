//
//  WorkoutView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct WorkoutView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom tab slider
                CustomTabView(selectedTab: $selectedTab, tabs: ["Schedule", "Routines"])
                
                // Content based on selection
                TabView(selection: $selectedTab) {
                    ScheduleContentView()
                        .tag(0)
                    
                    RoutineContentView()
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.appBackground)
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                            .foregroundColor(.appText)
                    }
                    
                    Spacer()
                    
                    Text(viewModel.currentMonthYear)
                        .font(.headline)
                        .foregroundColor(.appText)
                    
                    Spacer()
                    
                    Button {
                        viewModel.nextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.appText)
                    }
                }
                .padding()
                
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
                            .foregroundColor(.appText)
                        
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
                                    .foregroundColor(.appAccent)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if viewModel.scheduledWorkouts(for: selectedDate).isEmpty {
                        VStack(spacing: 12) {
                            Text("No workouts scheduled")
                                .foregroundColor(.appText.opacity(0.6))
                                .padding(.top, 20)
                            
                            Button {
                                showingRoutinePicker = true
                            } label: {
                                Text("Add Workout")
                                    .foregroundColor(.white)
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
                                    if let routine = viewModel.routine(for: scheduled.routineId) {
                                        ScheduledWorkoutCard(
                                            routine: routine,
                                            scheduled: scheduled,
                                            isEditMode: isEditMode,
                                            exerciseCount: viewModel.exerciseCount(for: routine.id),
                                            viewModel: viewModel,
                                            onDelete: {
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
                                        )
                                    }
                                }
                                
                                // Add button below the cards
                                Button {
                                    showingRoutinePicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                        Text("Add Workout")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.appAccent)
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
        .task {
            await viewModel.loadData()
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
                        .foregroundColor(.red)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.headline)
                        .foregroundColor(.appText)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 11))
                            .foregroundColor(.appAccent)
                        Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.appText.opacity(0.6))
                    }
                    
                    if scheduled.completed {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
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
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.appAccent)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.appSurface)
            .cornerRadius(8)
        }
        .animation(.spring(response: 0.3), value: isEditMode)
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(
                routine: routine,
                routineExercises: viewModel.routineExercises(for: routine.id),
                exercises: viewModel.exercises
            )
        }
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
            .navigationTitle("Select Routine")
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
            }
        }
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
                        .foregroundColor(.appText)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 11))
                            .foregroundColor(.appAccent)
                        Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.appText.opacity(0.6))
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.appSurface)
            .cornerRadius(8)
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
    @State private var showingCreateSheet = false
    @State private var isEditMode = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading routines...")
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
                            Task { await viewModel.loadRoutines() }
                        }
                        .foregroundColor(.appAccent)
                    }
                    .padding()
                } else if viewModel.routines.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 60))
                            .foregroundColor(.appText.opacity(0.6))
                        Text("No Routines Yet")
                            .font(.headline)
                            .foregroundColor(.appText)
                        Text("Create your first workout routine")
                            .foregroundColor(.appText.opacity(0.7))
                        Button("Create Routine") {
                            showingCreateSheet = true
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
                        .padding(.top, 8)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.routines) { routine in
                                    HStack(spacing: 12) {
                                            // Delete button in edit mode
                                            if isEditMode {
                                                Button {
                                                    Task {
                                                        await viewModel.deleteRoutine(routine)
                                                        
                                                        // Exit edit mode if no routines remain
                                                        if viewModel.routines.isEmpty {
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
                                            
                                            // Show as plain card in edit mode, NavigationLink otherwise
                                            if isEditMode {
                                                RoutineCard(
                                                    routine: routine,
                                                    exerciseCount: viewModel.exerciseCount(for: routine.id)
                                                )
                                            } else {
                                                NavigationLink(destination: RoutineDetailView(routine: routine)) {
                                                    RoutineCard(
                                                        routine: routine,
                                                        exerciseCount: viewModel.exerciseCount(for: routine.id)
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .animation(.spring(response: 0.3), value: isEditMode)
                                    }
                                }
                            }
                            .padding(16)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.appAccent)
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateRoutineSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadRoutines()
        }
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
                    .foregroundColor(.appText)
                
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 11))
                        .foregroundColor(.appAccent)
                    Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.appText.opacity(0.6))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.appText.opacity(0.3))
                .font(.system(size: 14))
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

import SwiftUI

struct CalendarGridView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let daysOfWeek = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Day headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.appText.opacity(0.6))
                }
            }
            
            // Calendar days
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.calendarDays, id: \.self) { date in
                    if let date = date {
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

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkout: Bool
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appAccent)
            } else if isToday {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appAccent, lineWidth: 2)
            }
            
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : .appText)
                
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
