import SwiftUI

struct ExerciseLoggingView: View {
    let sessionExerciseId: String
    let exerciseName: String
    let exerciseType: ExerciseType

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExerciseLoggingViewModel()

    var body: some View {
        List {
            Section {
                Text(exerciseName)
                    .font(.app(.headline))
                Text(exerciseType.displayName)
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
            }

            if viewModel.availableMetricTypes.count > 1 {
                Section {
                    Picker("Logging Mode", selection: $viewModel.selectedMetricType) {
                        ForEach(viewModel.availableMetricTypes, id: \.self) { metric in
                            Text(metric.displayName).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if viewModel.selectedMetricType == .strength || viewModel.selectedMetricType == .repsOnly {
                Section {
                    Toggle("Same reps for all", isOn: $viewModel.sameRepsForAll)

                    if viewModel.selectedMetricType == .strength {
                        Toggle("Same weight for all", isOn: $viewModel.sameWeightForAll)
                    }
                }
            }

            Section("Sets") {
                if viewModel.rows.isEmpty {
                    Text("No sets yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($viewModel.rows) { $row in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Set \(row.setIndex)")
                                    .font(.app(.headline))
                                Spacer()
                                HStack(spacing: 8) {
                                    Text("Set performed")
                                        .font(.app(.subheadline))
                                        .foregroundStyle(.secondary)

                                    Button {
                                        row.isDone.toggle()
                                    } label: {
                                        Image(systemName: row.isDone ? "checkmark.square.fill" : "square")
                                            .font(.app(.title3))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 10) {
                                switch viewModel.selectedMetricType {
                                case .strength:
                                    SetInputField(
                                        title: "Reps",
                                        placeholder: "e.g. 10",
                                        text: $row.repsText,
                                        keyboardType: .numberPad
                                    )
                                    .onChange(of: row.repsText) { _, newValue in
                                        viewModel.applyRepChange(value: newValue)
                                    }

                                    SetInputField(
                                        title: "Weight (kg)",
                                        placeholder: "e.g. 40",
                                        text: $row.weightText,
                                        keyboardType: .decimalPad
                                    )
                                    .onChange(of: row.weightText) { _, newValue in
                                        viewModel.applyWeightChange(value: newValue)
                                    }

                                case .repsOnly:
                                    SetInputField(
                                        title: "Reps",
                                        placeholder: "e.g. 15",
                                        text: $row.repsText,
                                        keyboardType: .numberPad
                                    )
                                    .onChange(of: row.repsText) { _, newValue in
                                        viewModel.applyRepChange(value: newValue)
                                    }

                                case .time:
                                    SetInputField(
                                        title: "Duration (sec)",
                                        placeholder: "e.g. 60",
                                        text: $row.durationText,
                                        keyboardType: .numberPad
                                    )

                                case .distanceOnly:
                                    SetInputField(
                                        title: "Distance (m)",
                                        placeholder: "e.g. 500",
                                        text: $row.distanceText,
                                        keyboardType: .decimalPad
                                    )

                                case .distanceTime:
                                    SetInputField(
                                        title: "Distance (m)",
                                        placeholder: "e.g. 1000",
                                        text: $row.distanceText,
                                        keyboardType: .decimalPad
                                    )

                                    SetInputField(
                                        title: "Duration (sec)",
                                        placeholder: "e.g. 300",
                                        text: $row.durationText,
                                        keyboardType: .numberPad
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            Section {
                Button("Add Set") {
                    viewModel.addSetRow()
                }

                Button("Copy Last Set") {
                    viewModel.copyLastSetRow()
                }
            }

            Section {
                Button("Save") {
                    Task {
                        let didSave = await viewModel.save(
                            sessionExerciseId: sessionExerciseId,
                            setRepository: container.setRepository
                        )
                        if didSave {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .scrollContentBackground(.hidden)
        .background(UIAssetColors.secondary.ignoresSafeArea())
        .navigationTitle("Log Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(
                sessionExerciseId: sessionExerciseId,
                exerciseType: exerciseType,
                setRepository: container.setRepository
            )
        }
        .onChange(of: viewModel.selectedMetricType) { _, newMetric in
            if newMetric != .strength {
                viewModel.sameWeightForAll = false
            }
            if newMetric != .strength && newMetric != .repsOnly {
                viewModel.sameRepsForAll = false
            }
        }
        .alert("Set Logging Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

private struct SetInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.app(.subheadline))
                .fontWeight(.medium)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
        }
    }
}

@MainActor
final class ExerciseLoggingViewModel: ObservableObject {
    struct SetRow: Identifiable {
        let id: String
        var createdAt: Date
        var setIndex: Int
        var repsText: String
        var weightText: String
        var distanceText: String
        var durationText: String
        var isDone: Bool
    }

    @Published var rows: [SetRow] = []
    @Published var availableMetricTypes: [MetricType] = [.strength]
    @Published var selectedMetricType: MetricType = .strength
    @Published var sameRepsForAll = false
    @Published var sameWeightForAll = false
    @Published var errorMessage: String?

    func load(
        sessionExerciseId: String,
        exerciseType: ExerciseType,
        setRepository: SetRepository
    ) async {
        do {
            availableMetricTypes = Self.metricTypes(for: exerciseType)
            let sets = try setRepository.fetchSets(sessionExerciseId: sessionExerciseId)

            if let metricFromData = sets.first?.metricType,
               availableMetricTypes.contains(metricFromData) {
                selectedMetricType = metricFromData
            } else {
                selectedMetricType = availableMetricTypes.first ?? .strength
            }

            rows = sets.map { set in
                SetRow(
                    id: set.id,
                    createdAt: set.createdAt,
                    setIndex: set.setIndex,
                    repsText: set.reps.map(String.init) ?? "",
                    weightText: set.weightKg.map { String($0) } ?? "",
                    distanceText: set.distanceM.map { String($0) } ?? "",
                    durationText: set.durationSec.map(String.init) ?? "",
                    isDone: false
                )
            }

            normalizeSetIndexes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSetRow() {
        let nextIndex = rows.count + 1
        rows.append(
            SetRow(
                id: UUID().uuidString,
                createdAt: Date(),
                setIndex: nextIndex,
                repsText: "",
                weightText: "",
                distanceText: "",
                durationText: "",
                isDone: false
            )
        )
    }

    func copyLastSetRow() {
        guard let last = rows.last else {
            addSetRow()
            return
        }

        rows.append(
            SetRow(
                id: UUID().uuidString,
                createdAt: Date(),
                setIndex: rows.count + 1,
                repsText: last.repsText,
                weightText: last.weightText,
                distanceText: last.distanceText,
                durationText: last.durationText,
                isDone: false
            )
        )
    }

    func applyRepChange(value: String) {
        guard sameRepsForAll else { return }

        for index in rows.indices {
            rows[index].repsText = value
        }
    }

    func applyWeightChange(value: String) {
        guard sameWeightForAll else { return }

        for index in rows.indices {
            rows[index].weightText = value
        }
    }

    func save(sessionExerciseId: String, setRepository: SetRepository) async -> Bool {
        do {
            normalizeSetIndexes()

            let now = Date()
            let setsToPersist: [WorkoutSet] = try rows.map { row in
                let reps = try parseOptionalInt(row.repsText)
                let weight = try parseOptionalDouble(row.weightText)
                let distance = try parseOptionalDouble(row.distanceText)
                let duration = try parseOptionalInt(row.durationText)

                let finalReps: Int?
                let finalWeight: Double?
                let finalDistance: Double?
                let finalDuration: Int?

                switch selectedMetricType {
                case .strength:
                    finalReps = try requireValue(reps, field: "reps")
                    finalWeight = try requireValue(weight, field: "weight_kg")
                    finalDistance = nil
                    finalDuration = nil
                case .repsOnly:
                    finalReps = try requireValue(reps, field: "reps")
                    finalWeight = nil
                    finalDistance = nil
                    finalDuration = nil
                case .time:
                    finalReps = nil
                    finalWeight = nil
                    finalDistance = nil
                    finalDuration = try requireValue(duration, field: "duration_sec")
                case .distanceOnly:
                    finalReps = nil
                    finalWeight = nil
                    finalDistance = try requireValue(distance, field: "distance_m")
                    finalDuration = nil
                case .distanceTime:
                    finalReps = nil
                    finalWeight = nil
                    finalDistance = try requireValue(distance, field: "distance_m")
                    finalDuration = try requireValue(duration, field: "duration_sec")
                }

                return try WorkoutSet(
                    id: row.id,
                    sessionExerciseID: sessionExerciseId,
                    setIndex: row.setIndex,
                    metricType: selectedMetricType,
                    reps: finalReps,
                    weightKg: finalWeight,
                    distanceM: finalDistance,
                    durationSec: finalDuration,
                    comment: nil,
                    createdAt: row.createdAt,
                    updatedAt: now
                )
            }

            try setRepository.upsertSets(sessionExerciseId: sessionExerciseId, sets: setsToPersist)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func normalizeSetIndexes() {
        for index in rows.indices {
            rows[index].setIndex = index + 1
        }
    }

    private func parseOptionalInt(_ raw: String) throws -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed) else {
            throw ValidationError.invalidNumberFormat
        }
        return value
    }

    private func parseOptionalDouble(_ raw: String) throws -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed) else {
            throw ValidationError.invalidNumberFormat
        }
        return value
    }

    private func requireValue<T>(_ value: T?, field: String) throws -> T {
        guard let value else {
            throw ValidationError.invalidRequiredField(field)
        }
        return value
    }

    private static func metricTypes(for exerciseType: ExerciseType) -> [MetricType] {
        switch exerciseType {
        case .weight:
            return [.strength]
        case .functional:
            return [.repsOnly, .time]
        case .cardio:
            return [.distanceTime, .time, .distanceOnly]
        }
    }

    enum ValidationError: Error, LocalizedError {
        case invalidRequiredField(String)
        case invalidNumberFormat

        var errorDescription: String? {
            switch self {
            case .invalidRequiredField(let field):
                return "Invalid value for required field: \(field)."
            case .invalidNumberFormat:
                return "Please enter valid numeric values."
            }
        }
    }
}

private extension MetricType {
    var displayName: String {
        switch self {
        case .strength:
            return "Strength"
        case .repsOnly:
            return "Reps"
        case .time:
            return "Time"
        case .distanceTime:
            return "Distance + Time"
        case .distanceOnly:
            return "Distance"
        }
    }
}

private extension ExerciseType {
    var displayName: String {
        switch self {
        case .weight:
            return "Weight"
        case .cardio:
            return "Cardio"
        case .functional:
            return "Functional"
        }
    }
}

#Preview {
    ExerciseLoggingView(
        sessionExerciseId: "session-exercise-id",
        exerciseName: "Bench Press",
        exerciseType: .weight
    )
}
