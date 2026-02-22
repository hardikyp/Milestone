import Foundation
import GRDB

enum TemplateRepositoryError: Error, LocalizedError {
    case templateNotFound(String)
    case transactionDidNotReturnValue

    var errorDescription: String? {
        switch self {
        case .templateNotFound(let id):
            return "Template not found: \(id)"
        case .transactionDidNotReturnValue:
            return "Template transaction did not return a value."
        }
    }
}

final class TemplateRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func createTemplate(name: String, description: String? = nil) throws -> Template {
        let now = Date()
        let template = Template(
            name: name,
            description: description,
            createdAt: now,
            updatedAt: now
        )

        try dbQueue.write { db in
            try template.insert(db)
        }

        return template
    }

    func createTemplateFromSession(
        sessionId: String,
        templateName: String,
        description: String? = nil
    ) throws -> Template {
        try dbQueue.write { db in
            var createdTemplate: Template?

            try db.inTransaction {
                guard try Session.fetchOne(db, key: sessionId) != nil else {
                    throw RepositoryError.sessionNotFound(sessionId)
                }

                let now = Date()
                let template = Template(
                    name: templateName,
                    description: description,
                    createdAt: now,
                    updatedAt: now
                )
                try template.insert(db)
                createdTemplate = template

                let sessionExercises = try SessionExercise.fetchAll(
                    db,
                    sql: """
                    SELECT *
                    FROM session_exercises
                    WHERE session_id = ?
                    ORDER BY order_index ASC
                    """,
                    arguments: [sessionId]
                )

                for (index, sessionExercise) in sessionExercises.enumerated() {
                    let setRows = try WorkoutSet.fetchAll(
                        db,
                        sql: """
                        SELECT *
                        FROM sets
                        WHERE session_exercise_id = ?
                        ORDER BY set_index ASC
                        """,
                        arguments: [sessionExercise.id]
                    )

                    let lastSet = setRows.last
                    let templateExercise = TemplateExercise(
                        templateID: template.id,
                        exerciseID: sessionExercise.exerciseID,
                        orderIndex: index + 1,
                        targetSets: setRows.isEmpty ? nil : setRows.count,
                        targetReps: lastSet?.reps,
                        targetWeightKg: lastSet?.weightKg,
                        targetDistanceM: lastSet?.distanceM,
                        targetDurationSec: lastSet?.durationSec,
                        notes: sessionExercise.notes,
                        createdAt: now,
                        updatedAt: now
                    )

                    try templateExercise.insert(db)
                }

                return .commit
            }

            guard let createdTemplate else {
                throw TemplateRepositoryError.transactionDidNotReturnValue
            }
            return createdTemplate
        }
    }

    func fetchTemplates() throws -> [Template] {
        try dbQueue.read { db in
            try Template.fetchAll(
                db,
                sql: """
                SELECT *
                FROM templates
                ORDER BY created_at DESC
                """
            )
        }
    }

    func fetchTemplateExercises(templateId: String) throws -> [TemplateExercise] {
        try dbQueue.read { db in
            try TemplateExercise.fetchAll(
                db,
                sql: """
                SELECT *
                FROM template_exercises
                WHERE template_id = ?
                ORDER BY order_index ASC
                """,
                arguments: [templateId]
            )
        }
    }

    func deleteTemplate(templateId: String) throws {
        try dbQueue.write { db in
            guard let template = try Template.fetchOne(db, key: templateId) else {
                throw TemplateRepositoryError.templateNotFound(templateId)
            }
            _ = try template.delete(db)
        }
    }

    func startSessionFromTemplate(
        templateId: String,
        sessionName: String? = nil,
        precreateSets: Bool
    ) throws -> Session {
        try dbQueue.write { db in
            var createdSession: Session?

            try db.inTransaction {
                guard let template = try Template.fetchOne(db, key: templateId) else {
                    throw TemplateRepositoryError.templateNotFound(templateId)
                }

                let templateExercises = try TemplateExercise.fetchAll(
                    db,
                    sql: """
                    SELECT *
                    FROM template_exercises
                    WHERE template_id = ?
                    ORDER BY order_index ASC
                    """,
                    arguments: [templateId]
                )

                let now = Date()
                let session = Session(
                    name: sessionName ?? template.name,
                    startDateTime: now,
                    endDateTime: nil,
                    notes: nil,
                    createdAt: now,
                    updatedAt: now
                )
                try session.insert(db)
                createdSession = session

                for (offset, templateExercise) in templateExercises.enumerated() {
                    let sessionExercise = SessionExercise(
                        sessionID: session.id,
                        exerciseID: templateExercise.exerciseID,
                        orderIndex: offset + 1,
                        notes: templateExercise.notes,
                        createdAt: now,
                        updatedAt: now
                    )
                    try sessionExercise.insert(db)

                    guard precreateSets else {
                        continue
                    }

                    let targetSets = max(templateExercise.targetSets ?? 0, 0)
                    guard targetSets > 0 else {
                        continue
                    }

                    let inferredMetricType = inferMetricType(from: templateExercise)

                    for setIndex in 1...targetSets {
                        guard
                            let metricType = inferredMetricType,
                            let workoutSet = try buildTemplateSet(
                                sessionExerciseID: sessionExercise.id,
                                setIndex: setIndex,
                                metricType: metricType,
                                templateExercise: templateExercise,
                                now: now
                            )
                        else {
                            continue
                        }

                        var mutableSet = workoutSet
                        try mutableSet.insert(db)
                    }
                }

                return .commit
            }

            guard let createdSession else {
                throw TemplateRepositoryError.transactionDidNotReturnValue
            }
            return createdSession
        }
    }

    private func inferMetricType(from templateExercise: TemplateExercise) -> MetricType? {
        if templateExercise.targetWeightKg != nil, templateExercise.targetReps != nil {
            return .strength
        }
        if templateExercise.targetDistanceM != nil, templateExercise.targetDurationSec != nil {
            return .distanceTime
        }
        if templateExercise.targetDistanceM != nil {
            return .distanceOnly
        }
        if templateExercise.targetDurationSec != nil {
            return .time
        }
        if templateExercise.targetReps != nil {
            return .repsOnly
        }
        return nil
    }

    private func buildTemplateSet(
        sessionExerciseID: String,
        setIndex: Int,
        metricType: MetricType,
        templateExercise: TemplateExercise,
        now: Date
    ) throws -> WorkoutSet? {
        switch metricType {
        case .strength:
            guard
                let reps = templateExercise.targetReps,
                let weight = templateExercise.targetWeightKg
            else {
                return nil
            }
            return try WorkoutSet(
                sessionExerciseID: sessionExerciseID,
                setIndex: setIndex,
                metricType: .strength,
                reps: reps,
                weightKg: weight,
                distanceM: nil,
                durationSec: nil,
                comment: nil,
                createdAt: now,
                updatedAt: now
            )
        case .repsOnly:
            guard let reps = templateExercise.targetReps else { return nil }
            return try WorkoutSet(
                sessionExerciseID: sessionExerciseID,
                setIndex: setIndex,
                metricType: .repsOnly,
                reps: reps,
                weightKg: nil,
                distanceM: nil,
                durationSec: nil,
                comment: nil,
                createdAt: now,
                updatedAt: now
            )
        case .time:
            guard let duration = templateExercise.targetDurationSec else { return nil }
            return try WorkoutSet(
                sessionExerciseID: sessionExerciseID,
                setIndex: setIndex,
                metricType: .time,
                reps: nil,
                weightKg: nil,
                distanceM: nil,
                durationSec: duration,
                comment: nil,
                createdAt: now,
                updatedAt: now
            )
        case .distanceOnly:
            guard let distance = templateExercise.targetDistanceM else { return nil }
            return try WorkoutSet(
                sessionExerciseID: sessionExerciseID,
                setIndex: setIndex,
                metricType: .distanceOnly,
                reps: nil,
                weightKg: nil,
                distanceM: distance,
                durationSec: nil,
                comment: nil,
                createdAt: now,
                updatedAt: now
            )
        case .distanceTime:
            guard
                let distance = templateExercise.targetDistanceM,
                let duration = templateExercise.targetDurationSec
            else {
                return nil
            }
            return try WorkoutSet(
                sessionExerciseID: sessionExerciseID,
                setIndex: setIndex,
                metricType: .distanceTime,
                reps: nil,
                weightKg: nil,
                distanceM: distance,
                durationSec: duration,
                comment: nil,
                createdAt: now,
                updatedAt: now
            )
        }
    }
}
