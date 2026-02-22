import Foundation
import GRDB

final class SessionRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func startSession(name: String? = nil, categoryTag: String? = nil) throws -> Session {
        // Current schema has no category_tag column. Keeping parameter for API stability.
        _ = categoryTag

        let now = Date()
        let session = Session(
            name: name,
            startDateTime: now,
            endDateTime: nil,
            notes: nil,
            createdAt: now,
            updatedAt: now
        )

        try dbQueue.write { db in
            try session.insert(db)
        }

        return session
    }

    func endSession(sessionId: String, notes: String? = nil) throws -> Session {
        try dbQueue.write { db in
            guard var session = try Session.fetchOne(db, key: sessionId) else {
                throw RepositoryError.sessionNotFound(sessionId)
            }

            let now = Date()
            session.endDateTime = now
            session.notes = notes
            session.updatedAt = now

            try session.update(db)
            return session
        }
    }

    func fetchSessions(limit: Int, offset: Int) throws -> [Session] {
        try dbQueue.read { db in
            try Session.fetchAll(
                db,
                sql: """
                SELECT *
                FROM sessions
                ORDER BY start_datetime DESC
                LIMIT ? OFFSET ?
                """,
                arguments: [limit, offset]
            )
        }
    }

    func fetchSessionsForMonth(month: Date) throws -> [Session] {
        let calendar = Calendar(identifier: .gregorian)

        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month)
        else {
            throw RepositoryError.invalidMonthDate
        }

        let start = DateISO8601.string(from: monthInterval.start)
        let end = DateISO8601.string(from: monthInterval.end)

        return try dbQueue.read { db in
            try Session.fetchAll(
                db,
                sql: """
                SELECT *
                FROM sessions
                WHERE start_datetime >= ?
                  AND start_datetime < ?
                ORDER BY start_datetime DESC
                """,
                arguments: [start, end]
            )
        }
    }

    func fetchMostRecentActiveSession() throws -> Session? {
        try dbQueue.read { db in
            try Session.fetchOne(
                db,
                sql: """
                SELECT *
                FROM sessions
                WHERE end_datetime IS NULL
                ORDER BY start_datetime DESC
                LIMIT 1
                """
            )
        }
    }

    func deleteSession(sessionId: String) throws {
        try dbQueue.write { db in
            guard let session = try Session.fetchOne(db, key: sessionId) else {
                throw RepositoryError.sessionNotFound(sessionId)
            }
            _ = try session.delete(db)
        }
    }
}
