import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = DashboardViewModel()
    @State private var navigationPath: [String] = []
    @State private var isCategoryPickerPresented = false
    @State private var isTemplatePickerPresented = false
    @State private var actionErrorMessage: String?
    private let contentHorizontalPadding: CGFloat = 16
    private let actionButtonSpacing: CGFloat = 16
    private let sectionVerticalSpacing: CGFloat = 24

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
                            .uiAssetText(.h4)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        HStack(spacing: actionButtonSpacing) {
                            UIAssetTiledButton(
                                systemImage: "play.circle.fill",
                                title: "Start a new workout",
                                variant: .primary
                            ) {
                                isCategoryPickerPresented = true
                            }

                            UIAssetTiledButton(
                                systemImage: "square.stack.3d.up.fill",
                                title: "Start from a template",
                                variant: .secondary
                            ) {
                                isTemplatePickerPresented = true
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if let active = viewModel.activeSession {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Active Session")
                                    .font(.app(.title2))

                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(active.name ?? "Workout")
                                            .font(.app(.headline))
                                            .foregroundStyle(.primary)

                                        Text("Started: \(Self.sessionStartTimeFormatter.string(from: active.startDateTime))")
                                            .font(.app(.subheadline))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)

                                    Button {
                                        navigationPath.append(active.id)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text("Resume")
                                            Image(systemName: "restart.circle")
                                            
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, sectionVerticalSpacing)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Month")
                            .uiAssetText(.h4)

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
                            }
                        )
                    }
                    .padding(16)
                    .uiAssetCardSurface(fill: UIAssetColors.primary)
                    .padding(.top, sectionVerticalSpacing)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Volume Last 7 Days")
                            .uiAssetText(.h4)

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
                        navigationPath.append(session.id)
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
                        navigationPath.append(session.id)
                        Task {
                            await viewModel.loadActiveSession(sessionRepository: container.sessionRepository)
                        }
                    } catch {
                        actionErrorMessage = error.localizedDescription
                    }
                }
                .environmentObject(container)
            }
            .navigationDestination(for: String.self) { sessionID in
                ActiveSessionView(sessionId: sessionID)
            }
            .onChange(of: navigationPath) { _ in
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
