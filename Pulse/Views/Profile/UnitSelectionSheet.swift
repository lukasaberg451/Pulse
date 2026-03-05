//
//  UnitSelectionSheet.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-05.
//

import SwiftUI

struct UnitSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var unitManager: UnitManager
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Button {
                            Task {
                                await viewModel.updateUnitSystem(system)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(system.displayName)
                                        .foregroundStyle(Color.appText)
                                    
                                    Text(system.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Color.appText.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                if unitManager.unitSystem == system {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .padding()
                        }
                        
                        if system != UnitSystem.allCases.last {
                            Divider()
                                .background(Color.appText.opacity(0.1))
                        }
                    }
                }
                .background(Color.appSurface)
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Units")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
}
