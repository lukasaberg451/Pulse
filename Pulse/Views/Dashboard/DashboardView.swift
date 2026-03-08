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
    @StateObject private var milestoneViewModel = MilestoneViewModel()
    @StateObject var authViewModel : AuthViewModel
    @State private var showingGoalSettings = false
    
    // In-progress workout recovery
    @Environment(\.modelContext) private var modelContext
    @State private var inProgressSession: LocalWorkoutSession?
    @State private var resumeRoutine: Routine?
    @State private var resumeRoutineExercises: [RoutineExercise] = []
    @State private var resumeExercises: [Exercise] = []
    @State private var showingResumeWorkout = false
    @State private var showingResumeAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack {
                        VStack{
                            Text("Welcome \(authViewModel.firstName)!")
                                .foregroundStyle(Color.appAccent)
                                .font(.title)
                            
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 40)
                        .padding(.horizontal)
                        
                        VStack {
                            Text(viewModel.formattedToday)
                                .foregroundStyle(Color.appText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                    
                    }
                    // Smart Insight
                    if let insight = viewModel.currentInsight {
                        SmartInsightCard(insight: insight)
                            .padding(.top, 8)
                            .onTapGesture {
                                viewModel.advanceInsight()
                                viewModel.startInsightRotation()
                            }
                    }
                    
                    VStack(spacing: 20) {
                        // Today's Workouts Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                                .padding(.horizontal)
                            
                            if viewModel.todaysWorkouts.isEmpty {
                                EmptyTodayCard()
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
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 12) {
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
            }
            .onAppear {
                viewModel.loadInsights()
                viewModel.startInsightRotation()
            }
            .onDisappear {
                viewModel.stopInsightRotation()
            }
            .task {
                await viewModel.refreshAll()
                await milestoneViewModel.loadMilestones()
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
            print("⚠️ Failed to load data for in-progress workout: \(error)")
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
    
    @State private var showingActiveWorkout = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.appAccent)
                    Text("Scheduled")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
                
                Text(routine.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appText)
                
                if scheduled.completed {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                } else {
                    Text("Not started")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
            }
            
            Spacer()
            
            if !scheduled.completed {
                Button{
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    showingActiveWorkout = true
                    PostHogSDK.shared.capture("scheduled_from_dashboard_started")
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                        Text("Start")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.appAccent)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.green)
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
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
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.appAccent)
                    Text("Scheduled")
                        .font(.caption)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
                
                Text(workoutName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appText)
                
                if scheduled.completed {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption2)
                        Text("Routine deleted")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.appText.opacity(0.4))
                }
            }
            
            Spacer()
            
            if scheduled.completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.green)
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct EmptyTodayCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.largeTitle)
                .foregroundStyle(Color.appAccent.opacity(0.4))
            
            Text("No workouts scheduled today")
                .font(.subheadline)
                .foregroundStyle(Color.appText.opacity(0.6))
            
            NavigationLink(destination: WorkoutView()) {
                Text("Schedule a workout")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.appAccent)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct SmartInsightCard: View {
    let insight: SmartInsight
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: insight.icon)
                .font(.callout)
                .foregroundStyle(insight.accentColor)
                .frame(width: 24)
            
            Text(insight.text)
                .font(.subheadline)
                .foregroundStyle(Color.appText.opacity(0.8))
                .lineLimit(2)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .clipped()
        .id(insight.id)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }
}
