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

    private var actionButtonSide: CGFloat {
        let totalHorizontalSpacing = (contentHorizontalPadding * 2) + actionButtonSpacing
        return max((UIScreen.main.bounds.width - totalHorizontalSpacing) / 2, 0)
    }

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
                            .font(.app(.title))
                            .padding(.top, 16)

                        Text(viewModel.greetingSubtext)
                            .font(.app(.headline))
                            .foregroundStyle(.secondary)

                        HStack(spacing: actionButtonSpacing) {
                            Button {
                                isCategoryPickerPresented = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.app(.title))
                                        .foregroundStyle(.white)
                                    Text("Start a new workout")
                                        .font(.app(.subheadline))
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(Color.accentColor)
                                )
                            }
                            .frame(width: actionButtonSide, height: actionButtonSide)
                            .buttonStyle(.plain)

                            Button {
                                isTemplatePickerPresented = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .font(.app(.title2))
                                        .foregroundStyle(Color.accentColor)
                                    Text("Start from a template")
                                        .font(.app(.subheadline))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                                        .background(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .fill(Color.accentColor.opacity(0.08))
                                    )
                                )
                            }
                            .frame(width: actionButtonSide, height: actionButtonSide)
                            .buttonStyle(.plain)
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

                    Text("Your Month")
                        .font(.app(.title2))
                        .padding(.top, sectionVerticalSpacing)
                        .padding(.bottom, contentHorizontalPadding)

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

                    VolumeLast7DaysView(points: viewModel.last7DayVolumes)
                        .padding(.top, sectionVerticalSpacing)

                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, 16)
            }
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
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.85),
                Color(.systemBackground).opacity(0.0)
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
