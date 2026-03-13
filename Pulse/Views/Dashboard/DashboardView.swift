//
//  DashboardView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import SwiftData
import PostHog

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject var milestoneViewModel: MilestoneViewModel
    @StateObject var authViewModel : AuthViewModel
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @ObservedObject var routineListViewModel: RoutineListViewModel
    @State private var showingGoalSettings = false
    @State private var goalBeforeEdit: Int = 0
    @State private var celebrateGoalUpdate = false
    @State private var hasAppeared = false
    @State private var sectionAppeared: [Bool] = [false, false, false]
    @State private var triggerStreakHighlight = false
    @Environment(\.splashDismissed) private var splashDismissed
    
    // In-progress workout recovery
    @Environment(\.modelContext) private var modelContext
    @State private var inProgressSession: LocalWorkoutSession?
    @State private var resumeRoutine: Routine?
    @State private var resumeRoutineExercises: [RoutineExercise] = []
    @State private var resumeExercises: [Exercise] = []
    @State private var showingResumeWorkout = false
    @State private var showingResumeAlert = false
    @State private var pendingResumeAlert = false
    @Environment(\.tabBarBottomInset) private var tabBarBottomInset
    @EnvironmentObject var syncService: WorkoutSyncService
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle vertical gradient background
                LinearGradient.dashboardBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Offline Banner
                        OfflineStatusBanner(subtitle: "Workouts can only be started from the routine during offline mode. Your workout will sync when you're back online.")
                            .animation(.easeInOut, value: syncService.isOnline)
                        
                        // MARK: - Hero Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Welcome \(authViewModel.firstName)!")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appText)

                            Text(viewModel.formattedToday)
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 40)
                        .padding(.horizontal)
                        .opacity(sectionAppeared[0] ? 1 : 0)
                        .offset(y: sectionAppeared[0] ? 0 : 18)

                        // MARK: - Stats Bar
                        StatsBar(
                            streak: viewModel.currentStreak,
                            totalWorkouts: viewModel.totalWorkoutCount,
                            weeklyMinutes: viewModel.weeklyWorkoutMinutes,
                            triggerHighlight: triggerStreakHighlight
                        )
                        .spotlightTarget("statsBar")
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .opacity(sectionAppeared[0] ? 1 : 0)
                        .offset(y: sectionAppeared[0] ? 0 : 18)

                        // MARK: - Today Section
                        VStack(alignment: .leading, spacing: 14) {
                            DashboardSectionHeader(title: "Today")

                            if viewModel.todaysWorkouts.isEmpty {
                                EmptyTodayCard(
                                    scheduleViewModel: scheduleViewModel,
                                    routineListViewModel: routineListViewModel
                                )
                                .transition(.opacity)
                            } else {
                                ForEach(viewModel.todaysWorkouts) { scheduled in
                                    if let routineId = scheduled.routineId,
                                       let routine = viewModel.routine(for: routineId) {
                                        TodayWorkoutCard(
                                            routine: routine,
                                            scheduled: scheduled,
                                            routineExercises: viewModel.routineExercises(for: routine.id),
                                            exercises: viewModel.exercises
                                        )
                                    } else if scheduled.routineDeleted == true || scheduled.routineId == nil {
                                        DeletedRoutineTodayCard(
                                            scheduled: scheduled,
                                            workoutName: viewModel.sessionName(for: scheduled)
                                        )
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: viewModel.todaysWorkouts.isEmpty)
                        .padding(.top, 24)
                        .opacity(sectionAppeared[1] ? 1 : 0)
                        .offset(y: sectionAppeared[1] ? 0 : 18)

                        // MARK: - Progress Section
                        VStack(spacing: 14) {
                            WeeklyGoalCard(
                                completedMinutes: viewModel.weeklyWorkoutMinutes,
                                goalMinutes: viewModel.weeklyGoalMinutes,
                                onEditGoal: {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    goalBeforeEdit = viewModel.weeklyGoalMinutes
                                    showingGoalSettings = true
                                },
                                celebrate: celebrateGoalUpdate
                            )
                            .spotlightTarget("weeklyGoal")
                            .padding(.horizontal)

                            if let dashboardMilestone = milestoneViewModel.dashboardMilestone {
                                MilestoneCard(milestone: dashboardMilestone, viewModel: milestoneViewModel)
                                    .id(dashboardMilestone.id)
                                    .padding(.horizontal)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.top, 20)
                        .opacity(sectionAppeared[2] ? 1 : 0)
                        .offset(y: sectionAppeared[2] ? 0 : 18)
                    }
                    .animation(.easeOut(duration: 0.35), value: viewModel.todaysWorkouts.count)
                }
                .contentMargins(.bottom, tabBarBottomInset, for: .scrollContent)
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                for index in sectionAppeared.indices {
                    withAnimation(.easeOut(duration: 0.45).delay(0.1 + Double(index) * 0.1)) {
                        sectionAppeared[index] = true
                    }
                }
            }
            .onChange(of: splashDismissed) { _, dismissed in
                guard dismissed else { return }
                if !triggerStreakHighlight {
                    // Small delay after splash fades so the pill entrance animation finishes first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        triggerStreakHighlight = true
                    }
                }
                if pendingResumeAlert {
                    pendingResumeAlert = false
                    // Show the resume alert after a short delay so splash exit animation finishes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingResumeAlert = true
                    }
                }
            }
            .task {
                await viewModel.refreshAll()
                await checkForInProgressWorkout()
            }
            .refreshable {
                await viewModel.refreshAll()
            }
            .sheet(isPresented: $showingGoalSettings, onDismiss: {
                if viewModel.weeklyGoalMinutes != goalBeforeEdit {
                    celebrateGoalUpdate = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        celebrateGoalUpdate = true
                    }
                }
            }) {
                WeeklyGoalSheet(viewModel: viewModel)
                    .sheetContentTransition()
            }
            .alert("Resume Workout?", isPresented: $showingResumeAlert) {
                Button("Resume", role: .cancel) {
                    showingResumeWorkout = true
                }
                Button("Discard", role: .destructive) {
                    discardInProgressWorkout()
                }
            } message: {
                if let session = inProgressSession {
                    let minutes = Int(Date().timeIntervalSince(session.startedAt)) / 60
                    Text("You have an unfinished \"\(session.name)\" workout from \(minutes) minutes ago. Would you like to continue?")
                }
            }
            .fullScreenCover(isPresented: $showingResumeWorkout) {
                if let routine = resumeRoutine, let session = inProgressSession {
                    ActiveWorkoutView(
                        routine: routine,
                        routineExercises: resumeRoutineExercises,
                        exercises: resumeExercises,
                        scheduledWorkoutId: nil,
                        workoutSessionId: nil,
                        resumingSession: session
                    )
                }
            }
        }
    }
    
    private func checkForInProgressWorkout() async {
        let repository = OfflineWorkoutRepository(modelContext: modelContext)
        
        guard let session = try? repository.fetchInProgressSession() else { return }
        guard let routineId = session.routineId else { return }
        
        do {
            let exerciseRepo = OfflineExerciseRepository(modelContext: modelContext)
            let routines = try await exerciseRepo.getRoutines()
            guard let routine = routines.first(where: { $0.id == routineId }) else {
                // Routine was deleted — discard the orphaned session
                repository.deleteSession(session)
                return
            }
            
            let routineExercises = try await exerciseRepo.getRoutineExercises(routineId: routineId)
            let exercises = try exerciseRepo.getCachedExercises()
            
            self.inProgressSession = session
            self.resumeRoutine = routine
            self.resumeRoutineExercises = routineExercises
            self.resumeExercises = exercises
            if splashDismissed {
                self.showingResumeAlert = true
            } else {
                self.pendingResumeAlert = true
            }
        } catch {
            debugLog("⚠️ Failed to load data for in-progress workout: \(error)")
        }
    }
    
    private func discardInProgressWorkout() {
        guard let session = inProgressSession else { return }
        let repository = OfflineWorkoutRepository(modelContext: modelContext)
        repository.deleteSession(session)
        inProgressSession = nil
    }
}

struct TodayWorkoutCard: View {
    let routine: Routine
    let scheduled: ScheduledWorkout
    let routineExercises: [RoutineExercise]
    let exercises: [Exercise]

    @Environment(\.colorScheme) private var colorScheme
    @State private var showingActiveWorkout = false

    var body: some View {
        DashboardCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        IconBadge(assetName: "calendar", size: 28)
                        Text("Scheduled")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                    }

                    Text(routine.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.appText)

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
                    } else {
                        Text("Not started")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Spacer()

                if !scheduled.completed {
                    Button {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        showingActiveWorkout = true
                        PostHogSDK.shared.capture("scheduled_from_dashboard_started")
                    } label: {
                        VStack(spacing: 4) {
                            Image("play")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            Text("Start")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(ScalePressStyle())
                } else {
                    Image("check-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.green)
                }
            }
        }
        .spotlightTarget("todaySection")
        .padding(.horizontal)
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(
                routine: routine,
                routineExercises: routineExercises,
                exercises: exercises,
                scheduledWorkoutId: scheduled.id,
                workoutSessionId: scheduled.workoutSessionId
            )
        }
    }
}

struct DeletedRoutineTodayCard: View {
    let scheduled: ScheduledWorkout
    let workoutName: String

    var body: some View {
        DashboardCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        IconBadge(assetName: "calendar", size: 28)
                        Text("Scheduled")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                    }

                    Text(workoutName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.appText)

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
                    } else {
                        HStack(spacing: 4) {
                            Image("trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                            Text("Routine deleted")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.appTertiaryText)
                    }
                }

                Spacer()

                if scheduled.completed {
                    Image("check-circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct EmptyTodayCard: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @ObservedObject var routineListViewModel: RoutineListViewModel
    @State private var showingRoutinePicker = false

    var body: some View {
        DashboardCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        IconBadge(assetName: "calendar", size: 28)
                        Text("Today")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                    }

                    Text("No workouts scheduled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    Text("Plan your training for today")
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }

                Spacer()

                Button {
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    showingRoutinePicker = true
                } label: {
                    VStack(spacing: 4) {
                        Image("plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                        Text("Add")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(ScalePressStyle())
            }
        }
        .spotlightTarget("todaySection")
        .padding(.horizontal)
        .sheet(isPresented: $showingRoutinePicker) {
            RoutinePickerSheet(
                viewModel: scheduleViewModel,
                selectedDate: Date()
            )
            .sheetContentTransition()
        }
    }
}

// MARK: - Stats Bar

struct StatsBar: View {
    let streak: Int
    let totalWorkouts: Int
    let weeklyMinutes: Int
    var triggerHighlight: Bool = false

    @State private var hasPlayedInitial = false
    @State private var isAnimating = false
    @State private var waveOffset: CGFloat = -1.5

    var body: some View {
        DashboardCard {
            HStack(spacing: 0) {
                StatBarItem(
                    icon: "flame",
                    value: "\(streak)",
                    label: "Daily Streak"
                )

                StatBarDivider()

                StatBarItem(
                    icon: "check-circle",
                    value: "\(totalWorkouts)",
                    label: "Workouts"
                )

                StatBarDivider()

                StatBarItem(
                    icon: "stopwatch",
                    value: formattedWeeklyTime,
                    label: "This Week"
                )
            }
        }
        .overlay {
            GeometryReader { geo in
                // Wave shimmer that sweeps from top-right to bottom-left
                let waveWidth = geo.size.width * 0.6
                LinearGradient(
                    stops: [
                        .init(color: Color.appAccent.opacity(0), location: 0),
                        .init(color: Color.appAccent.opacity(0.18), location: 0.4),
                        .init(color: Color.appAccent.opacity(0.25), location: 0.5),
                        .init(color: Color.appAccent.opacity(0.18), location: 0.6),
                        .init(color: Color.appAccent.opacity(0), location: 1)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(width: waveWidth)
                .blur(radius: 12)
                .offset(x: waveOffset * geo.size.width)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .allowsHitTesting(false)
        }
        .onTapGesture {
            guard !isAnimating else { return }
            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
            runWave()
        }
        .onChange(of: triggerHighlight) { _, newValue in
            guard newValue, !hasPlayedInitial else { return }
            hasPlayedInitial = true
            runWave()
        }
    }

    private var formattedWeeklyTime: String {
        let hours = weeklyMinutes / 60
        let minutes = weeklyMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func runWave() {
        isAnimating = true
        waveOffset = -1.5
        withAnimation(.easeInOut(duration: 2.0)) {
            waveOffset = 1.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isAnimating = false
            waveOffset = -1.5
        }
    }
}

private struct StatBarItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.appAccent)

                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appText)
            }

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.appSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatBarDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(Color.appSecondaryText.opacity(0.2))
            .frame(width: 1, height: 40)
    }
}

