//
//  LandingView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct LandingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showSignIn = false
    @State private var showSignUp = false
    
    var body: some View {
            NavigationStack{
                ZStack{
                    Color.appBackground
                    .ignoresSafeArea()
                    VStack{
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(Color.appText)
                            .font(.system(size: 60))
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 100)
                    VStack{
                        Spacer()
                        NavigationLink(destination: RegisterView(authViewModel: authViewModel)) {
                            Text("Sign Up")
                                .font(.headline)
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(5)
                                .contentShape(Rectangle())
                        }
                        .padding(.bottom, 10)
                        .padding(.leading, 40)
                        .padding(.trailing, 40)
                        HStack{
                            Text("Already a member?")
                                .foregroundStyle(Color.appText)
                            NavigationLink("Sign In", destination: LoginView(authViewModel: authViewModel))
                                .foregroundStyle(Color.appAccent)
                                .underline()
                        }
                        .font(.headline)
                        .padding(.bottom, 50)
                }
            }
        }
    }
}


//#Preview {
 //   LandingView()
//}
