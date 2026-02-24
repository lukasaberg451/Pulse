//
//  OfflineStatusBanner.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-02-24.
//

import SwiftUI

struct OfflineStatusBanner: View {
    @EnvironmentObject var syncService: WorkoutSyncService
    
    var body: some View {
        if !syncService.isOnline {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline Mode")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Your workouts will sync when you're back online")
                        .font(.caption)
                        .opacity(0.8)
                }
                
                Spacer()
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.orange.gradient)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if syncService.isSyncing {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Syncing...")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Uploading your workouts to the cloud")
                        .font(.caption)
                        .opacity(0.8)
                }
                
                Spacer()
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.blue.gradient)
            .cornerRadius(10)
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
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                Text("Offline")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if syncService.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text("Syncing")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
            } else if let lastSync = syncService.lastSyncDate {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.appSurface)
        .cornerRadius(20)
    }
}
