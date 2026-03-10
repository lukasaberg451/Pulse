//
//  ThemeSelectionSheet.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-21.
//

import SwiftUI

struct ThemeSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    IconBadge(systemName: "paintbrush.fill", size: 48)
                        .padding(.top, 24)
                    
                    Text("Appearance")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                    
                    Text("Choose your preferred theme")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                    
                    VStack(spacing: 0) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Button {
                                themeManager.selectedTheme = theme
                            } label: {
                                HStack(spacing: 14) {
                                    IconBadge(systemName: iconForTheme(theme), size: 32)
                                    
                                    Text(theme.rawValue)
                                        .font(.body)
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    if themeManager.selectedTheme == theme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding(14)
                            }
                            
                            if theme != AppTheme.allCases.last {
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
    
    func iconForTheme(_ theme: AppTheme) -> String {
        switch theme {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}
