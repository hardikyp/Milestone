#if DEBUG
import Foundation
import GRDB

enum DataTransferServiceSelfTests {
    private struct TableCounts: Equatable {
        let exercises: Int
        let sessions: Int
        let sessionExercises: Int
        let sets: Int
        let templates: Int
        let templateExercises: Int
        let bodyMetrics: Int
    }

    static func runAll() throws {
        print("DataTransferServiceSelfTests: start")
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("MilestoneDataTransferSelfTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempRoot)
        }

        let suiteName = "milestone.data-transfer.self-tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw DataTransferError.invalidBackupPayload("Unable to initialize isolated defaults for tests.")
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let dbQueue = try DatabaseQueue()
        try Migrations.makeMigrator().migrate(dbQueue)
        print("DataTransferServiceSelfTests: migrated schema")

        try seedSampleData(dbQueue: dbQueue, defaults: defaults)
        print("DataTransferServiceSelfTests: seeded sample data")

        let service = DataTransferService(
            fileManager: fileManager,
            defaults: defaults,
            baseDirectoryURL: tempRoot
        )

        let csvResult = try service.exportCSV(dbQueue: dbQueue)
        try assertCSVSchemaComplete(csvURL: csvResult.fileURL)
        print("DataTransferServiceSelfTests: csv export verified")

        let backupResult = try service.backup(dbQueue: dbQueue)
        print("DataTransferServiceSelfTests: backup created at \(backupResult.fileURL.path)")
        let baselineCounts = try tableCounts(dbQueue: dbQueue)

        _ = try service.restore(from: backupResult.fileURL, dbQueue: dbQueue)
        print("DataTransferServiceSelfTests: first restore complete")
        let afterFirstRestore = try tableCounts(dbQueue: dbQueue)

        _ = try service.restore(from: backupResult.fileURL, dbQueue: dbQueue)
        print("DataTransferServiceSelfTests: second restore complete")
        let afterSecondRestore = try tableCounts(dbQueue: dbQueue)

        guard afterFirstRestore == afterSecondRestore, afterSecondRestore == baselineCounts else {
            throw DataTransferError.invalidBackupPayload("Restore idempotency check failed.")
        }

        let invalidPayloadURL = tempRoot.appendingPathComponent("invalid-backup.json", isDirectory: false)
        try Data("{\"payloadVersion\": 999}".utf8).write(to: invalidPayloadURL, options: .atomic)

        do {
            _ = try service.restore(from: invalidPayloadURL, dbQueue: dbQueue)
            throw DataTransferError.invalidBackupPayload("Expected restore to fail for unsupported version payload.")
        } catch DataTransferError.unsupportedPayloadVersion {
            // Expected path.
            print("DataTransferServiceSelfTests: unsupported-version error path verified")
        }
    }

    private static func seedSampleData(dbQueue: DatabaseQueue, defaults: UserDefaults) throws {
        let now = Date()

        try dbQueue.write { db in
            let exercise = Exercise(
                id: "exercise-test-1",
                name: "Test Exercise",
                mediaURI: nil,
                type: .weight,
                category: .push,
                source: .user,
                description: "seed",
                targetArea: "Chest",
                isArchived: false,
                createdAt: now,
                updatedAt: now
            )
            try exercise.insert(db)

            let session = Session(
                id: "session-test-1",
                name: "Test Session",
                startDateTime: now,
                endDateTime: now,
                notes: nil,
                createdAt: now,
                updatedAt: now
            )
            try session.insert(db)

            let sessionExercise = SessionExercise(
                id: "session-exercise-test-1",
                sessionID: session.id,
                exerciseID: exercise.id,
                orderIndex: 1,
                notes: nil,
                createdAt: now,
                updatedAt: now
            )
            try sessionExercise.insert(db)

            var workoutSet = try WorkoutSet(
                id: "set-test-1",
                sessionExerciseID: sessionExercise.id,
                setIndex: 1,
                metricType: .strength,
                reps: 10,
                weightKg: 40,
                distanceM: nil,
                durationSec: nil,
                comment: nil,
                createdAt: now,
                updatedAt: now
            )
            try workoutSet.insert(db)

            let template = Template(
                id: "template-test-1",
                name: "Template",
                description: "seed",
                createdAt: now,
                updatedAt: now
            )
            try template.insert(db)

            let templateExercise = TemplateExercise(
                id: "template-exercise-test-1",
                templateID: template.id,
                exerciseID: exercise.id,
                orderIndex: 1,
                targetSets: 3,
                targetReps: 10,
                targetWeightKg: 40,
                targetDistanceM: nil,
                targetDurationSec: nil,
                notes: nil,
                createdAt: now,
                updatedAt: now
            )
            try templateExercise.insert(db)

            let bodyMetric = BodyMetric(
                id: "body-metric-test-1",
                dateTime: now,
                bodyweightKg: 70,
                bodyfatPct: 12,
                notes: nil,
                createdAt: now,
                updatedAt: now
            )
            try bodyMetric.insert(db)
        }

        defaults.set("Self", forKey: "settings.firstName")
        defaults.set("Tester", forKey: "settings.lastName")
        defaults.set("kg", forKey: "settings.weightUnit")
        defaults.set("km", forKey: "settings.distanceUnit")
    }

    private static func assertCSVSchemaComplete(csvURL: URL) throws {
        let csv = try String(contentsOf: csvURL)
        guard let header = csv.components(separatedBy: "\n").first else {
            throw DataTransferError.invalidBackupPayload("CSV export is missing a header row.")
        }

        let expectedColumns: [String] = [
            "session_id",
            "session_name",
            "start_datetime",
            "end_datetime",
            "session_notes",
            "session_exercise_id",
            "exercise_id",
            "exercise_name",
            "exercise_type",
            "exercise_category",
            "set_id",
            "set_index",
            "metric_type",
            "reps",
            "weight_kg",
            "distance_m",
            "duration_sec",
            "set_comment"
        ]

        for column in expectedColumns where !header.contains(column) {
            throw DataTransferError.invalidBackupPayload("CSV header missing expected column: \(column)")
        }
    }

    private static func tableCounts(dbQueue: DatabaseQueue) throws -> TableCounts {
        try dbQueue.read { db in
            TableCounts(
                exercises: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM exercises") ?? 0,
                sessions: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sessions") ?? 0,
                sessionExercises: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM session_exercises") ?? 0,
                sets: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sets") ?? 0,
                templates: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM templates") ?? 0,
                templateExercises: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM template_exercises") ?? 0,
                bodyMetrics: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM body_metrics") ?? 0
            )
        }
    }
}
#endif
