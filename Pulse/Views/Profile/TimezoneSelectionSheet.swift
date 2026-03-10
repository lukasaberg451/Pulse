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
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                List {
                    // Current timezone
                    Section {
                        HStack {
                            Text(currentTimezone)
                                .font(.body)
                                .foregroundStyle(Color.appText)
                            Spacer()
                            Image("check-circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(Color.appAccent)
                        }
                        .listRowBackground(Color.appSurface)
                    } header: {
                        Text("CURRENT")
                            .font(.caption.weight(.semibold))
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
                                        .font(.body)
                                        .foregroundStyle(Color.appText)
                                    Spacer()
                                    Text("Device Default")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .listRowBackground(Color.appSurface)
                        } header: {
                            Text("DEVICE DEFAULT")
                                .font(.caption.weight(.semibold))
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
                                        .font(.body)
                                        .foregroundStyle(Color.appText)
                                    Spacer()
                                    if tz == currentTimezone {
                                        Image("check-circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                            }
                            .listRowBackground(Color.appSurface)
                        }
                    } header: {
                        Text("ALL TIMEZONES")
                            .font(.caption.weight(.semibold))
                    }
                }
                .searchable(text: $searchText, prompt: "Search timezones")
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .navigationTitle("Timezone")
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
}
