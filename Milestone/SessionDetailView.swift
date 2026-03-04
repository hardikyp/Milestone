import SwiftUI
import GRDB

struct SessionDetailView: View {
    let sessionId: String

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SessionDetailViewModel()
    @State private var isDeleteConfirmationPresented = false
    @State private var isEditSessionPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(UIAssetFloatingActionButtonStyle())

                    Text("Session")
                        .uiAssetText(.h2)
                        .foregroundStyle(UIAssetColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        if viewModel.session?.endDateTime == nil {
                            Button(viewModel.isEnding ? "Ending..." : "End") {
                                Task {
                                    await viewModel.endSession(
                                        sessionId: sessionId,
                                        sessionRepository: container.sessionRepository,
                                        dbQueue: container.dbQueue
                                    )
                                }
                            }
                            .buttonStyle(UIAssetTextActionButtonStyle())
                            .disabled(viewModel.isEnding)
                        }
                        
                        Button {
                            isDeleteConfirmationPresented = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(UIAssetDestructiveFloatingActionButtonStyle())

                        Button("Edit") {
                            isEditSessionPresented = true
                        }
                        .buttonStyle(UIAssetTextActionButtonStyle())
                        .disabled(viewModel.session == nil)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)

                if let session = viewModel.session {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.name?.isEmpty == false ? session.name! : "Workout")
                            .uiAssetText(.h4)
                            .foregroundStyle(UIAssetColors.textPrimary)

                        Text(Self.dateFormatter.string(from: session.startDateTime))
                            .uiAssetText(.subtitle)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        if let durationText = viewModel.durationText {
                            Text("Duration: \(durationText)")
                                .uiAssetText(.subtitle)
                                .foregroundStyle(UIAssetColors.textSecondary)
                        }

                        Text(String(format: "Total Volume: %.1f kg", viewModel.totalVolumeKg))
                            .uiAssetText(.subtitle)
                            .foregroundStyle(UIAssetColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(cardBackground)

                    ForEach(viewModel.exerciseSections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(section.orderIndex). \(section.exerciseName)")
                                .uiAssetText(.subtitle)
                                .foregroundStyle(UIAssetColors.textPrimary)

                            if section.sets.isEmpty {
                                Text("No sets logged")
                                    .uiAssetText(.subtitle)
                                    .foregroundStyle(UIAssetColors.textSecondary)
                            } else {
                                ForEach(Array(section.sets.enumerated()), id: \.element.id) { index, set in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Set \(set.setIndex)")
                                            .uiAssetText(.footnote)
                                            .foregroundStyle(UIAssetColors.textPrimary)
                                        Text(set.summary)
                                            .uiAssetText(.caption)
                                            .foregroundStyle(UIAssetColors.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    if index < section.sets.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(cardBackground)
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                        .background(cardBackground)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(UIAssetColors.secondary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isEditSessionPresented) {
            SessionDetailEditView(sessionId: sessionId) {
                dismiss()
            }
                .environmentObject(container)
        }
        .task {
            await viewModel.load(sessionId: sessionId, dbQueue: container.dbQueue)
        }
        .overlay {
            if let error = viewModel.errorMessage {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .overlay {
                        UIAssetAlertDialog(
                            title: "Session Detail Error",
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
            } else if isDeleteConfirmationPresented {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .overlay {
                        UIAssetAlertDialog(
                            title: "Delete Session",
                            message: "Are you sure you want to delete this session?",
                            cancelTitle: "Cancel",
                            destructiveTitle: "Delete"
                        ) {
                            isDeleteConfirmationPresented = false
                        } onDestructive: {
                            Task {
                                let didDelete = await viewModel.deleteSession(
                                    sessionId: sessionId,
                                    sessionRepository: container.sessionRepository
                                )
                                if didDelete {
                                    dismiss()
                                }
                                isDeleteConfirmationPresented = false
                            }
                        }
                        .padding(.horizontal, 16)
                    }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
            .fill(UIAssetColors.primary)
            .overlay(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .stroke(UIAssetColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct SessionDetailEditView: View {
    let sessionId: String
    let onDone: () -> Void

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SessionDetailEditViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(UIAssetFloatingActionButtonStyle())

                        Text("Edit Session")
                            .uiAssetText(.h2)
                            .foregroundStyle(UIAssetColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Done") {
                            dismiss()
                            DispatchQueue.main.async {
                                onDone()
                            }
                        }
                        .buttonStyle(UIAssetTextActionButtonStyle())
                    }
                    .padding(.bottom, 8)

                    if viewModel.exerciseRows.isEmpty {
                        Text("No exercises found for this session")
                            .uiAssetText(.paragraph)
                            .foregroundStyle(UIAssetColors.textSecondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .uiAssetCardSurface(fill: UIAssetColors.primary)
                    } else {
                        ForEach(viewModel.exerciseRows) { row in
                            NavigationLink {
                                ExerciseLoggingView(
                                    sessionExerciseId: row.id,
                                    exerciseName: row.exerciseName,
                                    exerciseType: row.exerciseType
                                )
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(row.exerciseName)
                                            .uiAssetText(.paragraph)
                                            .foregroundStyle(UIAssetColors.textPrimary)
                                        Text("\(row.setCount) sets")
                                            .uiAssetText(.caption)
                                            .foregroundStyle(UIAssetColors.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(UIAssetColors.textSecondary)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .uiAssetCardSurface(fill: UIAssetColors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.load(sessionId: sessionId, dbQueue: container.dbQueue)
            }

            if let error = viewModel.errorMessage {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .overlay {
                        UIAssetAlertDialog(
                            title: "Session Edit Error",
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
            }
        }
    }
}

@MainActor
final class SessionDetailViewModel: ObservableObject {
    struct SetDisplay: Identifiable {
        let id: String
        let setIndex: Int
        let metricType: MetricType
        let reps: Int?
        let weightKg: Double?
        let distanceM: Double?
        let durationSec: Int?
        let comment: String?

        var summary: String {
            switch metricType {
            case .strength:
                let repsPart = reps.map { "\($0) reps" } ?? "- reps"
                let weightPart = weightKg.map { String(format: "%.1f kg", $0) } ?? "- kg"
                return [repsPart, weightPart].joined(separator: " • ")
            case .repsOnly:
                return "\(reps ?? 0) reps"
            case .time:
                return "\(durationSec ?? 0)s"
            case .distanceOnly:
                let distance = distanceM ?? 0
                return String(format: "%.0f m", distance)
            case .distanceTime:
                let distance = distanceM ?? 0
                let duration = durationSec ?? 0
                return String(format: "%.0f m • %ds", distance, duration)
            }
        }
    }

    struct ExerciseSection: Identifiable {
        let id: String
        let orderIndex: Int
        let exerciseName: String
        var sets: [SetDisplay]
    }

    @Published var session: Session?
    @Published var exerciseSections: [ExerciseSection] = []
    @Published var totalVolumeKg: Double = 0
    @Published var durationText: String?
    @Published var isLoading = false
    @Published var isEnding = false
    @Published var errorMessage: String?

    func load(sessionId: String, dbQueue: DatabaseQueue) async {
        isLoading = true

        do {
            let statsService = StatsService(dbQueue: dbQueue)

            let loaded = try dbQueue.read { db in
                guard let session = try Session.fetchOne(db, key: sessionId) else {
                    throw RepositoryError.sessionNotFound(sessionId)
                }

                let rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT
                        se.id AS session_exercise_id,
                        se.order_index,
                        e.name AS exercise_name,
                        s.id AS set_id,
                        s.set_index,
                        s.metric_type,
                        s.reps,
                        s.weight_kg,
                        s.distance_m,
                        s.duration_sec,
                        s.comment
                    FROM session_exercises se
                    JOIN exercises e ON e.id = se.exercise_id
                    LEFT JOIN sets s ON s.session_exercise_id = se.id
                    WHERE se.session_id = ?
                    ORDER BY se.order_index ASC, s.set_index ASC
                    """,
                    arguments: [sessionId]
                )

                return (session, rows)
            }

            var sectionsByID: [String: ExerciseSection] = [:]
            var orderedSectionIDs: [String] = []

            for row in loaded.1 {
                let sessionExerciseID: String = row["session_exercise_id"]
                let orderIndex: Int = row["order_index"]
                let exerciseName: String = row["exercise_name"]

                if sectionsByID[sessionExerciseID] == nil {
                    sectionsByID[sessionExerciseID] = ExerciseSection(
                        id: sessionExerciseID,
                        orderIndex: orderIndex,
                        exerciseName: exerciseName,
                        sets: []
                    )
                    orderedSectionIDs.append(sessionExerciseID)
                }

                let setID: String? = row["set_id"]
                if let setID {
                    let rawMetricType: String = row["metric_type"]
                    let metricType = MetricType(rawValue: rawMetricType) ?? .strength

                    let setDisplay = SetDisplay(
                        id: setID,
                        setIndex: row["set_index"],
                        metricType: metricType,
                        reps: row["reps"],
                        weightKg: row["weight_kg"],
                        distanceM: row["distance_m"],
                        durationSec: row["duration_sec"],
                        comment: row["comment"]
                    )

                    sectionsByID[sessionExerciseID]?.sets.append(setDisplay)
                }
            }

            let sections = orderedSectionIDs.compactMap { sectionsByID[$0] }
            let volume = try statsService.totalVolumeKg(sessionId: sessionId)

            session = loaded.0
            exerciseSections = sections
            totalVolumeKg = volume
            durationText = formatDuration(statsService.duration(session: loaded.0))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func endSession(
        sessionId: String,
        sessionRepository: SessionRepository,
        dbQueue: DatabaseQueue
    ) async {
        guard !isEnding else { return }
        isEnding = true
        defer { isEnding = false }

        do {
            _ = try sessionRepository.endSession(sessionId: sessionId, notes: nil)
            await load(sessionId: sessionId, dbQueue: dbQueue)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSession(
        sessionId: String,
        sessionRepository: SessionRepository
    ) async -> Bool {
        do {
            try sessionRepository.deleteSession(sessionId: sessionId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func formatDuration(_ duration: TimeInterval?) -> String? {
        guard let duration else {
            return nil
        }

        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        }

        return String(format: "%dm %02ds", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionId: "example-session")
    }
}

@MainActor
final class SessionDetailEditViewModel: ObservableObject {
    struct SessionExerciseRow: Identifiable {
        let id: String
        let exerciseName: String
        let exerciseType: ExerciseType
        let setCount: Int
        let orderIndex: Int
    }

    @Published var exerciseRows: [SessionExerciseRow] = []
    @Published var errorMessage: String?

    func load(sessionId: String, dbQueue: DatabaseQueue) async {
        do {
            let rows: [Row] = try dbQueue.read { db in
                try Row.fetchAll(
                    db,
                    sql: """
                    SELECT
                        se.id,
                        se.order_index,
                        e.name AS exercise_name,
                        e.type AS exercise_type,
                        COUNT(s.id) AS set_count
                    FROM session_exercises se
                    JOIN exercises e ON e.id = se.exercise_id
                    LEFT JOIN sets s ON s.session_exercise_id = se.id
                    WHERE se.session_id = ?
                    GROUP BY se.id, se.order_index, e.name, e.type
                    ORDER BY se.order_index ASC
                    """,
                    arguments: [sessionId]
                )
            }

            exerciseRows = rows.map {
                let rawType: String = $0["exercise_type"]
                let type = ExerciseType(rawValue: rawType) ?? .weight
                return SessionExerciseRow(
                    id: $0["id"],
                    exerciseName: $0["exercise_name"],
                    exerciseType: type,
                    setCount: $0["set_count"],
                    orderIndex: $0["order_index"]
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
