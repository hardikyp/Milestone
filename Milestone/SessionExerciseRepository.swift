import Foundation
import GRDB

final class SessionExerciseRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func addExerciseToSession(
        sessionId: String,
        exerciseId: String,
        orderIndex: Int,
        notes: String? = nil
    ) throws -> SessionExercise {
        let now = Date()
        let sessionExercise = SessionExercise(
            sessionID: sessionId,
            exerciseID: exerciseId,
            orderIndex: orderIndex,
            notes: notes,
            createdAt: now,
            updatedAt: now
        )

        try dbQueue.write { db in
            try sessionExercise.insert(db)
        }

        return sessionExercise
    }

    func reorderSessionExercises(sessionId: String, orderedIds: [String]) throws {
        try dbQueue.write { db in
            let existingIDs = try String.fetchAll(
                db,
                sql: """
                SELECT id
                FROM session_exercises
                WHERE session_id = ?
                """,
                arguments: [sessionId]
            )

            guard existingIDs.count == orderedIds.count,
                  Set(existingIDs) == Set(orderedIds) else {
                throw RepositoryError.invalidOrderedIDs
            }

            let updatedAt = DateISO8601.string(from: Date())

            for (index, id) in orderedIds.enumerated() {
                try db.execute(
                    sql: """
                    UPDATE session_exercises
                    SET order_index = ?, updated_at = ?
                    WHERE id = ? AND session_id = ?
                    """,
                    arguments: [index, updatedAt, id, sessionId]
                )
            }
        }
    }

    func fetchSessionExercises(sessionId: String) throws -> [SessionExercise] {
        try dbQueue.read { db in
            try SessionExercise.fetchAll(
                db,
                sql: """
                SELECT *
                FROM session_exercises
                WHERE session_id = ?
                ORDER BY order_index ASC
                """,
                arguments: [sessionId]
            )
        }
    }

    func removeExerciseFromSession(sessionExerciseId: String) throws {
        try dbQueue.write { db in
            guard let target = try SessionExercise.fetchOne(db, key: sessionExerciseId) else {
                throw RepositoryError.sessionExerciseNotFound(sessionExerciseId)
            }

            try target.delete(db)

            let remaining = try SessionExercise.fetchAll(
                db,
                sql: """
                SELECT *
                FROM session_exercises
                WHERE session_id = ?
                ORDER BY order_index ASC
                """,
                arguments: [target.sessionID]
            )

            let updatedAt = DateISO8601.string(from: Date())
            for (index, item) in remaining.enumerated() {
                try db.execute(
                    sql: """
                    UPDATE session_exercises
                    SET order_index = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    arguments: [index, updatedAt, item.id]
                )
            }
        }
    }
}
