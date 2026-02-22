import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = HistoryViewModel()
    @State private var pendingDeleteSessionID: String?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.rows.isEmpty && viewModel.isLoading {
                    Section {
                        ProgressView()
                    }
                } else {
                    ForEach(viewModel.rows) { row in
                        NavigationLink {
                            SessionDetailView(sessionId: row.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.name)
                                    .font(.app(.headline))

                                Text(Self.dateFormatter.string(from: row.startDateTime))
                                    .font(.app(.subheadline))
                                    .foregroundStyle(.secondary)

                                HStack {
                                    if let durationText = row.durationText {
                                        Text("Duration: \(durationText)")
                                    } else {
                                        Text("In progress")
                                    }

                                    Spacer()
                                    Text(String(format: "Volume: %.1f kg", row.totalVolumeKg))
                                }
                                .font(.app(.caption))
                                .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if row.isInProgress {
                                Button("End Session") {
                                    Task {
                                        await viewModel.endSession(
                                            sessionId: row.id,
                                            sessionRepository: container.sessionRepository
                                        )
                                    }
                                }
                                .tint(.red)
                            }

                            Button {
                                pendingDeleteSessionID = row.id
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }

                    if viewModel.canLoadMore {
                        Section {
                            Button {
                                Task {
                                    await viewModel.loadMore(
                                        sessionRepository: container.sessionRepository,
                                        statsService: StatsService(dbQueue: container.dbQueue)
                                    )
                                }
                            } label: {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Load More")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(viewModel.isLoadingMore)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadInitial(
                    sessionRepository: container.sessionRepository,
                    statsService: StatsService(dbQueue: container.dbQueue)
                )
            }
            .alert("History Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert(
                "Delete Exercise",
                isPresented: Binding(
                    get: { pendingDeleteSessionID != nil },
                    set: { isPresented in
                        if !isPresented { pendingDeleteSessionID = nil }
                    }
                )
            ) {
                Button("Yes", role: .destructive) {
                    guard let sessionId = pendingDeleteSessionID else { return }
                    pendingDeleteSessionID = nil
                    Task {
                        await viewModel.deleteSession(
                            sessionId: sessionId,
                            sessionRepository: container.sessionRepository
                        )
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteSessionID = nil
                }
            } message: {
                Text("Are you sure you want to delete this exercise?")
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
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
