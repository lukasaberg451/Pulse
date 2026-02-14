//
//  ContentView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    var body: some View {
        Group{
            if authViewModel.isAuthenticated {
                HomeView(authViewModel: authViewModel)
            } else {
                LandingView(authViewModel: authViewModel)
            }
        }
        .task {
            await authViewModel.getInitialSession()
        }
    }
}


#Preview {
    ContentView()
}
