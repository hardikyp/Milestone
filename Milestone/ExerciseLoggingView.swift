import SwiftUI

struct ExerciseLoggingView: View {
    let sessionExerciseId: String
    let exerciseName: String
    let exerciseType: ExerciseType

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExerciseLoggingViewModel()

    var body: some View {
        ZStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(UIAssetFloatingActionButtonStyle())

                        Text("Log Exercise")
                            .uiAssetText(.h2)
                            .foregroundStyle(UIAssetColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

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
                        .buttonStyle(UIAssetTextActionButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(exerciseName)
                            .uiAssetText(.h4)
                            .foregroundStyle(UIAssetColors.textPrimary)

                        UIAssetBadge(text: exerciseType.displayName, variant: .accent)

                        if viewModel.availableMetricTypes.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Logging Mode")
                                    .uiAssetText(.caption)
                                    .foregroundStyle(UIAssetColors.textSecondary)

                                if exerciseType == .cardio || exerciseType == .functional {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.availableMetricTypes, id: \.self) { metric in
                                            CompactLoggingModeRadioRow(
                                                title: metric.displayName,
                                                isSelected: viewModel.selectedMetricType == metric
                                            ) {
                                                viewModel.selectedMetricType = metric
                                            }
                                        }
                                    }
                                } else {
                                    Picker("Logging Mode", selection: $viewModel.selectedMetricType) {
                                        ForEach(viewModel.availableMetricTypes, id: \.self) { metric in
                                            Text(metric.displayName).tag(metric)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }

                        if viewModel.selectedMetricType == .strength || viewModel.selectedMetricType == .repsOnly {
                            VStack(spacing: 10) {
                                SetOptionToggleRow(
                                    title: "Same reps for all",
                                    explanation: "Apply entered reps to empty fields across unfinished sets.",
                                    isOn: $viewModel.sameRepsForAll
                                )

                                if viewModel.selectedMetricType == .strength {
                                    SetOptionToggleRow(
                                        title: "Same weight for all",
                                        explanation: "Apply entered weight to empty fields across unfinished sets.",
                                        isOn: $viewModel.sameWeightForAll
                                    )
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(14)
                    .uiAssetCardSurface(fill: UIAssetColors.primary)
                    .listRowInsets(EdgeInsets(top: 24, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    Text("Sets")
                        .uiAssetText(.h4)
                        .foregroundStyle(UIAssetColors.textPrimary)
                        .padding(.top, 4)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if viewModel.rows.isEmpty {
                        Text("No sets yet")
                            .uiAssetText(.paragraph)
                            .foregroundStyle(UIAssetColors.textSecondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .uiAssetCardSurface(fill: UIAssetColors.primary)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach($viewModel.rows) { $row in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    HStack(spacing: 10) {
                                        Button {
                                            row.isDone.toggle()
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(row.isDone ? UIAssetColors.accent : Color.clear)
                                                    .frame(width: 22, height: 22)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(
                                                                row.isDone ? UIAssetColors.accent : UIAssetColors.textSecondary.opacity(0.6),
                                                                lineWidth: 2
                                                            )
                                                    )

                                                if row.isDone {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(row.isDone ? "Unmark set done" : "Mark set done")

                                        Text("Set \(row.setIndex)")
                                            .uiAssetText(.h5)
                                    }

                                    Spacer()

                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.removeSetRow(id: row.id)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .buttonStyle(UIAssetButtonStyle(variant: .destructive, symbolOnly: true))
                                }

                                setInputs(for: $row)
                                .frame(minHeight: 68, alignment: .topLeading)
                                .disabled(row.isDone)
                            }
                            .padding(14)
                            .uiAssetCardSurface(fill: row.isDone ? UIAssetColors.accentSecondary : UIAssetColors.primary)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Button("Add Set") {
                            viewModel.addSetRow()
                        }
                        .buttonStyle(UIAssetButtonStyle(variant: .primary))
                        .frame(maxWidth: .infinity)

                        Button("Copy Last Set") {
                            viewModel.copyLastSetRow()
                        }
                        .buttonStyle(UIAssetButtonStyle(variant: .secondary))
                        .frame(maxWidth: .infinity)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.load(
                    sessionExerciseId: sessionExerciseId,
                    exerciseType: exerciseType,
                    setRepository: container.setRepository
                )
            }
            .onChange(of: viewModel.selectedMetricType) { _, newMetric in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if newMetric != .strength {
                        viewModel.sameWeightForAll = false
                    }
                    if newMetric != .strength && newMetric != .repsOnly {
                        viewModel.sameRepsForAll = false
                    }
                }
            }
            .onChange(of: viewModel.sameRepsForAll) { _, isOn in
                guard isOn else { return }
                viewModel.fillEmptyRepsFromFirstAvailable()
            }
            .onChange(of: viewModel.sameWeightForAll) { _, isOn in
                guard isOn else { return }
                viewModel.fillEmptyWeightFromFirstAvailable()
            }

            if let error = viewModel.errorMessage {
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.24))
                        .ignoresSafeArea()

                    UIAssetAlertDialog(
                        title: "Set Logging Error",
                        message: error,
                        cancelTitle: "Close",
                        destructiveTitle: "OK"
                    ) {
                        viewModel.errorMessage = nil
                    } onDestructive: {
                        viewModel.errorMessage = nil
                    }
                    .padding(.horizontal, 16)
                }
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func setInputs(for row: Binding<ExerciseLoggingViewModel.SetRow>) -> some View {
        if viewModel.selectedMetricType == .distanceTime {
            DistanceTimeInputRow(
                distanceText: row.distanceText,
                durationMinText: row.durationMinText,
                durationSecText: row.durationSecText
            )
        } else {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 10) {
                switch viewModel.selectedMetricType {
                case .strength:
                    SetInputField(
                        title: "Reps",
                        placeholder: "e.g. 10",
                        text: row.repsText,
                        keyboardType: .numberPad
                    )
                    .onChange(of: row.wrappedValue.repsText) { _, newValue in
                        viewModel.applyRepChange(value: newValue)
                    }

                    SetInputField(
                        title: "Weight (kg)",
                        placeholder: "e.g. 40",
                        text: row.weightText,
                        keyboardType: .decimalPad
                    )
                    .onChange(of: row.wrappedValue.weightText) { _, newValue in
                        viewModel.applyWeightChange(value: newValue)
                    }

                case .repsOnly:
                    SetInputField(
                        title: "Reps",
                        placeholder: "e.g. 15",
                        text: row.repsText,
                        keyboardType: .numberPad
                    )
                    .onChange(of: row.wrappedValue.repsText) { _, newValue in
                        viewModel.applyRepChange(value: newValue)
                    }

                case .time:
                    SetInputField(
                        title: "Duration (min-sec)",
                        placeholder: "min e.g. 2",
                        text: row.durationMinText,
                        keyboardType: .numberPad
                    )

                    SetInputField(
                        title: "Duration (min-sec)",
                        placeholder: "sec e.g. 30",
                        text: row.durationSecText,
                        keyboardType: .numberPad,
                        showsTitle: false
                    )

                case .distanceOnly:
                    SetInputField(
                        title: "Distance (m)",
                        placeholder: "e.g. 500",
                        text: row.distanceText,
                        keyboardType: .decimalPad
                    )

                case .distanceTime:
                    EmptyView()
                }
            }
        }
    }
}

private struct SetOptionToggleRow: View {
    let title: String
    let explanation: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .uiAssetText(.paragraph)
                    .foregroundStyle(UIAssetColors.textPrimary)

                Text(explanation)
                    .uiAssetText(.footnote)
                    .foregroundStyle(UIAssetColors.textSecondary)
            }

            Spacer(minLength: 0)

            UIAssetSettingsInlineToggle(isOn: $isOn)
        }
        .padding(.vertical, 2)
    }
}

private struct CompactLoggingModeRadioRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    private let unselectedRadioColor = Color(red: 0.72, green: 0.72, blue: 0.74)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? UIAssetColors.accent : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? UIAssetColors.accent : unselectedRadioColor, lineWidth: 2)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(title)
                    .uiAssetText(.paragraph)
                    .foregroundStyle(UIAssetColors.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                    .fill(isSelected ? UIAssetColors.accentSecondary : UIAssetColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                    .stroke(isSelected ? UIAssetColors.accent.opacity(0.28) : UIAssetColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct DistanceTimeInputRow: View {
    @Binding var distanceText: String
    @Binding var durationMinText: String
    @Binding var durationSecText: String

    private let columnSpacing: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width - (columnSpacing * 2), 0)
            let singleColumnWidth = availableWidth / 4
            let distanceColumnWidth = singleColumnWidth * 2

            HStack(spacing: columnSpacing) {
                SetInputField(
                    title: "Distance (m)",
                    placeholder: "e.g. 1000",
                    text: $distanceText,
                    keyboardType: .decimalPad
                )
                .frame(width: distanceColumnWidth)

                SetInputField(
                    title: "Duration (min-sec)",
                    placeholder: "min e.g. 2",
                    text: $durationMinText,
                    keyboardType: .numberPad
                )
                .frame(width: singleColumnWidth)

                SetInputField(
                    title: "Duration (min-sec)",
                    placeholder: "sec e.g. 30",
                    text: $durationSecText,
                    keyboardType: .numberPad,
                    showsTitle: false
                )
                .frame(width: singleColumnWidth)
            }
        }
        .frame(height: 64)
    }
}

private struct SetInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text(title)
                    .uiAssetText(.caption)
                    .fontWeight(.medium)
            } else {
                Text(title)
                    .uiAssetText(.caption)
                    .fontWeight(.medium)
                    .hidden()
            }
            TextField(placeholder, text: $text)
                .font(.app(.body))
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                        .fill(UIAssetColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                        .stroke(UIAssetColors.border, lineWidth: 1)
                )
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
        var durationMinText: String
        var durationSecText: String
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
                let (durationMinText, durationSecText) = Self.durationParts(from: set.durationSec)
                return SetRow(
                    id: set.id,
                    createdAt: set.createdAt,
                    setIndex: set.setIndex,
                    repsText: set.reps.map(String.init) ?? "",
                    weightText: set.weightKg.map { String($0) } ?? "",
                    distanceText: set.distanceM.map { String($0) } ?? "",
                    durationMinText: durationMinText,
                    durationSecText: durationSecText,
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
                durationMinText: "",
                durationSecText: "",
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
                durationMinText: last.durationMinText,
                durationSecText: last.durationSecText,
                isDone: false
            )
        )
    }

    func removeSetRow(id: String) {
        rows.removeAll { $0.id == id }
        normalizeSetIndexes()
    }

    func applyRepChange(value: String) {
        guard sameRepsForAll else { return }

        for index in rows.indices {
            if !rows[index].isDone && rows[index].repsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rows[index].repsText = value
            }
        }
    }

    func applyWeightChange(value: String) {
        guard sameWeightForAll else { return }

        for index in rows.indices {
            if !rows[index].isDone && rows[index].weightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rows[index].weightText = value
            }
        }
    }

    func fillEmptyRepsFromFirstAvailable() {
        guard sameRepsForAll else { return }
        guard let source = rows.first(where: { !$0.isDone && !$0.repsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return
        }
        applyRepChange(value: source.repsText)
    }

    func fillEmptyWeightFromFirstAvailable() {
        guard sameWeightForAll else { return }
        guard let source = rows.first(where: { !$0.isDone && !$0.weightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return
        }
        applyWeightChange(value: source.weightText)
    }

    func save(sessionExerciseId: String, setRepository: SetRepository) async -> Bool {
        do {
            normalizeSetIndexes()

            let now = Date()
            let setsToPersist: [WorkoutSet] = try rows.map { row in
                let reps = try parseOptionalInt(row.repsText)
                let weight = try parseOptionalDouble(row.weightText)
                let distance = try parseOptionalDouble(row.distanceText)
                let duration = try parseOptionalDurationSeconds(
                    minutesRaw: row.durationMinText,
                    secondsRaw: row.durationSecText
                )

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
        guard value >= 0 else {
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
        guard value >= 0 else {
            throw ValidationError.invalidNumberFormat
        }
        return value
    }

    private func parseOptionalDurationSeconds(minutesRaw: String, secondsRaw: String) throws -> Int? {
        let minutes = try parseOptionalInt(minutesRaw)
        let seconds = try parseOptionalInt(secondsRaw)

        if minutes == nil && seconds == nil {
            return nil
        }

        let resolvedMinutes = minutes ?? 0
        let resolvedSeconds = seconds ?? 0

        guard resolvedSeconds < 60 else {
            throw ValidationError.invalidDurationSeconds
        }

        return (resolvedMinutes * 60) + resolvedSeconds
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

    private static func durationParts(from totalSeconds: Int?) -> (String, String) {
        guard let totalSeconds else { return ("", "") }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return (String(minutes), String(seconds))
    }

    enum ValidationError: Error, LocalizedError {
        case invalidRequiredField(String)
        case invalidNumberFormat
        case invalidDurationSeconds

        var errorDescription: String? {
            switch self {
            case .invalidRequiredField(let field):
                return "Invalid value for required field: \(field)."
            case .invalidNumberFormat:
                return "Please enter valid numeric values."
            case .invalidDurationSeconds:
                return "Seconds must be between 0 and 59."
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
