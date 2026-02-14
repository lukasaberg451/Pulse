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
            Tab(Constants.progressString, systemImage: Constants.progressIconString){
                HomeProgressView()
                }
            Tab(Constants.workoutString, systemImage: Constants.workoutIconString){
                WorkoutView()
            }
            Tab(Constants.nutritionString, systemImage: Constants.nutritionIconString){
                NutritionView()
            }
            Tab(Constants.profileString, systemImage: Constants.profileIconString){
                ProfileView(authViewModel: authViewModel)
            }
        }
    
    }
}
