import SwiftUI
import GRDB

struct ActiveSessionView: View {
    let sessionId: String

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActiveSessionViewModel()
    @State private var isExercisePickerPresented = false
    @State private var selectedExerciseForLogging: ExercisePickerView.AddedExerciseSelection?

    var body: some View {
        List {
            Section {
                Text(viewModel.sessionName)
                    .font(.app(.headline))
                Text("Started at \(viewModel.startTimeText)")
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
            }

            Section("Exercises") {
                if viewModel.exerciseRows.isEmpty {
                    Text("No exercises added yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.exerciseRows) { row in
                        NavigationLink {
                            ExerciseLoggingView(
                                sessionExerciseId: row.id,
                                exerciseName: row.exerciseName,
                                exerciseType: row.exerciseType
                            )
                        } label: {
                            HStack {
                                Text(row.exerciseName)
                                Spacer()
                                Text("\(row.setCount) sets")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Add Exercise") {
                    isExercisePickerPresented = true
                }

                Button("Finish") {
                    Task {
                        await viewModel.finishSession(
                            sessionId: sessionId,
                            sessionRepository: container.sessionRepository
                        )

                        if viewModel.errorMessage == nil {
                            container.selectedTab = .home
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle("Active Session")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isExercisePickerPresented) {
            ExercisePickerView(sessionId: sessionId, sessionCategoryName: viewModel.sessionName) { added in
                Task {
                    await viewModel.loadSessionData(sessionId: sessionId, dbQueue: container.dbQueue)
                    selectedExerciseForLogging = added
                }
            }
            .environmentObject(container)
        }
        .navigationDestination(item: $selectedExerciseForLogging) { selected in
            ExerciseLoggingView(
                sessionExerciseId: selected.sessionExerciseID,
                exerciseName: selected.exerciseName,
                exerciseType: selected.exerciseType
            )
        }
        .task {
            await viewModel.loadSessionData(sessionId: sessionId, dbQueue: container.dbQueue)
        }
        .alert("Session Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

@MainActor
final class ActiveSessionViewModel: ObservableObject {
    struct SessionExerciseRow: Identifiable {
        let id: String
        let exerciseName: String
        let exerciseType: ExerciseType
        let setCount: Int
        let orderIndex: Int
    }

    @Published var sessionName = "Workout"
    @Published var startTimeText = "--"
    @Published var exerciseRows: [SessionExerciseRow] = []
    @Published var errorMessage: String?

    func loadSessionData(sessionId: String, dbQueue: DatabaseQueue) async {
        do {
            let result = try dbQueue.read { db in
                guard let session = try Session.fetchOne(db, key: sessionId) else {
                    throw RepositoryError.sessionNotFound(sessionId)
                }

                let rows = try Row.fetchAll(db, sql: """
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
                    """, arguments: [sessionId])

                return (session, rows)
            }

            sessionName = result.0.name ?? "Workout"
            startTimeText = Self.timeFormatter.string(from: result.0.startDateTime)
            exerciseRows = result.1.map {
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

    func finishSession(sessionId: String, sessionRepository: SessionRepository) async {
        do {
            _ = try sessionRepository.endSession(sessionId: sessionId, notes: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    ActiveSessionView(sessionId: "example-session-id")
}
