import Foundation
import GRDB

enum AppTab: Hashable {
    case home
    case history
    case exercises
    case settings
}

@MainActor
final class AppContainer: ObservableObject {
    @Published var selectedTab: AppTab = .home

    let dbManager: DatabaseManager
    let dbQueue: DatabaseQueue

    let exerciseRepository: ExerciseRepository
    let sessionRepository: SessionRepository
    let sessionExerciseRepository: SessionExerciseRepository
    let setRepository: SetRepository
    let templateRepository: TemplateRepository

    private let automaticBackupService: AutomaticBackupService
    private var automaticBackupTask: Task<Void, Never>?

    init(databaseManager: DatabaseManager) {
        self.dbManager = databaseManager
        self.dbQueue = databaseManager.dbQueue

        self.exerciseRepository = ExerciseRepository(dbQueue: dbQueue)
        self.sessionRepository = SessionRepository(dbQueue: dbQueue)
        self.sessionExerciseRepository = SessionExerciseRepository(dbQueue: dbQueue)
        self.setRepository = SetRepository(dbQueue: dbQueue)
        self.templateRepository = TemplateRepository(dbQueue: dbQueue)
        self.automaticBackupService = AutomaticBackupService()
    }

    func triggerAutomaticBackupIfNeeded() {
        guard automaticBackupTask == nil else { return }

        let service = automaticBackupService
        let queue = dbQueue

        automaticBackupTask = Task(priority: .background) { [weak self] in
            defer {
                Task { @MainActor in
                    self?.automaticBackupTask = nil
                }
            }

            _ = try? service.performBackupIfNeeded(dbQueue: queue)
        }
    }
}
