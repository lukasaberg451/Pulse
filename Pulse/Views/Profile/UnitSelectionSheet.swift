//
//  UnitSelectionSheet.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-05.
//

import SwiftUI

struct UnitSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var unitManager: UnitManager
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    IconBadge(systemName: "ruler", size: 48)
                        .padding(.top, 24)
                    
                    Text("Units")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                    
                    Text("Choose your measurement system")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                    
                    VStack(spacing: 0) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Button {
                                Task {
                                    await viewModel.updateUnitSystem(system)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    IconBadge(systemName: iconForSystem(system), size: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(system.displayName)
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                        
                                        Text(system.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(Color.appSecondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    if unitManager.unitSystem == system {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding(14)
                            }
                            
                            if system != UnitSystem.allCases.last {
                                Divider()
                                    .background(Color.appText.opacity(0.06))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear,
                        radius: 16, x: 0, y: 6
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
    
    private func iconForSystem(_ system: UnitSystem) -> String {
        switch system.displayName {
        case "Metric": return "scalemass"
        case "Imperial": return "scalemass.fill"
        default: return "ruler"
        }
    }
}
