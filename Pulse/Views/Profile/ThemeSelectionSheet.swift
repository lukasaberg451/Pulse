//
//  ThemeSelectionSheet.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-21.
//

import SwiftUI

struct ThemeSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            themeManager.selectedTheme = theme
                        } label: {
                            HStack {
                                Image(systemName: iconForTheme(theme))
                                    .font(.title3)
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 24)
                                
                                Text(theme.rawValue)
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                if themeManager.selectedTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .padding()
                        }
                        
                        if theme != AppTheme.allCases.last {
                            Divider()
                                .background(Color.appText.opacity(0.1))
                        }
                    }
                }
                .background(Color.appSurface)
                .cornerRadius(10)
                .padding()
            }
            .navigationTitle("Appearance")
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
    
    func iconForTheme(_ theme: AppTheme) -> String {
        switch theme {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}
