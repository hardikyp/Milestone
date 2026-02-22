import SwiftUI

struct LogView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = LogViewModel()
    @State private var isCategoryPickerPresented = false
    @State private var isTemplatePickerPresented = false
    @State private var navigationPath: [String] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 16) {
                if let active = viewModel.activeSession {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Active Session")
                            .font(.app(.headline))

                        Text(active.name ?? "Workout")
                            .font(.app(.subheadline))
                            .foregroundStyle(.secondary)

                        Button("Resume") {
                            navigationPath.append(active.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Start Workout") {
                    isCategoryPickerPresented = true
                }
                .buttonStyle(.borderedProminent)

                Button("Start from Template") {
                    isTemplatePickerPresented = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Templates") {
                        TemplatesView()
                    }
                }
            }
            .sheet(isPresented: $isCategoryPickerPresented) {
                CategoryPickerView { category in
                    do {
                        let session = try viewModel.startSession(
                            categoryName: category,
                            repository: container.sessionRepository
                        )
                        navigationPath.append(session.id)
                        isCategoryPickerPresented = false
                        Task {
                            await viewModel.loadActiveSession(repository: container.sessionRepository)
                        }
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            .sheet(isPresented: $isTemplatePickerPresented) {
                TemplatePickerView { templateId, precreateSets in
                    do {
                        let session = try viewModel.startFromTemplate(
                            templateId: templateId,
                            precreateSets: precreateSets,
                            templateRepository: container.templateRepository
                        )
                        navigationPath.append(session.id)
                        Task {
                            await viewModel.loadActiveSession(repository: container.sessionRepository)
                        }
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
                .environmentObject(container)
            }
            .navigationDestination(for: String.self) { sessionID in
                ActiveSessionView(sessionId: sessionID)
            }
            .onChange(of: navigationPath) { _ in
                Task {
                    await viewModel.loadActiveSession(repository: container.sessionRepository)
                }
            }
            .task {
                await viewModel.loadActiveSession(repository: container.sessionRepository)
            }
            .alert("Unable to Start Session", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

@MainActor
final class LogViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var activeSession: Session?

    func loadActiveSession(repository: SessionRepository) async {
        do {
            activeSession = try repository.fetchMostRecentActiveSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startSession(categoryName: String, repository: SessionRepository) throws -> Session {
        try repository.startSession(name: categoryName)
    }

    func startFromTemplate(
        templateId: String,
        precreateSets: Bool,
        templateRepository: TemplateRepository
    ) throws -> Session {
        try templateRepository.startSessionFromTemplate(
            templateId: templateId,
            sessionName: nil,
            precreateSets: precreateSets
        )
    }
}

#Preview {
    LogView()
}
