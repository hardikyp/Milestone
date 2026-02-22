import Foundation
import GRDB

enum AppTab: Hashable {
    case home
    case log
    case history
    case exercises
    case settings
}

final class AppContainer: ObservableObject {
    @Published var selectedTab: AppTab = .home

    let dbManager: DatabaseManager
    let dbQueue: DatabaseQueue

    let exerciseRepository: ExerciseRepository
    let sessionRepository: SessionRepository
    let sessionExerciseRepository: SessionExerciseRepository
    let setRepository: SetRepository
    let templateRepository: TemplateRepository

    init(databaseManager: DatabaseManager) {
        self.dbManager = databaseManager
        self.dbQueue = databaseManager.dbQueue

        self.exerciseRepository = ExerciseRepository(dbQueue: dbQueue)
        self.sessionRepository = SessionRepository(dbQueue: dbQueue)
        self.sessionExerciseRepository = SessionExerciseRepository(dbQueue: dbQueue)
        self.setRepository = SetRepository(dbQueue: dbQueue)
        self.templateRepository = TemplateRepository(dbQueue: dbQueue)
    }
}
