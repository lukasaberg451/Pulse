//
//  DashboardView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject var authViewModel : AuthViewModel
    @State private var showingGoalSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack {
                        VStack {
                            Text("Welcome \(authViewModel.firstName)!")
                                .foregroundStyle(Color.appAccent)
                                .font(.title2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 30)
                        .padding(.leading, 15)
                        VStack {
                            DayGreetingView()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 15)
                        
                        
                        VStack {
                            WeeklyGoalCard(
                                completedMinutes: viewModel.weeklyWorkoutMinutes,
                                goalMinutes: viewModel.weeklyGoalMinutes,
                                onEditGoal: {
                                    showingGoalSettings = true
                                }
                            )
                            .padding(.horizontal)
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
                                    if let routine = viewModel.routine(for: scheduled.routineId) {
                                        TodayWorkoutCard(
                                            routine: routine,
                                            scheduled: scheduled,
                                            routineExercises: viewModel.routineExercises(for: routine.id),
                                            exercises: viewModel.exercises
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Recent Workouts Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Workouts")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                                .padding(.horizontal)
                            
                            if viewModel.recentSessions.isEmpty {
                                EmptyRecentCard()
                            } else {
                                ForEach(viewModel.recentSessions) { session in
                                    RecentWorkoutCard(
                                        session: session,
                                        viewModel: viewModel
                                    )
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .task {
                await viewModel.loadData()
                await viewModel.loadWeeklyProgress()
            }
            .refreshable {
                await viewModel.loadData()
                await viewModel.loadWeeklyProgress()
            }
            .sheet(isPresented: $showingGoalSettings) {
                WeeklyGoalSheet(viewModel: viewModel)
            }
        }
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
                    showingActiveWorkout = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                        Text("Start")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.appAccent)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.green)
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(
                routine: routine,
                routineExercises: routineExercises,
                exercises: exercises,
                scheduledWorkoutId: scheduled.id
            )
        }
    }
}

struct EmptyTodayCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 50))
                .foregroundStyle(Color.appText.opacity(0.4))
            
            Text("No workouts scheduled today")
                .font(.subheadline)
                .foregroundStyle(Color.appText.opacity(0.6))
            
            NavigationLink(destination: WorkoutView()) {
                Text("Schedule a workout")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.appAccent)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(Color.appSurface)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct RecentWorkoutCard: View {
    let session: WorkoutSession
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        NavigationLink(destination: Text("Workout Detail - TODO")) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.name)
                        .font(.headline)
                        .foregroundStyle(Color.appText)
                    
                    HStack(spacing: 12) {
                        Label(viewModel.formatDate(session.startedAt), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(Color.appText.opacity(0.6))
                        
                        if session.completedAt != nil {
                            Label(viewModel.formatDuration(session.durationSeconds), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(Color.appText.opacity(0.6))
                        }
                    }
                    
                    if session.completedAt != nil {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.green)
                    } else {
                        Label("In Progress", systemImage: "circle.dotted")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.appText.opacity(0.3))
                    .font(.system(size: 14))
            }
            .padding(16)
            .background(Color.appSurface)
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyRecentCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundStyle(Color.appText.opacity(0.4))
            
            Text("No workout history yet")
                .font(.subheadline)
                .foregroundStyle(Color.appText.opacity(0.6))
            
            Text("Complete your first workout to see it here")
                .font(.caption)
                .foregroundStyle(Color.appText.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(Color.appSurface)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct DayGreetingView: View {
    var body: some View {
        Text(dailyMessage)
            .font(.system(size: 15))
            .bold()
            .foregroundStyle(Color.appAccent)
    }
    var dailyMessage: String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        
        switch weekday {
        case 1: return "Reset Sunday!"
        case 2: return "Mighty Monday!"
        case 3: return "Tackling Tuesday!"
        case 4: return "Winning Wednesday!"
        case 5: return "Thunder Thursday!"
        case 6: return "Focused Friday!"
        case 7: return "Sweet Saturday!"
        default: return "Hello!"
        }
    }
}
