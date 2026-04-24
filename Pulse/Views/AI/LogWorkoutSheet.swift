//
//  LogWorkoutSheet.swift
//  Pulse
//

import SwiftUI
import PostHog

struct LogWorkoutSheet: View {
    let accessToken: String
    let isOnline: Bool
    let onSave: (ParsedWorkout) -> Void
    let onManualEntry: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var unitManager: UnitManager
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var parsedWorkout: ParsedWorkout?
    @State private var editingExerciseId: UUID?
    @FocusState private var isTextEditorFocused: Bool
    @State private var aiReadyPulse = false
    @State private var recentSessions: [(name: String, summary: String)] = []
    
    private let maxCharacters = 800
    
    private var isAIReady: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if !isOnline {
                    offlineView
                } else if let workout = parsedWorkout {
                    confirmView(workout: workout)
                } else {
                    inputView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if parsedWorkout != nil {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                parsedWorkout = nil
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
        .sentryScreen("LogWorkoutAI")
        .task { await loadRecentSessions() }
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
            
            Text("AI logging needs a connection")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.appText)
            
            Text("Log manually instead")
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)
            
            PrimaryCTAButton("Log manually") {
                dismiss()
                onManualEntry()
            }
            .padding(.horizontal, 40)
            
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
                        Text("Log session with AI")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Start with a workout name, then your exercises")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                    .padding(.top, 8)
                    
                    // Text Editor
                    ZStack(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("Chest day, bench press 4x8 at 80kg, incline dumbbell press 3x10 at 30kg, cable flyes 3x12...")
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
                            suggestionChip("+ Exercise") {
                                appendText("exercise name sets x reps at weight, ")
                            }
                            suggestionChip("+ Sets/Reps") {
                                appendText("4x8 at ")
                            }
                            suggestionChip("+ Duration") {
                                appendText("for 45 minutes")
                            }
                        }
                    }
                    
                    // Recent sessions
                    if !recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTertiaryText)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentSessions, id: \.name) { session in
                                        recentSessionChip(name: session.name, summary: session.summary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Tip
                    HStack(spacing: 6) {
                        Image("lightbulb")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("The more detail you give, the smarter the log")
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
            
            // Parse button
            VStack(spacing: 0) {
                Divider().opacity(0.3)
                
                Button {
                    Task { await parseWorkout() }
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
                        Text("Generate session")
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
    
    private func confirmView(workout: ParsedWorkout) -> some View {
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
                    
                    // Routine name & duration
                    if workout.routineName != nil || workout.durationMinutes != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = workout.routineName {
                                Text(name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.appText)
                            }
                            if let minutes = workout.durationMinutes {
                                HStack(spacing: 4) {
                                    Image("clock")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                    Text("\(minutes) min")
                                        .font(.subheadline)
                                }
                                .foregroundStyle(Color.appSecondaryText)
                            }
                        }
                    }
                    
                    // Exercise cards
                    ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseCard(exercise: exercise, index: index)
                    }
                    
                
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            
            // Save button
            VStack(spacing: 0) {
                Divider().opacity(0.3)
                
                PrimaryCTAButton("Save workout", systemIcon: "checkmark") {
                    guard let workout = parsedWorkout else { return }
                    onSave(workout)
                    dismiss()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground)
        }
    }
    
    // MARK: - Exercise Card
    
    private func exerciseCard(exercise: ParsedExercise, index: Int) -> some View {
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
                            if let reps = exercise.reps {
                                Text("·")
                                Text("\(reps) reps")
                            }
                            Text("·")
                            if let weight = exercise.weightKg {
                                Text(String(format: "%.1f %@", unitManager.displayWeight(weight), unitManager.weightUnit))
                            } else {
                                Text("bodyweight")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                    }
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
                inlineEditor(for: exercise, at: index)
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
    
    private func inlineEditor(for exercise: ParsedExercise, at index: Int) -> some View {
        VStack(spacing: 10) {
            Divider().opacity(0.3)
            
            editorField(label: "Name", text: Binding(
                get: { parsedWorkout?.exercises[index].name ?? "" },
                set: { parsedWorkout?.exercises[index].name = $0 }
            ))
            
            if exercise.isCardio {
                HStack(spacing: 12) {
                    editorNumberField(label: "Sets", value: Binding(
                        get: { parsedWorkout?.exercises[index].sets ?? 0 },
                        set: { parsedWorkout?.exercises[index].sets = $0 }
                    ))
                    
                    editorNumberField(label: "Duration (min)", value: Binding(
                        get: { (parsedWorkout?.exercises[index].durationSeconds ?? 0) / 60 },
                        set: { parsedWorkout?.exercises[index].durationSeconds = $0 == 0 ? nil : $0 * 60 }
                    ))
                }
            } else {
                HStack(spacing: 12) {
                    editorNumberField(label: "Sets", value: Binding(
                        get: { parsedWorkout?.exercises[index].sets ?? 0 },
                        set: { parsedWorkout?.exercises[index].sets = $0 }
                    ))
                    
                    editorNumberField(label: "Reps", value: Binding(
                        get: { parsedWorkout?.exercises[index].reps ?? 0 },
                        set: { parsedWorkout?.exercises[index].reps = $0 == 0 ? nil : $0 }
                    ))
                    
                    editorDecimalField(
                        label: "Weight (\(unitManager.weightUnit))",
                        value: Binding(
                            get: {
                                if let kg = parsedWorkout?.exercises[index].weightKg {
                                    return unitManager.displayWeight(kg)
                                }
                                return 0
                            },
                            set: {
                                parsedWorkout?.exercises[index].weightKg = $0 == 0 ? nil : unitManager.toKg($0)
                            }
                        )
                    )
                }
            }
        }
    }
    
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
    
    // MARK: - Recent Session Chip
    
    private func recentSessionChip(name: String, summary: String) -> some View {
        Button {
            inputText = summary
        } label: {
            HStack(spacing: 4) {
                Text(name.count > 20 ? String(name.prefix(20)) + "…" : name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.appText)
                Image("arrow-angular-top-right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(Color.appTertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .strokeBorder(Color(white: 0.2), lineWidth: 1)
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
    
    private func parseWorkout() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        PostHogSDK.shared.capture("ai_parse_workout_tapped", properties: [
            "text_length": trimmed.count
        ])
        
        isLoading = true
        errorMessage = nil
        
        let impactLight = UIImpactFeedbackGenerator(style: .light)
        impactLight.impactOccurred()
        
        do {
            let result = try await WorkoutParserService.shared.parse(
                text: trimmed,
                accessToken: accessToken
            )
            withAnimation(.easeInOut(duration: 0.3)) {
                parsedWorkout = result
            }
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
        } catch let error as ParserError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = String(localized: "Something went wrong. Please try again.")
        }
        
        isLoading = false
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
    
    private func loadRecentSessions() async {
        let repository = WorkoutRepository()
        let exerciseRepository = ExerciseRepository.shared
        
        do {
            let sessions = try await repository.fetchRecentDistinctSessions(limit: 3)
            let allExercises = try await exerciseRepository.fetchAllExercises()
            let exerciseMap = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0.name) })
            
            var results: [(name: String, summary: String)] = []
            
            for session in sessions {
                let sets = try await repository.fetchSets(sessionId: session.id)
                
                // Group sets by exercise, preserving order
                var exerciseOrder: [UUID] = []
                var grouped: [UUID: (name: String, sets: Int, reps: Int?, weight: Double?)] = [:]
                
                for set in sets {
                    if grouped[set.exerciseId] == nil {
                        exerciseOrder.append(set.exerciseId)
                        grouped[set.exerciseId] = (
                            name: exerciseMap[set.exerciseId] ?? "Unknown",
                            sets: 1,
                            reps: set.reps,
                            weight: set.weight
                        )
                    } else {
                        grouped[set.exerciseId]?.sets += 1
                    }
                }
                
                // Build natural language summary
                let exerciseParts = exerciseOrder.compactMap { id -> String? in
                    guard let ex = grouped[id] else { return nil }
                    var part = "\(ex.name.lowercased()) \(ex.sets)x\(ex.reps ?? 0)"
                    if let w = ex.weight, w > 0 {
                        let displayWeight = unitManager.displayWeight(w)
                        part += " at \(String(format: "%.0f", displayWeight))\(unitManager.weightUnit)"
                    }
                    return part
                }
                
                let summary = "\(session.name), \(exerciseParts.joined(separator: ", "))"
                results.append((name: session.name, summary: summary))
            }
            
            await MainActor.run {
                recentSessions = results
            }
        } catch {
            // Silently fail — recent sessions are a nice-to-have
        }
    }
}
