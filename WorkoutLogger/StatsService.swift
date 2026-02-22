import Foundation
import GRDB

final class StatsService {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func totalVolumeKg(sessionId: String) throws -> Double {
        try dbQueue.read { db in
            let volume = try Double.fetchOne(
                db,
                sql: """
                SELECT COALESCE(SUM(CAST(s.reps AS REAL) * s.weight_kg), 0)
                FROM sets s
                JOIN session_exercises se ON se.id = s.session_exercise_id
                WHERE se.session_id = ?
                  AND s.reps IS NOT NULL
                  AND s.weight_kg IS NOT NULL
                """,
                arguments: [sessionId]
            )

            return volume ?? 0
        }
    }

    func duration(session: Session) -> TimeInterval? {
        guard let endDateTime = session.endDateTime else {
            return nil
        }

        return max(0, endDateTime.timeIntervalSince(session.startDateTime))
    }
}
