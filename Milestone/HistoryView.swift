import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = HistoryViewModel()
    @State private var pendingDeleteSessionID: String?
    @State private var navigationPath: [String] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Text("History")
                        .font(.app(.title))
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
                            Button {
                                navigationPath.append(row.id)
                            } label: {
                                historyRow(row)
                            }
                            .buttonStyle(.plain)
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
            .alert("History Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .overlay {
                if pendingDeleteSessionID != nil {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Delete Session")
                                    .font(.app(.headline))

                                Text("Are you sure you want to delete this session?")
                                    .font(.app(.subheadline))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 10) {
                                    Button {
                                        guard let sessionId = pendingDeleteSessionID else { return }
                                        pendingDeleteSessionID = nil
                                        Task {
                                            await viewModel.deleteSession(
                                                sessionId: sessionId,
                                                sessionRepository: container.sessionRepository
                                            )
                                        }
                                    } label: {
                                        Text("Yes")
                                            .font(.app(.subheadline))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color.red)
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        pendingDeleteSessionID = nil
                                    } label: {
                                        Text("Cancel")
                                            .font(.app(.subheadline))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(UIAssetColors.primary)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(UIAssetColors.primary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                            .padding(.horizontal, 24)
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
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
