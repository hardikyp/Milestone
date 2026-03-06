import Foundation
import GRDB

enum ModelError: Error, LocalizedError {
    case invalidISO8601(String)
    case invalidSet(String)
    case invalidEnum(column: String, value: String)

    var errorDescription: String? {
        switch self {
        case .invalidISO8601(let value):
            return "Invalid ISO-8601 timestamp: \(value)"
        case .invalidSet(let message):
            return message
        case .invalidEnum(let column, let value):
            return "Invalid value '\(value)' for column \(column)"
        }
    }
}

enum DateISO8601 {
    static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from value: String) throws -> Date {
        if let date = formatter.date(from: value) ?? fallbackFormatter.date(from: value) {
            return date
        }
        throw ModelError.invalidISO8601(value)
    }
}

enum ExerciseType: String, Codable, CaseIterable {
    case weight
    case cardio
    case functional
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case push
    case pull
    case legs
    case core
    case cardio
}

enum ExerciseSource: String, Codable, CaseIterable {
    case user
    case seeded
}

enum MetricType: String, Codable, CaseIterable {
    case strength
    case repsOnly = "reps_only"
    case time
    case distanceTime = "distance_time"
    case distanceOnly = "distance_only"
}

struct Exercise: FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "exercises"

    var id: String
    var name: String
    var mediaURI: String?
    var type: ExerciseType
    var category: ExerciseCategory?
    var source: ExerciseSource
    var description: String?
    var targetArea: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        mediaURI: String? = nil,
        type: ExerciseType,
        category: ExerciseCategory? = nil,
        source: ExerciseSource = .user,
        description: String? = nil,
        targetArea: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.mediaURI = mediaURI
        self.type = type
        self.category = category
        self.source = source
        self.description = description
        self.targetArea = targetArea
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(row: Row) throws {
        id = row["id"]
        name = row["name"]
        mediaURI = row["media_uri"]
        let rawType: String = row["type"]
        guard let exerciseType = ExerciseType(rawValue: rawType) else {
            throw ModelError.invalidEnum(column: "type", value: rawType)
        }
        type = exerciseType
        if let rawCategory: String = row["exercise_category"] {
            guard let parsedCategory = ExerciseCategory(rawValue: rawCategory) else {
                throw ModelError.invalidEnum(column: "exercise_category", value: rawCategory)
            }
            category = parsedCategory
        } else {
            category = nil
        }
        if let rawSource: String = row["exercise_source"] {
            guard let parsedSource = ExerciseSource(rawValue: rawSource) else {
                throw ModelError.invalidEnum(column: "exercise_source", value: rawSource)
            }
            source = parsedSource
        } else {
            source = .user
        }
        description = row["description"]
        targetArea = row["target_area"]
        isArchived = (row["is_archived"] as Int) != 0
        createdAt = try DateISO8601.date(from: row["created_at"])
        updatedAt = try DateISO8601.date(from: row["updated_at"])
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["media_uri"] = mediaURI
        container["type"] = type.rawValue
        container["exercise_category"] = category?.rawValue
        container["exercise_source"] = source.rawValue
        container["description"] = description
        container["target_area"] = targetArea
        container["is_archived"] = isArchived ? 1 : 0
        container["created_at"] = DateISO8601.string(from: createdAt)
        container["updated_at"] = DateISO8601.string(from: updatedAt)
    }
}

struct Session: FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "sessions"

    var id: String
    var name: String?
    var startDateTime: Date
    var endDateTime: Date?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String? = nil,
        startDateTime: Date,
        endDateTime: Date? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(row: Row) throws {
        id = row["id"]
        name = row["name"]
        startDateTime = try DateISO8601.date(from: row["start_datetime"])
        if let endValue: String = row["end_datetime"] {
            endDateTime = try DateISO8601.date(from: endValue)
        } else {
            endDateTime = nil
        }
        notes = row["notes"]
        createdAt = try DateISO8601.date(from: row["created_at"])
        updatedAt = try DateISO8601.date(from: row["updated_at"])
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["start_datetime"] = DateISO8601.string(from: startDateTime)
        container["end_datetime"] = endDateTime.map(DateISO8601.string(from:))
        container["notes"] = notes
        container["created_at"] = DateISO8601.string(from: createdAt)
        container["updated_at"] = DateISO8601.string(from: updatedAt)
    }
}

struct SessionExercise: FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "session_exercises"

    var id: String
    var sessionID: String
    var exerciseID: String
    var orderIndex: Int
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        sessionID: String,
        exerciseID: String,
        orderIndex: Int,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.orderIndex = orderIndex
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(row: Row) throws {
        id = row["id"]
        sessionID = row["session_id"]
        exerciseID = row["exercise_id"]
        orderIndex = row["order_index"]
        notes = row["notes"]
        createdAt = try DateISO8601.date(from: row["created_at"])
        updatedAt = try DateISO8601.date(from: row["updated_at"])
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["session_id"] = sessionID
        container["exercise_id"] = exerciseID
        container["order_index"] = orderIndex
        container["notes"] = notes
        container["created_at"] = DateISO8601.string(from: createdAt)
        container["updated_at"] = DateISO8601.string(from: updatedAt)
    }
}

struct WorkoutSet: FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "sets"

    var id: String
    var sessionExerciseID: String
    var setIndex: Int
    var metricType: MetricType
    var reps: Int?
    var weightKg: Double?
    var distanceM: Double?
    var durationSec: Int?
    var comment: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        sessionExerciseID: String,
        setIndex: Int,
        metricType: MetricType,
        reps: Int? = nil,
        weightKg: Double? = nil,
        distanceM: Double? = nil,
        durationSec: Int? = nil,
        comment: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        self.id = id
        self.sessionExerciseID = sessionExerciseID
        self.setIndex = setIndex
        self.metricType = metricType
        self.reps = reps
        self.weightKg = weightKg
        self.distanceM = distanceM
        self.durationSec = durationSec
        self.comment = comment
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        try validate()
    }

    init(row: Row) throws {
        id = row["id"]
        sessionExerciseID = row["session_exercise_id"]
        setIndex = row["set_index"]
        let rawMetricType: String = row["metric_type"]
        guard let decodedMetricType = MetricType(rawValue: rawMetricType) else {
            throw ModelError.invalidEnum(column: "metric_type", value: rawMetricType)
        }
        metricType = decodedMetricType
        reps = row["reps"]
        weightKg = row["weight_kg"]
        distanceM = row["distance_m"]
        durationSec = row["duration_sec"]
        comment = row["comment"]
        createdAt = try DateISO8601.date(from: row["created_at"])
        updatedAt = try DateISO8601.date(from: row["updated_at"])
    }

    mutating func willSave(_ db: Database) throws {
        try validate()
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["session_exercise_id"] = sessionExerciseID
        container["set_index"] = setIndex
        container["metric_type"] = metricType.rawValue
        container["reps"] = reps
        container["weight_kg"] = weightKg
        container["distance_m"] = distanceM
        container["duration_sec"] = durationSec
        container["comment"] = comment
        container["created_at"] = DateISO8601.string(from: createdAt)
        container["updated_at"] = DateISO8601.string(from: updatedAt)
    }

    func validate() throws {
        switch metricType {
        case .strength:
            guard reps != nil, weightKg != nil else {
                throw ModelError.invalidSet("strength set requires reps and weight_kg")
            }
        case .repsOnly:
            guard reps != nil else {
                throw ModelError.invalidSet("reps_only set requires reps")
            }
        case .time:
            guard durationSec != nil else {
                throw ModelError.invalidSet("time set requires duration_sec")
            }
        case .distanceOnly:
            guard distanceM != nil else {
                throw ModelError.invalidSet("distance_only set requires distance_km")
            }
        case .distanceTime:
            guard distanceM != nil, durationSec != nil else {
                throw ModelError.invalidSet("distance_time set requires distance_km and duration_sec")
            }
        }
    }
}

struct Template: FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "templates"

    var id: String
    var name: String
    var description: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(row: Row) throws {
        id = row["id"]
        name = row["name"]
        description = row["description"]
        createdAt = try DateISO8601.date(from: row["created_at"])
        updatedAt = try DateISO8601.date(from: row["updated_at"])
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["description"] = description
        container["created_at"] = DateISO8601.string(from: createdAt)
        container["updated_at"] = DateISO8601.string(from: updatedAt)
    }
}

struct TemplateExercise: FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "template_exercises"

    var id: String
    var templateID: String
    var exerciseID: String
    var orderIndex: Int
    var targetSets: Int?
    var targetReps: Int?
    var targetWeightKg: Double?
    var targetDistanceM: Double?
    var targetDurationSec: Int?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        templateID: String,
        exerciseID: String,
        orderIndex: Int,
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        targetWeightKg: Double? = nil,
        targetDistanceM: Double? = nil,
        targetDurationSec: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.templateID = templateID
        self.exerciseID = exerciseID
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
        self.targetDistanceM = targetDistanceM
        self.targetDurationSec = targetDurationSec
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(row: Row) throws {
        id = row["id"]
        templateID = row["template_id"]
        exerciseID = row["exercise_id"]
        orderIndex = row["order_index"]
        targetSets = row["target_sets"]
        targetReps = row["target_reps"]
        targetWeightKg = row["target_weight_kg"]
        targetDistanceM = row["target_distance_m"]
        targetDurationSec = row["target_duration_sec"]
        notes = row["notes"]
        createdAt = try DateISO8601.date(from: row["created_at"])
        updatedAt = try DateISO8601.date(from: row["updated_at"])
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["template_id"] = templateID
        container["exercise_id"] = exerciseID
        container["order_index"] = orderIndex
        container["target_sets"] = targetSets
        container["target_reps"] = targetReps
        container["target_weight_kg"] = targetWeightKg
        container["target_distance_m"] = targetDistanceM
        container["target_duration_sec"] = targetDurationSec
        container["notes"] = notes
        container["created_at"] = DateISO8601.string(from: createdAt)
        container["updated_at"] = DateISO8601.string(from: updatedAt)
    }
}

struct BodyMetric: FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "body_metrics"

    var id: String
    var dateTime: Date
    var bodyweightKg: Double?
    var bodyfatPct: Double?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        dateTime: Date,
        bodyweightKg: Double? = nil,
        bodyfatPct: Double? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateTime = dateTime
        self.bodyweightKg = bodyweightKg
        self.bodyfatPct = bodyfatPct
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(row: Row) throws {
        id = row["id"]
        dateTime = try DateISO8601.date(from: row["datetime"])
        bodyweightKg = row["bodyweight_kg"]
        bodyfatPct = row["bodyfat_pct"]
        notes = row["notes"]
        createdAt = try DateISO8601.date(from: row["created_at"])
        updatedAt = try DateISO8601.date(from: row["updated_at"])
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["datetime"] = DateISO8601.string(from: dateTime)
        container["bodyweight_kg"] = bodyweightKg
        container["bodyfat_pct"] = bodyfatPct
        container["notes"] = notes
        container["created_at"] = DateISO8601.string(from: createdAt)
        container["updated_at"] = DateISO8601.string(from: updatedAt)
    }
}
