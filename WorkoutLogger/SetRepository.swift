import Foundation
import GRDB

enum SetRepositoryError: Error, LocalizedError {
    case setNotFound(String)
    case invalidSetIndex(Int)
    case sessionExerciseMismatch(expected: String, actual: String)
    case duplicateSetIDs

    var errorDescription: String? {
        switch self {
        case .setNotFound(let id):
            return "Set not found: \(id)"
        case .invalidSetIndex(let value):
            return "set_index must be >= 1. Received: \(value)"
        case .sessionExerciseMismatch(let expected, let actual):
            return "Set belongs to session_exercise_id '\(actual)', expected '\(expected)'."
        case .duplicateSetIDs:
            return "Duplicate set ids in upsert payload."
        }
    }
}

enum FieldUpdate<Value> {
    case unchanged
    case value(Value)
}

final class SetRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func addSet(
        sessionExerciseId: String,
        metricType: MetricType,
        setIndex: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        distanceM: Double? = nil,
        durationSec: Int? = nil,
        comment: String? = nil
    ) throws -> WorkoutSet {
        guard setIndex >= 1 else {
            throw SetRepositoryError.invalidSetIndex(setIndex)
        }

        let now = Date()
        var workoutSet = try WorkoutSet(
            sessionExerciseID: sessionExerciseId,
            setIndex: setIndex,
            metricType: metricType,
            reps: reps,
            weightKg: weightKg,
            distanceM: distanceM,
            durationSec: durationSec,
            comment: comment,
            createdAt: now,
            updatedAt: now
        )

        try dbQueue.write { db in
            try workoutSet.insert(db)
        }

        return workoutSet
    }

    func updateSet(
        setId: String,
        metricType: FieldUpdate<MetricType> = .unchanged,
        setIndex: FieldUpdate<Int> = .unchanged,
        reps: FieldUpdate<Int?> = .unchanged,
        weightKg: FieldUpdate<Double?> = .unchanged,
        distanceM: FieldUpdate<Double?> = .unchanged,
        durationSec: FieldUpdate<Int?> = .unchanged,
        comment: FieldUpdate<String?> = .unchanged
    ) throws -> WorkoutSet {
        try dbQueue.write { db in
            guard var existing = try WorkoutSet.fetchOne(db, key: setId) else {
                throw SetRepositoryError.setNotFound(setId)
            }

            switch metricType {
            case .unchanged: break
            case .value(let value): existing.metricType = value
            }

            switch setIndex {
            case .unchanged: break
            case .value(let value):
                guard value >= 1 else {
                    throw SetRepositoryError.invalidSetIndex(value)
                }
                existing.setIndex = value
            }

            switch reps {
            case .unchanged: break
            case .value(let value): existing.reps = value
            }

            switch weightKg {
            case .unchanged: break
            case .value(let value): existing.weightKg = value
            }

            switch distanceM {
            case .unchanged: break
            case .value(let value): existing.distanceM = value
            }

            switch durationSec {
            case .unchanged: break
            case .value(let value): existing.durationSec = value
            }

            switch comment {
            case .unchanged: break
            case .value(let value): existing.comment = value
            }

            existing.updatedAt = Date()
            try existing.validate()
            try existing.update(db)
            return existing
        }
    }

    func deleteSet(setId: String) throws {
        try dbQueue.write { db in
            _ = try WorkoutSet.deleteOne(db, key: setId)
        }
    }

    func fetchSets(sessionExerciseId: String) throws -> [WorkoutSet] {
        try dbQueue.read { db in
            try WorkoutSet.fetchAll(
                db,
                sql: """
                SELECT *
                FROM sets
                WHERE session_exercise_id = ?
                ORDER BY set_index ASC
                """,
                arguments: [sessionExerciseId]
            )
        }
    }

    func upsertSets(sessionExerciseId: String, sets: [WorkoutSet]) throws {
        try dbQueue.write { db in
            let uniqueIDs = Set(sets.map(\.id))
            guard uniqueIDs.count == sets.count else {
                throw SetRepositoryError.duplicateSetIDs
            }

            let now = Date()
            var normalizedSets: [WorkoutSet] = []
            normalizedSets.reserveCapacity(sets.count)

            for (offset, input) in sets.enumerated() {
                guard input.sessionExerciseID == sessionExerciseId else {
                    throw SetRepositoryError.sessionExerciseMismatch(
                        expected: sessionExerciseId,
                        actual: input.sessionExerciseID
                    )
                }

                var normalized = input
                normalized.sessionExerciseID = sessionExerciseId
                normalized.setIndex = offset + 1
                normalized.updatedAt = now
                try normalized.validate()
                normalizedSets.append(normalized)
            }

            let maxKeptIndex = normalizedSets.count
            try db.execute(
                sql: """
                DELETE FROM sets
                WHERE session_exercise_id = ?
                  AND set_index > ?
                """,
                arguments: [sessionExerciseId, maxKeptIndex]
            )

            let existingById = Dictionary(
                uniqueKeysWithValues: try WorkoutSet
                    .fetchAll(
                        db,
                        sql: """
                        SELECT *
                        FROM sets
                        WHERE session_exercise_id = ?
                        """,
                        arguments: [sessionExerciseId]
                    )
                    .map { ($0.id, $0) }
            )

            for candidate in normalizedSets {
                if existingById[candidate.id] != nil {
                    let toUpdate = candidate
                    try toUpdate.update(db)
                } else {
                    var toInsert = candidate
                    try db.execute(
                        sql: """
                        DELETE FROM sets
                        WHERE session_exercise_id = ?
                          AND set_index = ?
                          AND id <> ?
                        """,
                        arguments: [sessionExerciseId, toInsert.setIndex, toInsert.id]
                    )
                    try toInsert.insert(db)
                }
            }
        }
    }
}
