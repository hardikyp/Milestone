import Foundation
import GRDB

enum RepositoryError: Error, LocalizedError {
    case invalidMonthDate
    case sessionNotFound(String)
    case invalidOrderedIDs
    case exerciseNotFound(String)
    case invalidSeedData
    case cannotDeleteSeededExercise(String)
    case exerciseInUse(String)

    var errorDescription: String? {
        switch self {
        case .invalidMonthDate:
            return "Unable to compute month boundaries for the provided date."
        case .sessionNotFound(let id):
            return "Session not found: \(id)"
        case .invalidOrderedIDs:
            return "orderedIds must exactly match session_exercise IDs for the session."
        case .exerciseNotFound(let id):
            return "Exercise not found: \(id)"
        case .invalidSeedData:
            return "Seed exercise data is invalid."
        case .cannotDeleteSeededExercise:
            return "Seeded exercises cannot be deleted."
        case .exerciseInUse:
            return "This exercise is already used in session or template history and cannot be deleted."
        }
    }
}

struct SeedExercisePayload: Decodable {
    let id: String
    let name: String
    let type: ExerciseType
    let category: ExerciseCategory?
    let description: String?
    let targetArea: String?
    let mediaURI: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case category
        case description
        case targetArea = "target_area"
        case mediaURI = "media_uri"
    }
}

struct ExerciseSeedPruneResult {
    let deletedCount: Int
    let skippedReferencedCount: Int
}

final class ExerciseRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func createExercise(
        name: String,
        type: ExerciseType,
        category: ExerciseCategory? = nil,
        description: String? = nil,
        targetArea: String? = nil,
        mediaUri: String? = nil
    ) throws -> Exercise {
        let now = Date()
        let exercise = Exercise(
            name: name,
            mediaURI: mediaUri,
            type: type,
            category: category,
            source: .user,
            description: description,
            targetArea: targetArea,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )

        try dbQueue.write { db in
            try exercise.insert(db)
        }

        return exercise
    }

    func updateExercise(
        id: String,
        name: String,
        type: ExerciseType,
        category: ExerciseCategory?,
        description: String?,
        targetArea: String?,
        mediaUri: String?
    ) throws -> Exercise {
        try dbQueue.write { db in
            guard var existing = try Exercise.fetchOne(db, key: id) else {
                throw RepositoryError.exerciseNotFound(id)
            }

            existing.name = name
            existing.type = type
            existing.category = category
            existing.description = description
            existing.targetArea = targetArea
            existing.mediaURI = mediaUri
            existing.updatedAt = Date()

            try existing.update(db)
            return existing
        }
    }

    func fetchAllExercises(includeArchived: Bool) throws -> [Exercise] {
        try dbQueue.read { db in
            if includeArchived {
                return try Exercise.fetchAll(db, sql: """
                    SELECT *
                    FROM exercises
                    ORDER BY name COLLATE NOCASE ASC
                    """)
            }

            return try Exercise.fetchAll(db, sql: """
                SELECT *
                FROM exercises
                WHERE is_archived = 0
                ORDER BY name COLLATE NOCASE ASC
                """)
        }
    }

    func searchExercises(query: String, includeArchived: Bool) throws -> [Exercise] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try fetchAllExercises(includeArchived: includeArchived)
        }

        let pattern = "%\(escapeLike(trimmed))%"

        return try dbQueue.read { db in
            if includeArchived {
                return try Exercise.fetchAll(db, sql: """
                    SELECT *
                    FROM exercises
                    WHERE name LIKE ? ESCAPE '\\'
                       OR COALESCE(description, '') LIKE ? ESCAPE '\\'
                       OR COALESCE(target_area, '') LIKE ? ESCAPE '\\'
                    ORDER BY name COLLATE NOCASE ASC
                    """, arguments: [pattern, pattern, pattern])
            }

            return try Exercise.fetchAll(db, sql: """
                SELECT *
                FROM exercises
                WHERE is_archived = 0
                  AND (
                        name LIKE ? ESCAPE '\\'
                     OR COALESCE(description, '') LIKE ? ESCAPE '\\'
                     OR COALESCE(target_area, '') LIKE ? ESCAPE '\\'
                  )
                ORDER BY name COLLATE NOCASE ASC
                """, arguments: [pattern, pattern, pattern])
        }
    }

    func archiveExercise(id: String, archived: Bool) throws {
        let now = DateISO8601.string(from: Date())

        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE exercises
                SET is_archived = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [archived ? 1 : 0, now, id]
            )
        }
    }

    func deleteExercise(id: String) throws {
        try dbQueue.write { db in
            guard let exercise = try Exercise.fetchOne(db, key: id) else {
                throw RepositoryError.exerciseNotFound(id)
            }

            guard exercise.source != .seeded else {
                throw RepositoryError.cannotDeleteSeededExercise(id)
            }

            do {
                _ = try exercise.delete(db)
            } catch let error as GRDB.DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
                throw RepositoryError.exerciseInUse(id)
            }
        }
    }

    func deleteNonSeededExercises() throws -> ExerciseSeedPruneResult {
        try dbQueue.write { db in
            let candidateIDs = try String.fetchAll(
                db,
                sql: """
                    SELECT id
                    FROM exercises
                    WHERE COALESCE(exercise_source, 'user') != 'seeded'
                    """
            )

            var deletedCount = 0
            var skippedReferencedCount = 0

            for id in candidateIDs {
                do {
                    try db.execute(
                        sql: "DELETE FROM exercises WHERE id = ?",
                        arguments: [id]
                    )
                    deletedCount += 1
                } catch let error as GRDB.DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
                    skippedReferencedCount += 1
                }
            }

            return ExerciseSeedPruneResult(
                deletedCount: deletedCount,
                skippedReferencedCount: skippedReferencedCount
            )
        }
    }

    func deleteExercisesNotInSeedList(seedIDs: [String]) throws -> ExerciseSeedPruneResult {
        let normalizedSeedIDs = seedIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalizedSeedIDs.isEmpty else {
            throw RepositoryError.invalidSeedData
        }

        return try dbQueue.write { db in
            let placeholders = Array(repeating: "?", count: normalizedSeedIDs.count).joined(separator: ",")
            let sql = """
                SELECT id
                FROM exercises
                WHERE id NOT IN (\(placeholders))
                """
            let candidateIDs = try String.fetchAll(db, sql: sql, arguments: StatementArguments(normalizedSeedIDs))

            var deletedCount = 0
            var skippedReferencedCount = 0

            for id in candidateIDs {
                do {
                    try db.execute(
                        sql: "DELETE FROM exercises WHERE id = ?",
                        arguments: [id]
                    )
                    deletedCount += 1
                } catch let error as GRDB.DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
                    skippedReferencedCount += 1
                }
            }

            return ExerciseSeedPruneResult(
                deletedCount: deletedCount,
                skippedReferencedCount: skippedReferencedCount
            )
        }
    }

    @discardableResult
    func upsertSeedExercises(_ seedExercises: [SeedExercisePayload]) throws -> Int {
        guard !seedExercises.isEmpty else {
            return 0
        }

        return try dbQueue.write { db in
            var upsertedCount = 0
            let now = Date()

            for payload in seedExercises {
                guard !payload.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !payload.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw RepositoryError.invalidSeedData
                }

                if var existing = try Exercise.fetchOne(db, key: payload.id) {
                    existing.name = payload.name
                    existing.type = payload.type
                    existing.category = payload.category
                    existing.source = .seeded
                    existing.description = payload.description
                    existing.targetArea = payload.targetArea
                    existing.mediaURI = payload.mediaURI
                    existing.updatedAt = now
                    try existing.update(db)
                } else {
                    let created = Exercise(
                        id: payload.id,
                        name: payload.name,
                        mediaURI: payload.mediaURI,
                        type: payload.type,
                        category: payload.category,
                        source: .seeded,
                        description: payload.description,
                        targetArea: payload.targetArea,
                        isArchived: false,
                        createdAt: now,
                        updatedAt: now
                    )
                    try created.insert(db)
                }

                upsertedCount += 1
            }

            return upsertedCount
        }
    }

    func reconcileSeededExerciseSources(seedIDs: [String]) throws {
        let normalizedSeedIDs = seedIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalizedSeedIDs.isEmpty else {
            throw RepositoryError.invalidSeedData
        }

        try dbQueue.write { db in
            let now = DateISO8601.string(from: Date())
            let placeholders = Array(repeating: "?", count: normalizedSeedIDs.count).joined(separator: ",")

            var demoteArgs = StatementArguments([now])
            demoteArgs += StatementArguments(normalizedSeedIDs)
            try db.execute(
                sql: """
                    UPDATE exercises
                    SET exercise_source = 'user',
                        updated_at = ?
                    WHERE COALESCE(exercise_source, 'user') = 'seeded'
                      AND id NOT IN (\(placeholders))
                    """,
                arguments: demoteArgs
            )

            var promoteArgs = StatementArguments([now])
            promoteArgs += StatementArguments(normalizedSeedIDs)
            try db.execute(
                sql: """
                    UPDATE exercises
                    SET exercise_source = 'seeded',
                        updated_at = ?
                    WHERE id IN (\(placeholders))
                    """,
                arguments: promoteArgs
            )
        }
    }

    private func escapeLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
