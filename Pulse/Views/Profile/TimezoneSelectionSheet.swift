//
//  TimezoneSelectionSheet.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-04.
//

import SwiftUI

struct TimezoneSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @State private var searchText = ""
    
    private var allTimezones: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }
    
    private var filteredTimezones: [String] {
        if searchText.isEmpty {
            return allTimezones
        }
        return allTimezones.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var currentTimezone: String {
        viewModel.profile?.timezone ?? TimeZone.current.identifier
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                List {
                    // Current timezone
                    Section {
                        HStack {
                            Text(currentTimezone)
                                .foregroundStyle(Color.appText)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.appAccent)
                        }
                        .listRowBackground(Color.appSurface)
                    } header: {
                        Text("Current")
                    }
                    
                    // Show device timezone as quick option if different
                    if currentTimezone != TimeZone.current.identifier {
                        Section {
                            Button {
                                Task {
                                    await viewModel.updateTimezone(TimeZone.current.identifier)
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text(TimeZone.current.identifier)
                                        .foregroundStyle(Color.appText)
                                    Spacer()
                                    Text("Device")
                                        .font(.caption)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .listRowBackground(Color.appSurface)
                        } header: {
                            Text("Device Timezone")
                        }
                    }
                    
                    // All timezones
                    Section {
                        ForEach(filteredTimezones, id: \.self) { tz in
                            Button {
                                Task {
                                    await viewModel.updateTimezone(tz)
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text(tz)
                                        .foregroundStyle(Color.appText)
                                    Spacer()
                                    if tz == currentTimezone {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                            }
                            .listRowBackground(Color.appSurface)
                        }
                    } header: {
                        Text("All Timezones")
                    }
                }
                .searchable(text: $searchText, prompt: "Search timezones")
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Timezone")
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
