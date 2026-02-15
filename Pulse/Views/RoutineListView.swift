//
//  RoutineListView.swift
//  Pulse
//
//  Created by lukasaberg on 2/8/26.
//

import SwiftUI

struct RoutineListView: View {
    @StateObject private var viewModel = RoutineListViewModel()
    @State private var showingCreateSheet = false
    
    var body: some View {
        NavigationStack{
            Group{
                if viewModel.isLoading {
                    ProgressView("Loading routines...")
                } else if let error = viewModel.errorMessage {
                    VStack{
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.loadRoutines() }
                        }
                    }
                    .padding()
                } else if viewModel.routines.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.secondary)
                        Text("No Routines Yet")
                            .font(.headline)
                        Text("Create your first workout routine")
                            .foregroundStyle(Color.secondary)
                        Button("Create Routine") {
                            showingCreateSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(viewModel.routines) { routine in
                            NavigationLink(destination: RoutineDetailView(routine: routine)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(routine.name)
                                        .font(.headline)
                                    if let description = routine.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                                .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { IndexSet in
                            for index in IndexSet {
                                let routines = viewModel.routines[index]
                                Task {
                                    await viewModel.deleteRoutine(routines)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Routines")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateRoutineSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadRoutines()
            }
        }
    }
}

struct CreateRoutineSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: RoutineListViewModel
    
    @State private var name = ""
    @State private var description = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Routine Name")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("", text: $name)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("Optional", text: $description, axis: .vertical)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
                            .lineLimit(3...6)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createRoutine(name: name, descritpion: description)
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color(name.isEmpty ? Color.appText.opacity(0.3) : Color.appAccent))
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
