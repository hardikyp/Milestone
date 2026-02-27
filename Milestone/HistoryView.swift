import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = HistoryViewModel()
    @State private var pendingDeleteSessionID: String?
    @State private var navigationPath: [String] = []
    @State private var openSwipeSessionID: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Text("History")
                        .uiAssetText(.h2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                List {
                    if viewModel.rows.isEmpty && viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.rows) { row in
                            HistorySwipeRow(
                                canEnd: row.isInProgress,
                                isOpen: openSwipeSessionID == row.id,
                                onOpen: { openSwipeSessionID = row.id },
                                onClose: {
                                    if openSwipeSessionID == row.id {
                                        openSwipeSessionID = nil
                                    }
                                },
                                onTapRow: {
                                    if openSwipeSessionID != nil {
                                        openSwipeSessionID = nil
                                    } else {
                                        navigationPath.append(row.id)
                                    }
                                },
                                onDelete: {
                                    pendingDeleteSessionID = row.id
                                },
                                onEnd: {
                                    Task {
                                        await viewModel.endSession(
                                            sessionId: row.id,
                                            sessionRepository: container.sessionRepository
                                        )
                                    }
                                }
                            ) {
                                historyRow(row)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        if viewModel.canLoadMore {
                            Button {
                                Task {
                                    await viewModel.loadMore(
                                        sessionRepository: container.sessionRepository,
                                        statsService: StatsService(dbQueue: container.dbQueue)
                                    )
                                }
                            } label: {
                                Group {
                                    if viewModel.isLoadingMore {
                                        ProgressView()
                                    } else {
                                        Text("Load More")
                                    }
                                }
                                .uiAssetText(.paragraph)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(UIAssetColors.primary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isLoadingMore)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadInitial(
                    sessionRepository: container.sessionRepository,
                    statsService: StatsService(dbQueue: container.dbQueue)
                )
            }
            .overlay {
                if let error = viewModel.errorMessage {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()
                        .overlay {
                            UIAssetAlertDialog(
                                title: "History Error",
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
                } else if pendingDeleteSessionID != nil {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .overlay {
                            UIAssetAlertDialog(
                                title: "Delete Session",
                                message: "Are you sure you want to delete this session?",
                                cancelTitle: "Cancel",
                                destructiveTitle: "Delete"
                            ) {
                                pendingDeleteSessionID = nil
                            } onDestructive: {
                                guard let sessionId = pendingDeleteSessionID else { return }
                                pendingDeleteSessionID = nil
                                Task {
                                    await viewModel.deleteSession(
                                        sessionId: sessionId,
                                        sessionRepository: container.sessionRepository
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                }
            }
            .navigationDestination(for: String.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
        }
    }

    @ViewBuilder
    private func historyRow(_ row: HistoryViewModel.SessionRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(row.name)
                    .uiAssetText(.h5)
                    .foregroundStyle(UIAssetColors.textPrimary)

                Text(Self.dateFormatter.string(from: row.startDateTime))
                    .uiAssetText(.subtitle)
                    .foregroundStyle(UIAssetColors.textSecondary)

                HStack {
                    if let durationText = row.durationText {
                        Text("Duration: \(durationText)")
                    } else {
                        Text("In progress")
                    }

                    Spacer()
                    Text(String(format: "Volume: %.1f kg", row.totalVolumeKg))
                }
                .uiAssetText(.caption)
                .foregroundStyle(UIAssetColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UIAssetColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                .fill(row.isInProgress ? UIAssetColors.accentSecondary : UIAssetColors.primary)
        )
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

private struct HistorySwipeRow<Content: View>: View {
    let canEnd: Bool
    let isOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onTapRow: () -> Void
    let onDelete: () -> Void
    let onEnd: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragTranslation: CGFloat = 0

    private let actionWidth: CGFloat = 84
    private let rowHeight: CGFloat = UIAssetMetrics.rowCardHeight
    private let destructiveColor = Color(red: 225/255, green: 0, blue: 0)
    private let settleAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.82)

    private var actionCount: CGFloat { canEnd ? 2 : 1 }
    private var actionRevealWidth: CGFloat { actionWidth * actionCount }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                if canEnd {
                    Button(action: onEnd) {
                        UIAssetRowSlideActionButton(
                            systemName: "stop.fill",
                            title: "Stop",
                            iconColor: UIAssetColors.accent,
                            backgroundColor: UIAssetColors.accentSecondary,
                            borderColor: UIAssetColors.accent.opacity(0.3),
                            height: rowHeight
                        )
                    }
                    .buttonStyle(HistoryBouncyPlainButtonStyle())
                    .frame(width: actionWidth, height: rowHeight)
                }

                Button(action: onDelete) {
                    UIAssetRowSlideActionButton(
                        systemName: "trash",
                        title: "Delete",
                        iconColor: .white,
                        backgroundColor: destructiveColor,
                        borderColor: destructiveColor.opacity(0.7),
                        height: rowHeight
                    )
                }
                .buttonStyle(HistoryBouncyPlainButtonStyle())
                .frame(width: actionWidth, height: rowHeight)
            }
            .offset(x: actionOffset)
            .opacity(swipeProgress)
            .allowsHitTesting(swipeProgress > 0.02)

            content()
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapRow()
                }
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
}

private struct HistoryBouncyPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    struct SessionRow: Identifiable {
        let id: String
        let name: String
        let startDateTime: Date
        let durationText: String?
        let totalVolumeKg: Double
        let isInProgress: Bool
    }

    @Published var rows: [SessionRow] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var canLoadMore = true
    @Published var errorMessage: String?

    private let pageSize = 20

    func loadInitial(sessionRepository: SessionRepository, statsService: StatsService) async {
        guard rows.isEmpty else { return }
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let sessions = try sessionRepository.fetchSessions(limit: pageSize, offset: 0)
            rows = try sessions.map { session in
                let volume = try statsService.totalVolumeKg(sessionId: session.id)
                return SessionRow(
                    id: session.id,
                    name: session.name?.isEmpty == false ? session.name! : "Workout",
                    startDateTime: session.startDateTime,
                    durationText: formatDuration(statsService.duration(session: session)),
                    totalVolumeKg: volume,
                    isInProgress: session.endDateTime == nil
                )
            }

            canLoadMore = sessions.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(sessionRepository: SessionRepository, statsService: StatsService) async {
        guard !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true

        defer {
            isLoadingMore = false
        }

        do {
            let sessions = try sessionRepository.fetchSessions(limit: pageSize, offset: rows.count)
            let nextRows = try sessions.map { session in
                let volume = try statsService.totalVolumeKg(sessionId: session.id)
                return SessionRow(
                    id: session.id,
                    name: session.name?.isEmpty == false ? session.name! : "Workout",
                    startDateTime: session.startDateTime,
                    durationText: formatDuration(statsService.duration(session: session)),
                    totalVolumeKg: volume,
                    isInProgress: session.endDateTime == nil
                )
            }

            rows.append(contentsOf: nextRows)
            canLoadMore = sessions.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endSession(sessionId: String, sessionRepository: SessionRepository) async {
        do {
            let ended = try sessionRepository.endSession(sessionId: sessionId, notes: nil)
            guard let index = rows.firstIndex(where: { $0.id == sessionId }) else { return }

            rows[index] = SessionRow(
                id: rows[index].id,
                name: rows[index].name,
                startDateTime: rows[index].startDateTime,
                durationText: formatDuration(
                    ended.endDateTime.map { max(0, $0.timeIntervalSince(ended.startDateTime)) }
                ),
                totalVolumeKg: rows[index].totalVolumeKg,
                isInProgress: false
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSession(sessionId: String, sessionRepository: SessionRepository) async {
        do {
            try sessionRepository.deleteSession(sessionId: sessionId)
            rows.removeAll { $0.id == sessionId }
            canLoadMore = rows.count % pageSize == 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatDuration(_ duration: TimeInterval?) -> String? {
        guard let duration else {
            return nil
        }

        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }

        return String(format: "%dm", minutes)
    }
}

#Preview {
    HistoryView()
}
