//
//  ProfileView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var authViewModel : AuthViewModel
    var body: some View {
        ZStack{
            Color.appBackground
                .ignoresSafeArea()
            Button("Sign-Out"){
                Task {
                    await authViewModel.signOut()
                }
            }
            .foregroundStyle(Color.appAccent)
        }
    }
}

//#Preview {
  //  ProfileView()
//}
