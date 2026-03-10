//
//  OfflineStatusBanner.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import SwiftUI

struct OfflineStatusBanner: View {
    @EnvironmentObject var syncService: WorkoutSyncService
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if !syncService.isOnline {
            HStack(spacing: 12) {
                IconBadge(systemName: "wifi.slash", color: .white, size: 36)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Offline Mode")
                        .font(.subheadline.weight(.semibold))
                    
                    Text("Your workouts will sync when you're back online")
                        .font(.caption)
                        .opacity(0.8)
                }
                
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(LinearGradient.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if syncService.isSyncing {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(Color.appAccent)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Syncing...")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)
                    
                    Text("Saving your workout.")
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }
                
                Spacer()
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .shadow(color: colorScheme == .light ? .black.opacity(0.06) : .clear, radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct SyncStatusIndicator: View {
    @EnvironmentObject var syncService: WorkoutSyncService
    
    var body: some View {
        HStack(spacing: 6) {
            if !syncService.isOnline {
                Image(systemName: "wifi.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                
                Text("Offline")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            } else if syncService.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text("Syncing")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.appSecondaryText)
            } else if let lastSync = syncService.lastSyncDate {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.appSurface, in: Capsule())
    }
}
