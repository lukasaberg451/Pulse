//
//  AICreateRoutineSheet.swift
//  Pulse
//

import SwiftUI
import PostHog

struct AICreateRoutineSheet: View {
    let accessToken: String
    let isOnline: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var unitManager: UnitManager
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var parsedRoutine: ParsedRoutine?
    @State private var editingExerciseId: UUID?
    @FocusState private var isTextEditorFocused: Bool
    @State private var aiReadyPulse = false
    
    private let maxCharacters = 800
    
    private var isAIReady: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 15
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if !isOnline {
                    offlineView
                } else if let routine = parsedRoutine {
                    confirmView(routine: routine)
                } else {
                    inputView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if parsedRoutine != nil {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                parsedRoutine = nil
                                errorMessage = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image("chevron-left")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                Text("Edit")
                            }
                            .foregroundStyle(Color.appAccent)
                        }
                    } else {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheetContentTransition()
        .sentryScreen("CreateRoutineAI")
    }
    
    // MARK: - Offline View
    
    private var offlineView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image("wifi-disabled")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(Color.appTertiaryText)
            
            Text("AI features need a connection")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.appText)
            
            Text("Connect to the internet and try again")
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Input View (Step 1)
    
    private var inputView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create routine with AI")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Describe the routine you'd like and AI will build it")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                    .padding(.top, 8)
                    
                    // Text Editor
                    ZStack(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("Upper body push day, 5 exercises, focus on chest and shoulders, include bench press...")
                                .font(.body)
                                .foregroundStyle(Color.appTertiaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $inputText)
                            .font(.body)
                            .foregroundStyle(Color.appText)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .focused($isTextEditorFocused)
                            .disabled(isLoading)
                    }
                    .frame(minHeight: 160)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.appSurface)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isAIReady
                                    ? Color.appAccent
                                    : (isTextEditorFocused
                                        ? Color.appAccent.opacity(0.5)
                                        : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))),
                                lineWidth: isAIReady ? 1.5 : (isTextEditorFocused ? 1.5 : 1)
                            )
                            .animation(.easeInOut(duration: 0.3), value: isAIReady)
                            .animation(.easeInOut(duration: 0.2), value: isTextEditorFocused)
                    }
                    .shadow(
                        color: isAIReady ? Color.appAccent.opacity(aiReadyPulse ? 0.25 : 0.08) : Color.clear,
                        radius: aiReadyPulse ? 8 : 4
                    )
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: aiReadyPulse)
                    .onChange(of: isAIReady) { _, ready in
                        aiReadyPulse = ready
                    }
                    .onChange(of: inputText) { _, newValue in
                        if newValue.count > maxCharacters {
                            inputText = String(newValue.prefix(maxCharacters))
                        }
                    }
                    
                    // Character counter
                    HStack {
                        Spacer()
                        Text("\(inputText.count)/\(maxCharacters)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(
                                inputText.count > maxCharacters - 50
                                    ? Color.orange
                                    : Color.appTertiaryText
                            )
                    }
                    
                    // Quick-add suggestion chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            suggestionChip("Push day") {
                                appendText("Push day — chest, shoulders, triceps")
                            }
                            suggestionChip("Pull day") {
                                appendText("Pull day — back, biceps")
                            }
                            suggestionChip("Leg day") {
                                appendText("Leg day — quads, hamstrings, glutes")
                            }
                            suggestionChip("Full body") {
                                appendText("Full body workout, balanced")
                            }
                        }
                    }
                    
                    // Tip
                    HStack(spacing: 6) {
                        Image("lightbulb")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("Include muscle groups, exercise preferences, and number of exercises")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.appTertiaryText)
                    
                    // Error banner
                    if let errorMessage {
                        errorBanner(message: errorMessage)
                    }
                }
                .padding(.horizontal)
            }
            
            // Generate button
            VStack(spacing: 0) {
                Divider().opacity(0.3)
                
                Button {
                    Task { await generateRoutine() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image("sparkles")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                        Text("Generate routine")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient.accentGradient
                            .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? 0.5 : 1.0),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .buttonStyle(ScalePressStyle())
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground)
        }
    }
    
    // MARK: - Confirm View (Step 2)
    
    private func confirmView(routine: ParsedRoutine) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Badge
                    HStack(spacing: 6) {
                        Image("sparkles")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("AI generated · review before saving")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .strokeBorder(Color.appAccent.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.top, 8)
                    
                    // Routine name & description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.routineName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        if let description = routine.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        
                        Text("\(routine.exercises.count) exercises")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appTertiaryText)
                    }
                    
                    // Exercise cards
                    ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                        routineExerciseCard(exercise: exercise, index: index)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            
            // Save button
            VStack(spacing: 0) {
                Divider().opacity(0.3)
                
                Button {
                    Task { await saveRoutine() }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image("check")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                        Text("Save routine")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient.accentGradient
                            .opacity(isSaving ? 0.5 : 1.0),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .buttonStyle(ScalePressStyle())
                .disabled(isSaving)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground)
        }
    }
    
    // MARK: - Exercise Card
    
    private func routineExerciseCard(exercise: ParsedRoutineExercise, index: Int) -> some View {
        let isEditing = editingExerciseId == exercise.id
        let isLowConfidence = exercise.confidence == .low
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)
                    
                    if exercise.isCardio {
                        HStack(spacing: 8) {
                            Text("\(exercise.sets) sets")
                            if let duration = exercise.durationSeconds {
                                Text("·")
                                Text(formattedDuration(duration))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                    } else {
                        HStack(spacing: 8) {
                            Text("\(exercise.sets) sets")
                            if let reps = exercise.repsTarget {
                                Text("·")
                                Text("\(reps) reps")
                            }
                            if let weight = exercise.targetWeight {
                                Text("·")
                                Text(String(format: "%.1f %@", unitManager.displayWeight(weight), unitManager.weightUnit))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                    }
                    
                    HStack(spacing: 8) {
                        Image("stopwatch")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(exercise.restSeconds)s rest")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.appTertiaryText)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editingExerciseId = isEditing ? nil : exercise.id
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                        .font(.body)
                        .foregroundStyle(isEditing ? Color.green : Color.appAccent)
                        .frame(width: 36, height: 36)
                        .background(
                            isEditing ? Color.green.opacity(0.12) : Color.appAccentSubtle,
                            in: Circle()
                        )
                }
                .buttonStyle(ScalePressStyle())
            }
            
            // Low confidence warning
            if isLowConfidence {
                HStack(spacing: 6) {
                    Image("error")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    Text(exercise.note ?? String(localized: "Low confidence — please verify"))
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // Inline editor
            if isEditing {
                routineInlineEditor(for: exercise, at: index)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isLowConfidence ? Color.orange.opacity(0.4) :
                        (colorScheme == .dark ? Color.white.opacity(0.08) : Color.clear),
                    lineWidth: isLowConfidence ? 1.5 : 1
                )
        }
        .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Inline Editor
    
    private func routineInlineEditor(for exercise: ParsedRoutineExercise, at index: Int) -> some View {
        VStack(spacing: 10) {
            Divider().opacity(0.3)
            
            editorField(label: "Name", text: Binding(
                get: { parsedRoutine?.exercises[index].name ?? "" },
                set: { parsedRoutine?.exercises[index].name = $0 }
            ))
            
            if exercise.isCardio {
                HStack(spacing: 12) {
                    editorNumberField(label: "Sets", value: Binding(
                        get: { parsedRoutine?.exercises[index].sets ?? 0 },
                        set: { parsedRoutine?.exercises[index].sets = $0 }
                    ))
                    
                    editorNumberField(label: "Duration (min)", value: Binding(
                        get: { (parsedRoutine?.exercises[index].durationSeconds ?? 0) / 60 },
                        set: { parsedRoutine?.exercises[index].durationSeconds = $0 == 0 ? nil : $0 * 60 }
                    ))
                    
                    editorNumberField(label: "Rest (s)", value: Binding(
                        get: { parsedRoutine?.exercises[index].restSeconds ?? 60 },
                        set: { parsedRoutine?.exercises[index].restSeconds = $0 }
                    ))
                }
            } else {
                HStack(spacing: 12) {
                    editorNumberField(label: "Sets", value: Binding(
                        get: { parsedRoutine?.exercises[index].sets ?? 0 },
                        set: { parsedRoutine?.exercises[index].sets = $0 }
                    ))
                    
                    editorField(label: "Reps", text: Binding(
                        get: { parsedRoutine?.exercises[index].repsTarget ?? "" },
                        set: { parsedRoutine?.exercises[index].repsTarget = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                HStack(spacing: 12) {
                    editorDecimalField(
                        label: "Weight (\(unitManager.weightUnit))",
                        value: Binding(
                            get: {
                                if let kg = parsedRoutine?.exercises[index].targetWeight {
                                    return unitManager.displayWeight(kg)
                                }
                                return 0
                            },
                            set: {
                                parsedRoutine?.exercises[index].targetWeight = $0 == 0 ? nil : unitManager.toKg($0)
                            }
                        )
                    )
                    
                    editorNumberField(label: "Rest (s)", value: Binding(
                        get: { parsedRoutine?.exercises[index].restSeconds ?? 60 },
                        set: { parsedRoutine?.exercises[index].restSeconds = $0 }
                    ))
                }
            }
        }
    }
    
    // MARK: - Editor Fields
    
    private func editorField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appTertiaryText)
            TextField(label, text: text)
                .font(.subheadline)
                .foregroundStyle(Color.appText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    private func editorNumberField(label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appTertiaryText)
            TextField(label, value: value, format: .number)
                .keyboardType(.numberPad)
                .font(.subheadline)
                .foregroundStyle(Color.appText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    private func editorDecimalField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appTertiaryText)
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.subheadline)
                .foregroundStyle(Color.appText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    // MARK: - Suggestion Chip
    
    private func suggestionChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .strokeBorder(Color.appAccent, lineWidth: 1)
                )
        }
        .buttonStyle(ScalePressStyle())
        .disabled(isLoading)
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image("error")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.appText)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        }
    }
    
    // MARK: - Actions
    
    private func generateRoutine() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        PostHogSDK.shared.capture("ai_generate_routine_tapped", properties: [
            "text_length": trimmed.count
        ])
        
        isLoading = true
        errorMessage = nil
        
        let impactLight = UIImpactFeedbackGenerator(style: .light)
        impactLight.impactOccurred()
        
        do {
            let result = try await WorkoutParserService.shared.generateRoutine(
                text: trimmed,
                accessToken: accessToken
            )
            withAnimation(.easeInOut(duration: 0.3)) {
                parsedRoutine = result
            }
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
        } catch let error as ParserError {
            debugLog("❌ AI routine ParserError: \(error.errorDescription ?? "nil")")
            errorMessage = error.errorDescription
        } catch {
            debugLog("❌ AI routine other error: \(error)")
            errorMessage = String(localized: "Something went wrong. Please try again.")
        }
        
        isLoading = false
    }
    
    private func saveRoutine() async {
        guard let routine = parsedRoutine else { return }
        
        isSaving = true
        
        let routineRepo = RoutineRepository()
        let exerciseRepo = ExerciseRepository.shared
        
        do {
            // 1. Create the routine
            let newRoutine = try await routineRepo.createRoutine(
                name: routine.routineName,
                description: routine.description
            )
            
            // 2. Fetch all exercises for matching
            let allExercises = try await exerciseRepo.fetchAllExercises()
            
            // 3. Add each exercise to the routine
            for (index, exercise) in routine.exercises.enumerated() {
                // Match by name (case-insensitive)
                let matched = allExercises.first {
                    $0.name.lowercased() == exercise.name.lowercased()
                }
                
                let exerciseId: UUID
                if let matched {
                    exerciseId = matched.id
                } else {
                    let custom = try await exerciseRepo.createCustomExercise(
                        name: exercise.name,
                        exerciseType: exercise.exerciseType ?? "strength"
                    )
                    exerciseRepo.addToCache(custom)
                    exerciseId = custom.id
                }
                
                _ = try await routineRepo.addExerciseToRoutine(
                    routineId: newRoutine.id,
                    exerciseId: exerciseId,
                    sets: exercise.sets,
                    repsTarget: exercise.repsTarget,
                    targetWeight: exercise.targetWeight,
                    durationSeconds: exercise.durationSeconds,
                    restSeconds: exercise.restSeconds,
                    orderIndex: index
                )
            }
            
            // 4. Analytics
            PostHogSDK.shared.capture("routine_created", properties: [
                "ai_generated": true,
                "exercise_count": routine.exercises.count
            ])
            
            // 5. Notify other views
            NotificationCenter.default.post(name: .routineDataChanged, object: nil)
            NotificationCenter.default.post(name: .workoutDataChanged, object: nil)
            
            let impactSuccess = UINotificationFeedbackGenerator()
            impactSuccess.notificationOccurred(.success)
            
            onSave()
            dismiss()
            
            debugLog("✅ AI generated routine saved successfully")
        } catch {
            errorMessage = String(localized: "Failed to save routine. Please try again.")
            debugLog("❌ Failed to save AI generated routine: \(error)")
        }
        
        isSaving = false
    }
    
    private func appendText(_ text: String) {
        if !inputText.isEmpty && !inputText.hasSuffix(" ") && !inputText.hasSuffix("\n") {
            inputText += " "
        }
        inputText += text
    }
    
    private func formattedDuration(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(seconds)s"
        }
    }
}
