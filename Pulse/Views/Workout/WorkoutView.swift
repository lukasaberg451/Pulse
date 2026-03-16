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
    @EnvironmentObject var tourManager: OnboardingTourManager
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
            .onChange(of: tourManager.currentIndex) { _, _ in
                guard let step = tourManager.currentStep,
                      let subTab = step.workoutSubTab else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    selectedTab = subTab
                }
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
    @State private var isSelectMode = false
    @State private var selectedScheduledIds: Set<UUID> = []
    @State private var showingDeleteAlert = false
    @State private var monthChangeDirection: Edge = .trailing
    @Environment(\.tabBarBottomInset) private var tabBarBottomInset

    private var selectedScheduledWorkouts: [ScheduledWorkout] {
        viewModel.scheduledWorkouts(for: selectedDate).filter { selectedScheduledIds.contains($0.id) }
    }

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
                        isSelectMode: $isSelectMode,
                        selectedScheduledIds: $selectedScheduledIds,
                        showingRoutinePicker: $showingRoutinePicker,
                        showingDeleteAlert: $showingDeleteAlert
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
            .sheetContentTransition()
        }
        .alert("Remove Workout\(selectedScheduledIds.count == 1 ? "" : "s")", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                let workouts = selectedScheduledWorkouts
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.warning)
                Task {
                    let ids = Set(workouts.map(\.id))
                    await viewModel.deleteScheduledWorkouts(workouts)

                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.removeScheduledLocally(ids)
                        selectedScheduledIds.removeAll()
                        isSelectMode = false
                    }
                }
            }
        } message: {
            if selectedScheduledIds.count == 1, let scheduled = selectedScheduledWorkouts.first,
               let routineId = scheduled.routineId,
               let routine = viewModel.routine(for: routineId) {
                Text("Are you sure you want to remove '\(routine.name)' from your schedule?")
            } else {
                Text("Are you sure you want to remove \(selectedScheduledIds.count) workouts from your schedule?")
            }
        }
        .onChange(of: selectedDate) {
            if isSelectMode {
                withAnimation {
                    selectedScheduledIds.removeAll()
                    isSelectMode = false
                }
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
    @Binding var isSelectMode: Bool
    @Binding var selectedScheduledIds: Set<UUID>
    @Binding var showingRoutinePicker: Bool
    @Binding var showingDeleteAlert: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var workouts: [ScheduledWorkout] {
        viewModel.scheduledWorkouts(for: selectedDate)
    }
    
    private var uncompletedWorkouts: [ScheduledWorkout] {
        workouts.filter { !$0.completed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                if isSelectMode {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isSelectMode = false
                            selectedScheduledIds.removeAll()
                        }
                    } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                    }
                } else {
                    Text("Scheduled for \(viewModel.formattedDate(selectedDate))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)
                }

                Spacer()

                if isSelectMode {
                    Button {
                        if selectedScheduledIds.isEmpty { return }
                        showingDeleteAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image("trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                            Text("Delete\(selectedScheduledIds.isEmpty ? "" : " (\(selectedScheduledIds.count))")")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            selectedScheduledIds.isEmpty
                                ? Color.red.opacity(0.4)
                                : Color.red,
                            in: Capsule()
                        )
                    }
                    .buttonStyle(ScalePressStyle())
                    .disabled(selectedScheduledIds.isEmpty)
                } else if !workouts.isEmpty && uncompletedWorkouts.count > 0 {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isSelectMode = true
                        }
                    } label: {
                        Text("Modify")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }

            if workouts.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    IconBadge(assetName: "calendar", size: 44)

                    Text("No workouts scheduled")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)

                    PrimaryCTAButton("Add Workout", icon: "plus") {
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
                                isSelectMode: isSelectMode,
                                isSelected: selectedScheduledIds.contains(scheduled.id),
                                exerciseCount: viewModel.exerciseCount(for: routine.id),
                                viewModel: viewModel,
                                onTap: {
                                    if isSelectMode && !scheduled.completed {
                                        withAnimation(.spring(response: 0.25)) {
                                            if selectedScheduledIds.contains(scheduled.id) {
                                                selectedScheduledIds.remove(scheduled.id)
                                            } else {
                                                selectedScheduledIds.insert(scheduled.id)
                                            }
                                        }
                                    }
                                }
                            )
                        } else if scheduled.routineDeleted == true || scheduled.routineId == nil {
                            DeletedRoutineWorkoutCard(
                                scheduled: scheduled,
                                viewModel: viewModel,
                                isSelectMode: isSelectMode,
                                isSelected: selectedScheduledIds.contains(scheduled.id),
                                onTap: {
                                    if isSelectMode && !scheduled.completed {
                                        withAnimation(.spring(response: 0.25)) {
                                            if selectedScheduledIds.contains(scheduled.id) {
                                                selectedScheduledIds.remove(scheduled.id)
                                            } else {
                                                selectedScheduledIds.insert(scheduled.id)
                                            }
                                        }
                                    }
                                }
                            )
                        }
                    }

                    // Inline add button
                    if !isSelectMode {
                        Button {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            showingRoutinePicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image("plus")
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
    let isSelectMode: Bool
    let isSelected: Bool
    let exerciseCount: Int
    @ObservedObject var viewModel: ScheduleViewModel
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showingActiveWorkout = false

    var body: some View {
        HStack(spacing: 12) {
            if isSelectMode && !scheduled.completed {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.appAccent : Color.appTertiaryText, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 24, height: 24)
                        
                        Image("check")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.white)
                    }
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
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectMode && !scheduled.completed {
                onTap()
            }
        }
        .animation(.spring(response: 0.3), value: isSelectMode)
        .animation(.spring(response: 0.25), value: isSelected)
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
                assetName: "workout",
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
                        .background(
                            (isSelectMode || exerciseCount == 0)
                                ? LinearGradient.accentGradient.opacity(0.4)
                                : LinearGradient.accentGradient.opacity(1),
                            in: Capsule()
                        )
                }
                .buttonStyle(ScalePressStyle())
                .disabled(isSelectMode || exerciseCount == 0)
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
    let isSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void

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
            if isSelectMode && !scheduled.completed {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.appAccent : Color.appTertiaryText, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 24, height: 24)
                        
                        Image("check")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.white)
                    }
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
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectMode && !scheduled.completed {
                onTap()
            }
        }
        .animation(.spring(response: 0.3), value: isSelectMode)
        .animation(.spring(response: 0.25), value: isSelected)
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
                            assetName: "routine",
                            size: 56
                        )
                        Text("No Routines Yet")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        Text("Go to the Workout tab to create your first routine")
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
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
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
    @State private var isSelected = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isSelected = true
            }
            onSelect()
        } label: {
            HStack(spacing: 12) {
                IconBadge(
                    assetName: isSelected ? "check" : "routine",
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

                if isSelected {
                    ProgressView()
                        .tint(Color.appAccent)
                } else {
                    Image("plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.appAccent.opacity(0.12) : Color.appSurface)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1.5)
                        } else if colorScheme == .dark {
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
        .buttonStyle(RoutinePickerPressStyle())
        .disabled(isSelected)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }
}

struct RoutinePickerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Routines tab content
struct RoutineContentView: View {
    @ObservedObject var viewModel: RoutineListViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingCreateSheet = false
    @State private var showingPaywall = false
    @State private var isSelectMode = false
    @State private var selectedRoutineIds: Set<UUID> = []
    @State private var showingDeleteAlert = false
    @State private var animateList = false
    @Binding var routineToNavigateTo: Routine?
    @Environment(\.tabBarBottomInset) private var tabBarBottomInset

    private var canCreateRoutine: Bool {
        subscriptionManager.isProUser || viewModel.routines.count < SubscriptionManager.freeRoutineLimit
    }
    
    private var selectedRoutines: [Routine] {
        viewModel.routines.filter { selectedRoutineIds.contains($0.id) }
    }

    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()

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
                    IconBadge(assetName: "error", color: .red, size: 48)
                    Text("Something went wrong")
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                        .multilineTextAlignment(.center)
                    PrimaryCTAButton("Retry", icon: "refresh") {
                        Task { await viewModel.loadRoutines() }
                    }
                    .frame(width: 160)
                }
                .padding()
            } else if !viewModel.routines.isEmpty {
                    VStack(spacing: 0) {
                        // Header with new routine and select/delete buttons
                        HStack {
                            if isSelectMode {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        isSelectMode = false
                                        selectedRoutineIds.removeAll()
                                    }
                                } label: {
                                    Text("Cancel")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                            } else {
                                Button {
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
                            }

                            Spacer()

                            if isSelectMode {
                                Button {
                                    if selectedRoutineIds.isEmpty { return }
                                    showingDeleteAlert = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image("trash")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 12, height: 12)
                                        Text("Delete\(selectedRoutineIds.isEmpty ? "" : " (\(selectedRoutineIds.count))")")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .background(
                                        selectedRoutineIds.isEmpty
                                            ? Color.red.opacity(0.4)
                                            : Color.red,
                                        in: Capsule()
                                    )
                                }
                                .buttonStyle(ScalePressStyle())
                                .disabled(selectedRoutineIds.isEmpty)
                            } else {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        isSelectMode = true
                                    }
                                } label: {
                                    Text("Modify")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                        ScrollView {
                            LazyVStack(spacing: 10) {
                                StaggeredList(
                                    items: viewModel.routines,
                                    id: \.id,
                                    staggerDelay: 0.08,
                                    initialDelay: 0.1
                                ) { routine in
                                    RoutineRow(
                                        routine: routine,
                                        isSelectMode: isSelectMode,
                                        isSelected: selectedRoutineIds.contains(routine.id),
                                        exerciseCount: viewModel.exerciseCount(for: routine.id),
                                        onTap: {
                                            if isSelectMode {
                                                withAnimation(.spring(response: 0.25)) {
                                                    if selectedRoutineIds.contains(routine.id) {
                                                        selectedRoutineIds.remove(routine.id)
                                                    } else {
                                                        selectedRoutineIds.insert(routine.id)
                                                    }
                                                }
                                            } else {
                                                routineToNavigateTo = routine
                                            }
                                        }
                                    )
                                }
                            }
                            .id(animateList)
                            .padding(16)
                        }
                        .contentMargins(.bottom, tabBarBottomInset, for: .scrollContent)
                    }
                }
        }
        .overlay {
            if !viewModel.isLoading && viewModel.errorMessage == nil && viewModel.routines.isEmpty && viewModel.hasLoaded {
                VStack(spacing: 16) {
                    IconBadge(
                        assetName: "routine",
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
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.routines.isEmpty)
        .sheet(isPresented: $showingCreateSheet) {
            CreateRoutineSheet(
                viewModel: viewModel,
                onRoutineCreated: { routine in
                    routineToNavigateTo = routine
                }
            )
            .sheetContentTransition()
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
                .sheetContentTransition()
        }
        .alert("Delete Routine\(selectedRoutineIds.count == 1 ? "" : "s")", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let routines = selectedRoutines
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.warning)
                Task {
                    selectedRoutineIds.removeAll()
                    isSelectMode = false
                    await viewModel.deleteRoutines(routines)
                }
            }
        } message: {
            if selectedRoutineIds.count == 1, let routine = selectedRoutines.first {
                Text("Are you sure you want to delete '\(routine.name)'? All past workouts related to the routine will not be deleted. This action cannot be undone.")
            } else {
                Text("Are you sure you want to delete \(selectedRoutineIds.count) routines? All past workouts related to these routines will not be deleted. This action cannot be undone.")
            }
        }
        .task {
            if !viewModel.hasLoaded {
                await viewModel.loadRoutines()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDataChanged)) { notification in
            // Skip reload if this ViewModel posted the notification (local state is already up to date)
            if notification.object as? RoutineListViewModel === viewModel { return }
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
                        IconBadge(assetName: "routine", color: .appAccent, size: 48)

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

                            HStack {
                                TextField("e.g. Push Day, Upper Body", text: $name)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .foregroundStyle(Color.appText)
                                    .focused($focusedField, equals: .name)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .notes }
                            }
                            .padding(14)
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
                            .contentShape(Rectangle())
                            .onTapGesture { focusedField = .name }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Notes (Optional)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                                    .padding(.horizontal, 4)

                                Spacer()

                                Text("\(description.count)/256")
                                    .font(.caption2)
                                    .foregroundStyle(description.count >= 256 ? Color.red : Color.appTertiaryText)
                                    .padding(.horizontal, 4)
                            }

                            HStack(alignment: .top) {
                                TextField("Add a description or notes", text: $description, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .foregroundStyle(Color.appText)
                                    .focused($focusedField, equals: .notes)
                                    .lineLimit(3...6)
                                    .onChange(of: description) { _, newValue in
                                        if newValue.count > 256 {
                                            description = String(newValue.prefix(256))
                                        }
                                    }
                            }
                            .padding(14)
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
                            .contentShape(Rectangle())
                            .onTapGesture { focusedField = .notes }
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
                assetName: "routine",
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
    let isSelectMode: Bool
    let isSelected: Bool
    let exerciseCount: Int
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                if isSelectMode {
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? Color.appAccent : Color.appTertiaryText, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 24, height: 24)
                            
                            Image("check")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(.white)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                RoutineCard(
                    routine: routine,
                    exerciseCount: exerciseCount
                )
            }
        }
        .buttonStyle(ScalePressStyle())
        .animation(.spring(response: 0.3), value: isSelectMode)
        .animation(.spring(response: 0.25), value: isSelected)
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
