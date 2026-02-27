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

                        Text("Active Session")
                            .uiAssetText(.h2)
                            .foregroundStyle(UIAssetColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

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
                        .buttonStyle(UIAssetTextActionButtonStyle())
                    }
                    .padding(.bottom, 8)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(viewModel.sessionName)
                                .uiAssetText(.h4)
                                .foregroundStyle(UIAssetColors.textPrimary)

                            Spacer(minLength: 0)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(viewModel.startTimeText)
                                    .uiAssetText(.paragraph)
                                    .foregroundStyle(UIAssetColors.textSecondary)

                                Text(viewModel.startDateText)
                                    .uiAssetText(.paragraph)
                                    .foregroundStyle(UIAssetColors.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(16)
                        .uiAssetCardSurface(fill: UIAssetColors.primary)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(5 / 4, contentMode: .fit)

                        UIAssetTiledButton(
                            systemImage: "dumbbell.fill",
                            label: "Add",
                            description: "Exercise",
                            variant: .primary
                        ) {
                            isExercisePickerPresented = true
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Text("Exercises")
                        .uiAssetText(.h4)
                        .foregroundStyle(UIAssetColors.textPrimary)

                    if viewModel.exerciseRows.isEmpty {
                        Text("No exercises added yet")
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

            if let error = viewModel.errorMessage {
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.24))
                        .ignoresSafeArea()

                    UIAssetAlertDialog(
                        title: "Session Error",
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
    @Published var startDateText = "--"
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
            startDateText = Self.dateFormatter.string(from: result.0.startDateTime)
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
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    ActiveSessionView(sessionId: "example-session-id")
}
