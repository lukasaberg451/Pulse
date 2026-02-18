//
//  HomeView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel : AuthViewModel
    var body: some View {
        TabView{
            Tab("Dashboard", systemImage: "chart.bar.fill"){
                DashboardView(authViewModel: authViewModel)
            }
            Tab("Workout", systemImage: "dumbbell.fill"){
                WorkoutView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis"){
                ProgressTabView()
            }
            Tab("Profile", systemImage: "person.circle.fill"){
                ProfileView()
            }
        }
    }
}
