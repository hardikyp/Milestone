import SwiftUI
import UIKit

struct DashboardView: View {
    private enum DashboardRoute: Hashable {
        case activeSession(String)
        case sessionDetail(String)
    }

    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = DashboardViewModel()
    @State private var navigationPath: [DashboardRoute] = []
    @State private var isCategoryPickerPresented = false
    @State private var isTemplatePickerPresented = false
    @State private var actionErrorMessage: String?
    private let contentHorizontalPadding: CGFloat = 16
    private let actionButtonSpacing: CGFloat = 16
    private let sectionVerticalSpacing: CGFloat = 16

    private static let sessionStartTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(viewModel.greetingText)
                            .uiAssetText(.h1)
                            .padding(.top, 16)

                        Text(viewModel.greetingSubtext)
                            .uiAssetText(.paragraph)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        HStack(spacing: actionButtonSpacing) {
                            UIAssetTiledButton(
                                systemImage: "play.circle.fill",
                                label: "Start",
                                description: "New workout",
                                variant: .primary
                            ) {
                                isCategoryPickerPresented = true
                            }

                            UIAssetTiledButton(
                                systemImage: "square.stack.3d.up.fill",
                                label: "Start",
                                description: "From template",
                                variant: .secondary
                            ) {
                                isTemplatePickerPresented = true
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if let active = viewModel.activeSession {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Active Session")
                                    .uiAssetText(.h2)
                                    .foregroundStyle(UIAssetColors.accent)

                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(active.name ?? "Workout")
                                            .uiAssetText(.h3)
                                            .foregroundStyle(UIAssetColors.accent)

                                        Text("Started: \(Self.sessionStartTimeFormatter.string(from: active.startDateTime))")
                                            .uiAssetText(.subtitle)
                                            .foregroundStyle(UIAssetColors.accent)
                                    }

                                    Spacer(minLength: 0)

                                    Button {
                                        navigationPath.append(.activeSession(active.id))
                                    } label: {
                                        Text("Resume")
                                    }
                                    .buttonStyle(UIAssetTextActionButtonStyle(hasShadow: false))
                                }
                            }
                            .padding(16)
                            .uiAssetCardSurface(fill: UIAssetColors.accentSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Month")
                            .uiAssetText(.h2)

                        MonthlyCalendarView(
                            monthDate: viewModel.monthDate,
                            highlightedDays: viewModel.highlightedDays,
                            onPreviousMonth: {
                                Task {
                                    await viewModel.shiftMonth(
                                        by: -1,
                                        sessionRepository: container.sessionRepository
                                    )
                                }
                            },
                            onNextMonth: {
                                Task {
                                    await viewModel.shiftMonth(
                                        by: 1,
                                        sessionRepository: container.sessionRepository
                                    )
                                }
                            },
                            onSelectDay: handleCalendarSelection(day:)
                        )
                    }
                    .padding(16)
                    .uiAssetCardSurface(fill: UIAssetColors.primary)
                    .padding(.top, sectionVerticalSpacing)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Volume Last 7 Days")
                            .uiAssetText(.h2)

                        VolumeLast7DaysView(points: viewModel.last7DayVolumes, showsTitle: false)
                    }
                    .padding(16)
                    .uiAssetCardSurface(fill: UIAssetColors.primary)
                        .padding(.top, sectionVerticalSpacing)

                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, 16)
            }
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isCategoryPickerPresented) {
                CategoryPickerView { category in
                    do {
                        let session = try container.sessionRepository.startSession(name: category)
                        navigationPath.append(.activeSession(session.id))
                        isCategoryPickerPresented = false
                        Task {
                            await viewModel.loadActiveSession(sessionRepository: container.sessionRepository)
                        }
                    } catch {
                        actionErrorMessage = error.localizedDescription
                    }
                }
            }
            .sheet(isPresented: $isTemplatePickerPresented) {
                TemplatePickerView { templateId, precreateSets in
                    do {
                        let session = try container.templateRepository.startSessionFromTemplate(
                            templateId: templateId,
                            sessionName: nil,
                            precreateSets: precreateSets
                        )
                        navigationPath.append(.activeSession(session.id))
                        Task {
                            await viewModel.loadActiveSession(sessionRepository: container.sessionRepository)
                        }
                    } catch {
                        actionErrorMessage = error.localizedDescription
                    }
                }
                .environmentObject(container)
            }
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .activeSession(let sessionID):
                    ActiveSessionView(sessionId: sessionID)
                case .sessionDetail(let sessionID):
                    SessionDetailView(sessionId: sessionID)
                }
            }
            .onChange(of: navigationPath) { _, _ in
                Task {
                    await viewModel.loadActiveSession(sessionRepository: container.sessionRepository)
                }
            }
            .task {
                await viewModel.load(
                    sessionRepository: container.sessionRepository,
                    statsService: StatsService(dbQueue: container.dbQueue)
                )
            }
            .alert("Dashboard Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert("Unable to Start Session", isPresented: .constant(actionErrorMessage != nil)) {
                Button("OK") { actionErrorMessage = nil }
            } message: {
                Text(actionErrorMessage ?? "Unknown error")
            }
            .overlay(alignment: .top) {
                DashboardTopFadeNavigationBackground()
            }
        }
    }

    private func handleCalendarSelection(day: Int) {
        let sessions = viewModel.sessions(forDay: day)
        guard !sessions.isEmpty else { return }

        if sessions.count == 1, let session = sessions.first {
            navigationPath.append(.sessionDetail(session.id))
            return
        }

        guard let selectedDate = viewModel.dateForSelectedDay(day) else { return }
        container.historyNavigationDate = selectedDate
        container.selectedTab = .history
    }
}

private struct DashboardTopFadeNavigationBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                UIAssetColors.secondary,
                UIAssetColors.secondary.opacity(0.85),
                UIAssetColors.secondary.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 75)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

#Preview {
    DashboardView()
}
