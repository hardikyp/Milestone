import SwiftUI
import GRDB

struct ActiveSessionView: View {
    let sessionId: String

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActiveSessionViewModel()
    @State private var isExercisePickerPresented = false
    @State private var selectedExerciseForLogging: ExercisePickerView.AddedExerciseSelection?
    @State private var openSwipeSessionExerciseID: String?
    @State private var pendingDeleteSessionExerciseID: String?

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
                                .uiAssetText(.h1)
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
                        .uiAssetText(.h1)
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
                            ActiveSessionExerciseSwipeRow(
                                isOpen: openSwipeSessionExerciseID == row.id,
                                onOpen: { openSwipeSessionExerciseID = row.id },
                                onClose: {
                                    if openSwipeSessionExerciseID == row.id {
                                        openSwipeSessionExerciseID = nil
                                    }
                                },
                                onTapRow: {
                                    if openSwipeSessionExerciseID != nil {
                                        openSwipeSessionExerciseID = nil
                                    } else {
                                        selectedExerciseForLogging = ExercisePickerView.AddedExerciseSelection(
                                            sessionExerciseID: row.id,
                                            exerciseName: row.exerciseName,
                                            exerciseType: row.exerciseType
                                        )
                                    }
                                },
                                onDelete: {
                                    pendingDeleteSessionExerciseID = row.id
                                }
                            ) {
                                exerciseRow(row)
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
            } else if pendingDeleteSessionExerciseID != nil {
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.25))
                        .ignoresSafeArea()

                    UIAssetAlertDialog(
                        title: "Remove Exercise",
                        message: "Remove this exercise from the active session? Logged sets for it will also be removed.",
                        cancelTitle: "Cancel",
                        destructiveTitle: "Remove"
                    ) {
                        pendingDeleteSessionExerciseID = nil
                    } onDestructive: {
                        guard let sessionExerciseId = pendingDeleteSessionExerciseID else { return }
                        pendingDeleteSessionExerciseID = nil
                        Task {
                            await viewModel.deleteSessionExercise(
                                sessionExerciseId: sessionExerciseId,
                                sessionExerciseRepository: container.sessionExerciseRepository
                            )

                            if openSwipeSessionExerciseID == sessionExerciseId {
                                openSwipeSessionExerciseID = nil
                            }

                            if viewModel.errorMessage == nil {
                                await viewModel.loadSessionData(sessionId: sessionId, dbQueue: container.dbQueue)
                            }
                        }
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

    @ViewBuilder
    private func exerciseRow(_ row: ActiveSessionViewModel.SessionExerciseRow) -> some View {
        UIAssetExerciseCard(
            symbolName: UIAssetExerciseCard<EmptyView>.symbolName(
                for: row.exerciseType,
                category: row.exerciseCategory
            ),
            title: row.exerciseName
        ) {
            Text("\(row.setCount) sets")
                .uiAssetText(.footnote)
                .foregroundStyle(UIAssetColors.textSecondary)
        }
    }
}

@MainActor
final class ActiveSessionViewModel: ObservableObject {
    struct SessionExerciseRow: Identifiable {
        let id: String
        let exerciseName: String
        let exerciseType: ExerciseType
        let exerciseCategory: ExerciseCategory?
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
                        e.exercise_category AS exercise_category,
                        COUNT(s.id) AS set_count
                    FROM session_exercises se
                    JOIN exercises e ON e.id = se.exercise_id
                    LEFT JOIN sets s ON s.session_exercise_id = se.id
                    WHERE se.session_id = ?
                    GROUP BY se.id, se.order_index, e.name, e.type, e.exercise_category
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
                let rawCategory: String? = $0["exercise_category"]
                return SessionExerciseRow(
                    id: $0["id"],
                    exerciseName: $0["exercise_name"],
                    exerciseType: type,
                    exerciseCategory: rawCategory.flatMap(ExerciseCategory.init(rawValue:)),
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

    func deleteSessionExercise(
        sessionExerciseId: String,
        sessionExerciseRepository: SessionExerciseRepository
    ) async {
        do {
            try sessionExerciseRepository.removeExerciseFromSession(sessionExerciseId: sessionExerciseId)
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

private struct ActiveSessionExerciseSwipeRow<Content: View>: View {
    let isOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onTapRow: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragTranslation: CGFloat = 0
    @State private var measuredRowHeight: CGFloat = UIAssetMetrics.rowCardHeight

    private let actionGap: CGFloat = 8
    private let destructiveColor = Color(red: 225/255, green: 0, blue: 0)
    private let settleAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.82)

    private var actionWidth: CGFloat { measuredRowHeight }
    private var actionRevealWidth: CGFloat { actionWidth + actionGap }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: actionGap, height: measuredRowHeight)

                Button(action: onDelete) {
                    VStack(spacing: 6) {
                        Image(systemName: "trash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.white)

                        Text("Remove")
                            .uiAssetText(.footnote)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .fill(destructiveColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .stroke(destructiveColor.opacity(0.7), lineWidth: 0)
                    )
                    .shadow(color: UIAssetShadows.soft, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .frame(width: actionWidth, height: measuredRowHeight)
            }
            .frame(width: actionRevealWidth, height: measuredRowHeight, alignment: .leading)
            .offset(x: actionOffset)
            .opacity(swipeProgress)
            .allowsHitTesting(swipeProgress > 0.02)

            content()
                .contentShape(Rectangle())
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { updateMeasuredRowHeight(proxy.size.height) }
                            .onChange(of: proxy.size.height) { _, newHeight in
                                updateMeasuredRowHeight(newHeight)
                            }
                    }
                )
                .onTapGesture { onTapRow() }
                .offset(x: rowOffset)
                .highPriorityGesture(dragGesture)
        }
        .animation(settleAnimation, value: isOpen)
    }

    private var rowOffset: CGFloat {
        let baseOffset = isOpen ? -actionRevealWidth : 0
        let proposedOffset = baseOffset + dragTranslation
        return min(0, max(-actionRevealWidth, proposedOffset))
    }

    private var actionOffset: CGFloat {
        actionRevealWidth + rowOffset
    }

    private var swipeProgress: CGFloat {
        min(1, max(0, -rowOffset / actionRevealWidth))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let baseOffset = isOpen ? -actionRevealWidth : 0
                let projected = baseOffset + value.predictedEndTranslation.width
                let shouldOpen = projected < -actionRevealWidth * 0.45

                withAnimation(settleAnimation) {
                    dragTranslation = 0
                    if shouldOpen {
                        onOpen()
                    } else {
                        onClose()
                    }
                }
            }
    }

    private func updateMeasuredRowHeight(_ newHeight: CGFloat) {
        let resolvedHeight = max(newHeight, 1)
        if abs(resolvedHeight - measuredRowHeight) > 0.5 {
            measuredRowHeight = resolvedHeight
        }
    }
}

#Preview {
    ActiveSessionView(sessionId: "example-session-id")
}
