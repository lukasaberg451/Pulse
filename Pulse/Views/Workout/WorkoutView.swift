//
//  WorkoutView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import PostHog

struct WorkoutView: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @ObservedObject var routineListViewModel: RoutineListViewModel
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
                    ScheduleContentView(viewModel: scheduleViewModel)
                        .tag(0)
                    
                    RoutineContentView(viewModel: routineListViewModel, routineToNavigateTo: $routineToNavigateTo)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .navigationDestination(item: $routineToNavigateTo) { routine in
                RoutineDetailView(routine: routine)
                    .hidesTabBar()
            }
        }
    }
}

// Schedule tab content
struct ScheduleContentView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @StateObject private var exerciseViewModel = ExerciseListViewModel()
    @State private var selectedDate = Date()
    @State private var showingRoutinePicker = false
    @State private var isEditMode = false
    @State private var scheduledToDelete: ScheduledWorkout?
    @State private var showingDeleteAlert = false
    @State private var monthChangeDirection: Edge = .trailing
    @Environment(\.tabBarBottomInset) private var tabBarBottomInset

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Month/Year selector
                    HStack {
                        Button {
                            monthChangeDirection = .leading
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.previousMonth()
                            }
                        } label: {
                            Image("chevron-left")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color.appSecondaryText)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScalePressStyle())

                        Spacer()

                        Text(viewModel.currentMonthYear)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.appText)
                            .id(viewModel.currentMonthYear)
                            .transition(.push(from: monthChangeDirection))

                        Spacer()

                        Button {
                            monthChangeDirection = .trailing
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.nextMonth()
                            }
                        } label: {
                            Image("chevron-right")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 13, height: 13)
                                .foregroundStyle(Color.appSecondaryText)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScalePressStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 32)
                    .padding(.bottom, 12)

                    // Calendar Grid
                    CalendarGridView(
                        viewModel: viewModel,
                        selectedDate: $selectedDate,
                        onDateSelected: { date in
                            selectedDate = date
                        }
                    )

                    // Scheduled workouts section in a card
                    ScheduledSectionCard(
                        viewModel: viewModel,
                        selectedDate: selectedDate,
                        isEditMode: $isEditMode,
                        showingRoutinePicker: $showingRoutinePicker,
                        onDeleteScheduled: { scheduled in
                            scheduledToDelete = scheduled
                            showingDeleteAlert = true
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .contentMargins(.bottom, tabBarBottomInset, for: .scrollContent)
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
            if !viewModel.hasLoaded {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - Scheduled Section Card

/// The bottom section showing workouts for the selected date, wrapped in a modern card.
private struct ScheduledSectionCard: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let selectedDate: Date
    @Binding var isEditMode: Bool
    @Binding var showingRoutinePicker: Bool
    let onDeleteScheduled: (ScheduledWorkout) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var workouts: [ScheduledWorkout] {
        viewModel.scheduledWorkouts(for: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Text("Scheduled for \(viewModel.formattedDate(selectedDate))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Spacer()

                if !workouts.isEmpty && workouts.contains(where: { !$0.completed }) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isEditMode.toggle()
                        }
                    } label: {
                        Text(isEditMode ? "Done" : "Edit")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }

            if workouts.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    IconBadge(assetName: "calendar-days", size: 44)

                    Text("No workouts scheduled")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)

                    PrimaryCTAButton("Add Workout", icon: "plus") {
                        if isEditMode {
                            withAnimation { isEditMode = false }
                        }
                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                        impactLight.impactOccurred()
                        showingRoutinePicker = true
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(workouts) { scheduled in
                        if let routineId = scheduled.routineId,
                           let routine = viewModel.routine(for: routineId) {
                            ScheduledWorkoutCard(
                                routine: routine,
                                scheduled: scheduled,
                                isEditMode: isEditMode,
                                exerciseCount: viewModel.exerciseCount(for: routine.id),
                                viewModel: viewModel,
                                onDelete: {
                                    onDeleteScheduled(scheduled)
                                }
                            )
                        } else if scheduled.routineDeleted == true || scheduled.routineId == nil {
                            DeletedRoutineWorkoutCard(
                                scheduled: scheduled,
                                viewModel: viewModel,
                                isEditMode: isEditMode,
                                onDelete: {
                                    onDeleteScheduled(scheduled)
                                }
                            )
                        }
                    }

                    // Inline add button
                    Button {
                        if isEditMode {
                            withAnimation { isEditMode = false }
                        }
                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                        impactLight.impactOccurred()
                        showingRoutinePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image("plus-circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                            Text("Add Workout")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.appAccentSubtle)
                        }
                    }
                    .buttonStyle(ScalePressStyle())
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appSurface)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .shadow(
                    color: colorScheme == .light
                        ? Color.black.opacity(0.08)
                        : Color.clear,
                    radius: 16,
                    x: 0,
                    y: 6
                )
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

    @Environment(\.colorScheme) private var colorScheme
    @State private var showingActiveWorkout = false

    var body: some View {
        HStack(spacing: 12) {
            if isEditMode && !scheduled.completed {
                Button {
                    onDelete()
                } label: {
                    Image("minus-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.red)
                }
                .transition(.scale.combined(with: .opacity))
            }

            if scheduled.completed, let sessionId = scheduled.workoutSessionId,
               let session = viewModel.workoutSession(for: sessionId) {
                NavigationLink(destination: WorkoutDetailView(workoutSession: session).hidesTabBar()) {
                    scheduledWorkoutContent
                }
                .buttonStyle(.plain)
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
        HStack(spacing: 12) {
            IconBadge(
                systemName: "figure.strengthtraining.traditional",
                color: .appAccent,
                size: 38
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)

                if scheduled.completed {
                    HStack(spacing: 4) {
                        Image("check-circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("Completed")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                }
            }

            Spacer()

            if !scheduled.completed {
                Button {
                    showingActiveWorkout = true
                    PostHogSDK.shared.capture("scheduled_workout_started​")
                } label: {
                    Text("Start")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(LinearGradient.accentGradient, in: Capsule())
                }
                .buttonStyle(ScalePressStyle())
            } else {
                Image("chevron-right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Color.appTertiaryText)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appBackground)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }
        }
    }
}

struct DeletedRoutineWorkoutCard: View {
    let scheduled: ScheduledWorkout
    @ObservedObject var viewModel: ScheduleViewModel
    let isEditMode: Bool
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

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
                    Image("minus-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.red)
                }
                .transition(.scale.combined(with: .opacity))
            }

            if scheduled.completed, let sessionId = scheduled.workoutSessionId,
               let session = viewModel.workoutSession(for: sessionId) {
                NavigationLink(destination: WorkoutDetailView(workoutSession: session).hidesTabBar()) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .animation(.spring(response: 0.3), value: isEditMode)
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            IconBadge(assetName: "trash", color: Color.appTertiaryText, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(sessionName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Text("Routine deleted")
                    .font(.caption)
                    .foregroundStyle(Color.appTertiaryText)

                if scheduled.completed {
                    HStack(spacing: 4) {
                        Image("check-circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("Completed")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                }
            }

            Spacer()

            if scheduled.completed {
                Image("chevron-right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Color.appTertiaryText)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appBackground)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }
        }
    }
}

struct RoutinePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: ScheduleViewModel
    let selectedDate: Date

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                if viewModel.routines.isEmpty {
                    VStack(spacing: 16) {
                        IconBadge(
                            systemName: "figure.strengthtraining.traditional",
                            size: 56
                        )
                        Text("No Routines Yet")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        Text("Go to Routines tab to create your first routine")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                IconBadge(
                    systemName: "figure.strengthtraining.traditional",
                    color: .appAccent,
                    size: 38
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(routine.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }

                Spacer()

                Image("plus-circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Color.appAccent)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: colorScheme == .light
                            ? Color.black.opacity(0.06)
                            : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 3
                    )
            }
        }
        .buttonStyle(ScalePressStyle())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }
}

// Routines tab content
struct RoutineContentView: View {
    @ObservedObject var viewModel: RoutineListViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingCreateSheet = false
    @State private var showingPaywall = false
    @State private var isEditMode = false
    @State private var routineToDelete: Routine?
    @State private var showingDeleteAlert = false
    @Binding var routineToNavigateTo: Routine?
    @Environment(\.tabBarBottomInset) private var tabBarBottomInset

    private var canCreateRoutine: Bool {
        subscriptionManager.isProUser || viewModel.routines.count < SubscriptionManager.freeRoutineLimit
    }

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.appAccent)
                        Text("Loading routines...")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 14) {
                        IconBadge(assetName: "exclamation-triangle", color: .red, size: 48)
                        Text("Something went wrong")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                        PrimaryCTAButton("Retry", systemIcon: "arrow.clockwise") {
                            Task { await viewModel.loadRoutines() }
                        }
                        .frame(width: 160)
                    }
                    .padding()
                } else if viewModel.routines.isEmpty {
                    VStack(spacing: 16) {
                        IconBadge(
                            systemName: "figure.strengthtraining.traditional",
                            size: 56
                        )
                        Text("No Routines Yet")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.appText)
                        Text("Create your first workout routine")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        PrimaryCTAButton("Create Routine", icon: "plus") {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            if canCreateRoutine {
                                showingCreateSheet = true
                            } else {
                                showingPaywall = true
                            }
                        }
                        .frame(width: 220)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Header with new routine and edit buttons
                        HStack {
                            Button {
                                if isEditMode {
                                    withAnimation(.spring(response: 0.3)) {
                                        isEditMode = false
                                    }
                                }
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
                                if canCreateRoutine {
                                    showingCreateSheet = true
                                } else {
                                    showingPaywall = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image("plus")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                    Text("New Routine")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(LinearGradient.accentGradient, in: Capsule())
                            }
                            .buttonStyle(ScalePressStyle())

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    isEditMode.toggle()
                                }
                            } label: {
                                Text(isEditMode ? "Done" : "Edit")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                        ScrollView {
                            LazyVStack(spacing: 10) {
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
                        .contentMargins(.bottom, tabBarBottomInset, for: .scrollContent)
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
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
        .alert("Delete Routine", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let routine = routineToDelete {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.warning)
                    Task {
                        await viewModel.deleteRoutine(routine)

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
                Text("Are you sure you want to delete '\(routine.name)'? All past workouts related to the routine will not be deleted. This action cannot be undone.")
            }
        }
        .task {
            if !viewModel.hasLoaded {
                await viewModel.loadRoutines()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDataChanged)) { _ in
            Task { await viewModel.loadRoutines() }
        }
    }
}

struct CreateRoutineSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: RoutineListViewModel
    let onRoutineCreated: (Routine) -> Void
    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, notes }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        IconBadge(assetName: "plus-circle", color: .appAccent, size: 48)

                        Text("New Routine")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)

                        Text("Give your routine a name to get started")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Form fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Routine Name")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)
                                .padding(.horizontal, 4)

                            TextField("e.g. Push Day, Upper Body", text: $name)
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
                    PrimaryCTAButton("Create Routine", icon: "check") {
                        isCreating = true
                        Task {
                            if let newRoutine = await viewModel.createRoutine(name: name, description: description) {
                                onRoutineCreated(newRoutine)
                                dismiss()
                            }
                            isCreating = false
                        }
                    }
                    .opacity(name.isEmpty ? 0.5 : 1.0)
                    .disabled(name.isEmpty || isCreating)
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
            .onAppear {
                focusedField = .name
            }
        }
        .presentationBackground(Color.appBackground)
    }
}

struct RoutineCard: View {
    let routine: Routine
    let exerciseCount: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(
                systemName: "figure.strengthtraining.traditional",
                color: .appAccent,
                size: 40
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }

            Spacer()

            Image("chevron-right")
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(Color.appTertiaryText)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }
                .shadow(
                    color: colorScheme == .light
                        ? Color.black.opacity(0.06)
                        : Color.clear,
                    radius: 10,
                    x: 0,
                    y: 4
                )
        }
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
            if isEditMode {
                Button {
                    onDelete()
                } label: {
                    Image("minus-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.red)
                }
                .transition(.scale.combined(with: .opacity))
            }

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
            .buttonStyle(ScalePressStyle())
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

    private var userCalendar: Calendar {
        viewModel.userCalendar
    }

    private var calendarItems: [CalendarItem] {
        viewModel.calendarDays.enumerated().map { index, date in
            CalendarItem(id: index, date: date)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Day headers
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.appTertiaryText)
                        .textCase(.uppercase)
                }
            }

            // Calendar days — fixed height for 6 rows so layout doesn't jump between months
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(calendarItems) { item in
                    if let date = item.date {
                        CalendarDayView(
                            calendar: userCalendar,
                            date: date,
                            isSelected: userCalendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: userCalendar.isDate(date, inSameDayAs: Date()),
                            hasWorkout: viewModel.hasScheduledWorkout(on: date),
                            isCompleted: viewModel.isWorkoutCompleted(on: date)
                        )
                        .onTapGesture {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                            onDateSelected(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
            // 6 rows × 48pt + 5 gaps × 10pt = 338pt
            .frame(height: 338, alignment: .top)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// Helper struct for calendar items with stable identity
private struct CalendarItem: Identifiable {
    let id: Int
    let date: Date?
}

struct CalendarDayView: View {
    let calendar: Calendar
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkout: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Selected: filled circle
                if isSelected {
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 36, height: 36)
                } else if isToday {
                    // Today (not selected): thin orange ring
                    Circle()
                        .strokeBorder(Color.appAccent, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : Color.appText)
            }
            .frame(width: 36, height: 36)

            // Workout dot indicator
            if hasWorkout {
                Circle()
                    .fill(isCompleted ? Color.green : (isSelected ? Color.appAccent : Color.appAccent.opacity(0.6)))
                    .frame(width: 5, height: 5)
            } else {
                Color.clear
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 48)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
    }
}
