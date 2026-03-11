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
    @State private var hasAppeared = false
    
    // In-progress workout recovery
    @Environment(\.modelContext) private var modelContext
    @State private var inProgressSession: LocalWorkoutSession?
    @State private var resumeRoutine: Routine?
    @State private var resumeRoutineExercises: [RoutineExercise] = []
    @State private var resumeExercises: [Exercise] = []
    @State private var showingResumeWorkout = false
    @State private var showingResumeAlert = false
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

                            // Stat pills row
                            if viewModel.currentStreak > 0 {
                                StatPill(
                                    icon: "FlameIcon",
                                    value: "\(viewModel.currentStreak)",
                                    label: viewModel.currentStreak == 1 ? "day streak" : "day streak"
                                )
                                .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 40)
                        .padding(.horizontal)

                        // MARK: - Smart Insight
                        if let insight = viewModel.currentInsight {
                            SmartInsightCard(insight: insight)
                                .padding(.top, 12)
                                .onTapGesture {
                                    viewModel.advanceInsight()
                                    viewModel.startInsightRotation()
                                }
                        }

                        // MARK: - Today Section
                        VStack(alignment: .leading, spacing: 14) {
                            DashboardSectionHeader(title: "Today")

                            if viewModel.todaysWorkouts.isEmpty {
                                EmptyTodayCard(
                                    scheduleViewModel: scheduleViewModel,
                                    routineListViewModel: routineListViewModel
                                )
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
                            }
                        }
                        .padding(.top, 24)

                        // MARK: - Progress Section
                        VStack(spacing: 14) {
                            WeeklyGoalCard(
                                completedMinutes: viewModel.weeklyWorkoutMinutes,
                                goalMinutes: viewModel.weeklyGoalMinutes,
                                onEditGoal: {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingGoalSettings = true
                                }
                            )
                            .padding(.horizontal)

                            if let nextMilestone = milestoneViewModel.nextMilestone {
                                MilestoneCard(milestone: nextMilestone)
                                    .padding(.horizontal)
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.top, 20)
                    }
                    // Card entrance animation
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)
                }
                .contentMargins(.bottom, tabBarBottomInset, for: .scrollContent)
            }
            .onAppear {
                viewModel.startInsightRotation()
                withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
                    hasAppeared = true
                }
            }
            .onDisappear {
                viewModel.stopInsightRotation()
            }
            .task {
                await viewModel.refreshAll(includeInsights: true)
                await checkForInProgressWorkout()
            }
            .refreshable {
                await viewModel.refreshAll(includeInsights: true)
            }
            .sheet(isPresented: $showingGoalSettings) {
                WeeklyGoalSheet(viewModel: viewModel)
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
            self.showingResumeAlert = true
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
                        IconBadge(assetName: "calendar-days", size: 28)
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
                            Image("play-circle")
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
                        IconBadge(assetName: "calendar-days", size: 28)
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

    var body: some View {
        DashboardCard {
            VStack(spacing: 16) {
                IconBadge(assetName: "calendar-days", size: 52)
                    .padding(.top, 4)

                VStack(spacing: 4) {
                    Text("No workouts scheduled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)
                    Text("Plan your training for today")
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }

                PrimaryCTALink("Schedule a workout", icon: "plus") {
                    WorkoutView(
                        scheduleViewModel: scheduleViewModel,
                        routineListViewModel: routineListViewModel
                    )
                    .hidesTabBar()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
    }
}

struct SmartInsightCard: View {
    let insight: SmartInsight

    var body: some View {
        HStack(spacing: 10) {
            if insight.isSystemImage {
                IconBadge(systemName: insight.icon, color: insight.accentColor, size: 32)
            } else {
                IconBadge(assetName: insight.icon, color: insight.accentColor, size: 32)
            }

            Text(insight.text)
                .font(.subheadline)
                .foregroundStyle(Color.appText.opacity(0.8))
                .lineLimit(2)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 44)
        .clipped()
        .id(insight.id)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }
}
