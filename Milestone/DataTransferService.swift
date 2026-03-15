import Foundation
import GRDB

enum DataTransferError: Error, LocalizedError {
    case documentsDirectoryUnavailable
    case failedToPrepareFilesDirectory
    case failedToCreateBookmark(String)
    case selectedExportFolderUnavailable
    case failedToAccessSelectedExportFolder
    case invalidBackupPayload(String)
    case unsupportedPayloadVersion(Int)
    case duplicateIdentifier(table: String)
    case missingReference(table: String, id: String, referenceTable: String, referenceID: String)
    case unreadableFile(String)

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "Unable to access the app Documents directory."
        case .failedToPrepareFilesDirectory:
            return "Unable to prepare the app's Files folder."
        case .failedToCreateBookmark(let message):
            return "Unable to save the selected export folder: \(message)"
        case .selectedExportFolderUnavailable:
            return "The selected export folder is no longer available. Choose it again."
        case .failedToAccessSelectedExportFolder:
            return "Unable to access the selected export folder."
        case .invalidBackupPayload(let message):
            return "Invalid backup payload: \(message)"
        case .unsupportedPayloadVersion(let version):
            return "Unsupported backup payload version: \(version)."
        case .duplicateIdentifier(let table):
            return "Backup payload contains duplicate ids in \(table)."
        case .missingReference(let table, let id, let referenceTable, let referenceID):
            return "Record \(id) in \(table) references missing \(referenceTable) id \(referenceID)."
        case .unreadableFile(let message):
            return "Unable to read selected file: \(message)"
        }
    }
}

struct DataTransferExportResult {
    let fileURL: URL
    let summary: String
}

struct DataTransferRestoreResult {
    let sourceURL: URL
    let stagedURL: URL
    let summary: String
}

struct ExportDestinationInfo {
    let displayName: String
    let detail: String
    let isExternal: Bool
}

struct DataTransferService {
    private static let currentPayloadVersion = 2

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let baseDirectoryURL: URL?

    private enum Keys {
        static let externalExportFolderBookmark = "dataTransfer.externalExportFolderBookmark"
        static let externalExportFolderName = "dataTransfer.externalExportFolderName"
    }

    private struct ResolvedExportDirectory {
        let url: URL
        let isExternal: Bool
        let displayName: String
    }

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        baseDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
        self.baseDirectoryURL = baseDirectoryURL
    }

    func appDocumentsURL() throws -> URL {
        let documentsURL: URL
        if let baseDirectoryURL {
            documentsURL = baseDirectoryURL
        } else {
            guard let resolvedDocumentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw DataTransferError.documentsDirectoryUnavailable
            }
            documentsURL = resolvedDocumentsURL
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: documentsURL.path, isDirectory: &isDirectory)

        guard exists, isDirectory.boolValue else {
            throw DataTransferError.failedToPrepareFilesDirectory
        }

        return documentsURL
    }

    @discardableResult
    func prepareFilesDirectory() throws -> URL {
        let documentsURL = try appDocumentsURL()
        let exportsFolderURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: exportsFolderURL.path, isDirectory: &isDirectory)

        if exists {
            if isDirectory.boolValue {
                return exportsFolderURL
            }
            throw DataTransferError.failedToPrepareFilesDirectory
        }

        do {
            try fileManager.createDirectory(at: exportsFolderURL, withIntermediateDirectories: true)
            return exportsFolderURL
        } catch {
            throw DataTransferError.failedToPrepareFilesDirectory
        }
    }

    func exportsFolderPath() -> String {
        (try? prepareFilesDirectory().path) ?? "Unavailable"
    }

    func exportDestinationInfo() -> ExportDestinationInfo {
        if let external = try? resolveExternalExportDirectory() {
            return ExportDestinationInfo(
                displayName: external.displayName,
                detail: "Custom folder: \(external.displayName)",
                isExternal: true
            )
        }

        return ExportDestinationInfo(
            displayName: "Milestone > Exports",
            detail: "Files > On My iPhone > Milestone > Exports",
            isExternal: false
        )
    }

    func hasExternalExportFolderSelection() -> Bool {
        defaults.data(forKey: Keys.externalExportFolderBookmark) != nil
    }

    @discardableResult
    func saveExternalExportFolderSelection(_ folderURL: URL) throws -> ExportDestinationInfo {
        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let bookmark = try folderURL.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: Keys.externalExportFolderBookmark)

            let displayName = Self.displayName(for: folderURL)
            defaults.set(displayName, forKey: Keys.externalExportFolderName)

            return ExportDestinationInfo(
                displayName: displayName,
                detail: "Custom folder: \(displayName)",
                isExternal: true
            )
        } catch {
            throw DataTransferError.failedToCreateBookmark(error.localizedDescription)
        }
    }

    func clearExternalExportFolderSelection() {
        defaults.removeObject(forKey: Keys.externalExportFolderBookmark)
        defaults.removeObject(forKey: Keys.externalExportFolderName)
    }

    func exportCSV(dbQueue: DatabaseQueue) throws -> DataTransferExportResult {
        let csvString = try makeCSV(dbQueue: dbQueue)
        let destination = try writeFile(
            data: Data(csvString.utf8),
            filenamePrefix: "sessions-export",
            pathExtension: "csv"
        )

        return DataTransferExportResult(
            fileURL: destination,
            summary: "CSV export saved to \(destination.path)."
        )
    }

    func exportJSON(dbQueue: DatabaseQueue) throws -> DataTransferExportResult {
        let payload = try makeSnapshotPayload(dbQueue: dbQueue)
        let envelope = PayloadEnvelopeV1(
            kind: .jsonExport,
            payloadVersion: Self.currentPayloadVersion,
            generatedAt: DateISO8601.string(from: Date()),
            appVersion: Self.appVersionString,
            payload: payload
        )

        let data = try encodeEnvelope(envelope)
        let destination = try writeFile(
            data: data,
            filenamePrefix: "full-export",
            pathExtension: "json"
        )

        return DataTransferExportResult(
            fileURL: destination,
            summary: "JSON export saved to \(destination.path)."
        )
    }

    func backup(dbQueue: DatabaseQueue) throws -> DataTransferExportResult {
        let payload = try makeSnapshotPayload(dbQueue: dbQueue)
        let envelope = PayloadEnvelopeV1(
            kind: .backup,
            payloadVersion: Self.currentPayloadVersion,
            generatedAt: DateISO8601.string(from: Date()),
            appVersion: Self.appVersionString,
            payload: payload
        )

        let data = try encodeEnvelope(envelope)
        let destination = try writeFile(
            data: data,
            filenamePrefix: "backup-v\(Self.currentPayloadVersion)",
            pathExtension: "json"
        )

        return DataTransferExportResult(
            fileURL: destination,
            summary: "Backup saved to \(destination.path)."
        )
    }

    func restore(from selectedFileURL: URL, dbQueue: DatabaseQueue) throws -> DataTransferRestoreResult {
        let stagedURL = try stageRestoreSource(selectedFileURL)

        let payloadData: Data
        do {
            payloadData = try Data(contentsOf: stagedURL)
        } catch {
            throw DataTransferError.unreadableFile(error.localizedDescription)
        }

        let envelope = try decodeEnvelope(payloadData)
        try validatePayload(envelope.payload)

        let restoredSummary = try dbQueue.write { db in
            try clearDataTables(db)
            try persistPayload(envelope.payload, db: db)
            return "Restored \(envelope.payload.exercises.count) exercises, \(envelope.payload.sessions.count) sessions, \(envelope.payload.sessionExercises.count) session exercises, \(envelope.payload.sets.count) sets, \(envelope.payload.templates.count) templates, \(envelope.payload.templateExercises.count) template exercises, and \(envelope.payload.bodyMetrics.count) body metrics."
        }

        applySettings(envelope.payload.settings)

        return DataTransferRestoreResult(
            sourceURL: selectedFileURL,
            stagedURL: stagedURL,
            summary: "\(restoredSummary) Source: \(selectedFileURL.lastPathComponent)."
        )
    }

    private func encodeEnvelope(_ envelope: PayloadEnvelopeV1) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    private func decodeEnvelope(_ data: Data) throws -> PayloadEnvelopeV1 {
        let decoder = JSONDecoder()

        if let envelope = try? decoder.decode(PayloadEnvelopeV1.self, from: data) {
            guard envelope.payloadVersion <= Self.currentPayloadVersion else {
                throw DataTransferError.unsupportedPayloadVersion(envelope.payloadVersion)
            }
            if envelope.payloadVersion == 1 {
                return PayloadEnvelopeV1(
                    kind: envelope.kind,
                    payloadVersion: Self.currentPayloadVersion,
                    generatedAt: envelope.generatedAt,
                    appVersion: envelope.appVersion,
                    payload: Self.migratePayloadDistanceMetersToKilometers(envelope.payload)
                )
            }
            return envelope
        }

        if let legacy = try? decoder.decode(LegacyPayloadV0.self, from: data) {
            return PayloadEnvelopeV1(
                kind: .backup,
                payloadVersion: Self.currentPayloadVersion,
                generatedAt: DateISO8601.string(from: Date()),
                appVersion: Self.appVersionString,
                payload: Self.migratePayloadDistanceMetersToKilometers(legacy.migratedToV1())
            )
        }

        if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = raw["payloadVersion"] as? Int,
           version > Self.currentPayloadVersion {
            throw DataTransferError.unsupportedPayloadVersion(version)
        }

        throw DataTransferError.invalidBackupPayload("Unsupported payload structure.")
    }

    private func makeSnapshotPayload(dbQueue: DatabaseQueue) throws -> PayloadV1 {
        try dbQueue.read { db in
            let exercises = try Exercise.fetchAll(db, sql: "SELECT * FROM exercises ORDER BY created_at ASC, id ASC")
            let sessions = try Session.fetchAll(db, sql: "SELECT * FROM sessions ORDER BY created_at ASC, id ASC")
            let sessionExercises = try SessionExercise.fetchAll(db, sql: "SELECT * FROM session_exercises ORDER BY created_at ASC, id ASC")
            let sets = try WorkoutSet.fetchAll(db, sql: "SELECT * FROM sets ORDER BY created_at ASC, id ASC")
            let templates = try Template.fetchAll(db, sql: "SELECT * FROM templates ORDER BY created_at ASC, id ASC")
            let templateExercises = try TemplateExercise.fetchAll(db, sql: "SELECT * FROM template_exercises ORDER BY created_at ASC, id ASC")
            let bodyMetrics = try BodyMetric.fetchAll(db, sql: "SELECT * FROM body_metrics ORDER BY created_at ASC, id ASC")

            return PayloadV1(
                exercises: exercises.map(ExerciseRecord.init(model:)),
                sessions: sessions.map(SessionRecord.init(model:)),
                sessionExercises: sessionExercises.map(SessionExerciseRecord.init(model:)),
                sets: sets.map(SetRecord.init(model:)),
                templates: templates.map(TemplateRecord.init(model:)),
                templateExercises: templateExercises.map(TemplateExerciseRecord.init(model:)),
                bodyMetrics: bodyMetrics.map(BodyMetricRecord.init(model:)),
                settings: SettingsSnapshot(defaults: defaults)
            )
        }
    }

    private func makeCSV(dbQueue: DatabaseQueue) throws -> String {
        let header = [
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

        let rows = try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT
                  s.id AS session_id,
                  s.name AS session_name,
                  s.start_datetime,
                  s.end_datetime,
                  s.notes AS session_notes,
                  se.id AS session_exercise_id,
                  e.id AS exercise_id,
                  e.name AS exercise_name,
                  e.type AS exercise_type,
                  e.exercise_category,
                  ws.id AS set_id,
                  ws.set_index,
                  ws.metric_type,
                  ws.reps,
                  ws.weight_kg,
                  ws.distance_m,
                  ws.duration_sec,
                  ws.comment AS set_comment
                FROM sessions s
                LEFT JOIN session_exercises se ON se.session_id = s.id
                LEFT JOIN exercises e ON e.id = se.exercise_id
                LEFT JOIN sets ws ON ws.session_exercise_id = se.id
                ORDER BY s.start_datetime DESC, se.order_index ASC, ws.set_index ASC
                """
            )
        }

        var lines: [String] = [header.map(Self.csvEscape).joined(separator: ",")]

        for row in rows {
            let setIndexText: String? = (row["set_index"] as Int?).map { String($0) }
            let repsText: String? = (row["reps"] as Int?).map { String($0) }
            let weightText: String? = (row["weight_kg"] as Double?).map { String($0) }
            let distanceText: String? = (row["distance_m"] as Double?).map { String($0) }
            let durationText: String? = (row["duration_sec"] as Int?).map { String($0) }

            let fields: [String?] = [
                row["session_id"] as String?,
                row["session_name"] as String?,
                row["start_datetime"] as String?,
                row["end_datetime"] as String?,
                row["session_notes"] as String?,
                row["session_exercise_id"] as String?,
                row["exercise_id"] as String?,
                row["exercise_name"] as String?,
                row["exercise_type"] as String?,
                row["exercise_category"] as String?,
                row["set_id"] as String?,
                setIndexText,
                row["metric_type"] as String?,
                repsText,
                weightText,
                distanceText,
                durationText,
                row["set_comment"] as String?
            ]

            lines.append(fields.map { Self.csvEscape($0 ?? "") }.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private func validatePayload(_ payload: PayloadV1) throws {
        try validateUniqueIDs(payload.exercises.map(\.id), table: "exercises")
        try validateUniqueIDs(payload.sessions.map(\.id), table: "sessions")
        try validateUniqueIDs(payload.sessionExercises.map(\.id), table: "session_exercises")
        try validateUniqueIDs(payload.sets.map(\.id), table: "sets")
        try validateUniqueIDs(payload.templates.map(\.id), table: "templates")
        try validateUniqueIDs(payload.templateExercises.map(\.id), table: "template_exercises")
        try validateUniqueIDs(payload.bodyMetrics.map(\.id), table: "body_metrics")

        let exerciseIDs = Set(payload.exercises.map(\.id))
        let sessionIDs = Set(payload.sessions.map(\.id))
        let sessionExerciseIDs = Set(payload.sessionExercises.map(\.id))
        let templateIDs = Set(payload.templates.map(\.id))

        for item in payload.sessionExercises {
            guard sessionIDs.contains(item.sessionID) else {
                throw DataTransferError.missingReference(
                    table: "session_exercises",
                    id: item.id,
                    referenceTable: "sessions",
                    referenceID: item.sessionID
                )
            }
            guard exerciseIDs.contains(item.exerciseID) else {
                throw DataTransferError.missingReference(
                    table: "session_exercises",
                    id: item.id,
                    referenceTable: "exercises",
                    referenceID: item.exerciseID
                )
            }
        }

        for item in payload.sets {
            guard sessionExerciseIDs.contains(item.sessionExerciseID) else {
                throw DataTransferError.missingReference(
                    table: "sets",
                    id: item.id,
                    referenceTable: "session_exercises",
                    referenceID: item.sessionExerciseID
                )
            }
        }

        for item in payload.templateExercises {
            guard templateIDs.contains(item.templateID) else {
                throw DataTransferError.missingReference(
                    table: "template_exercises",
                    id: item.id,
                    referenceTable: "templates",
                    referenceID: item.templateID
                )
            }
            guard exerciseIDs.contains(item.exerciseID) else {
                throw DataTransferError.missingReference(
                    table: "template_exercises",
                    id: item.id,
                    referenceTable: "exercises",
                    referenceID: item.exerciseID
                )
            }
        }
    }

    private func validateUniqueIDs(_ ids: [String], table: String) throws {
        if Set(ids).count != ids.count {
            throw DataTransferError.duplicateIdentifier(table: table)
        }
    }

    private func clearDataTables(_ db: Database) throws {
        try db.execute(sql: "DELETE FROM sets")
        try db.execute(sql: "DELETE FROM session_exercises")
        try db.execute(sql: "DELETE FROM sessions")
        try db.execute(sql: "DELETE FROM template_exercises")
        try db.execute(sql: "DELETE FROM templates")
        try db.execute(sql: "DELETE FROM body_metrics")
        try db.execute(sql: "DELETE FROM exercises")
    }

    private func persistPayload(_ payload: PayloadV1, db: Database) throws {
        for record in payload.exercises {
            let exercise = try record.toModel()
            try exercise.insert(db)
        }

        for record in payload.sessions {
            let session = try record.toModel()
            try session.insert(db)
        }

        for record in payload.sessionExercises {
            let sessionExercise = try record.toModel()
            try sessionExercise.insert(db)
        }

        for record in payload.sets {
            var set = try record.toModel()
            try set.insert(db)
        }

        for record in payload.templates {
            let template = try record.toModel()
            try template.insert(db)
        }

        for record in payload.templateExercises {
            let templateExercise = try record.toModel()
            try templateExercise.insert(db)
        }

        for record in payload.bodyMetrics {
            let bodyMetric = try record.toModel()
            try bodyMetric.insert(db)
        }
    }

    private func applySettings(_ settings: SettingsSnapshot?) {
        guard let settings else { return }

        let trimmedFirstName = settings.firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = settings.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBodyWeight = settings.bodyWeight?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBodyHeight = settings.bodyHeight?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAge = settings.age?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRestDuration = settings.defaultRestDurationSec?.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(trimmedFirstName ?? "", forKey: SettingsSnapshot.Keys.firstName)
        defaults.set(trimmedLastName ?? "", forKey: SettingsSnapshot.Keys.lastName)
        defaults.set(trimmedBodyWeight ?? "", forKey: SettingsSnapshot.Keys.bodyWeight)
        defaults.set(trimmedBodyHeight ?? "", forKey: SettingsSnapshot.Keys.bodyHeight)
        defaults.set(trimmedAge ?? "", forKey: SettingsSnapshot.Keys.age)
        defaults.set(settings.gender ?? "prefer_not_to_say", forKey: SettingsSnapshot.Keys.gender)

        let sanitizedWeightUnit: String = {
            guard let raw = settings.weightUnit, SettingsViewModel.WeightUnit(rawValue: raw) != nil else {
                return SettingsViewModel.WeightUnit.kg.rawValue
            }
            return raw
        }()

        let sanitizedDistanceUnit: String = {
            guard let raw = settings.distanceUnit, SettingsViewModel.DistanceUnit(rawValue: raw) != nil else {
                return SettingsViewModel.DistanceUnit.km.rawValue
            }
            return raw
        }()

        defaults.set(sanitizedWeightUnit, forKey: SettingsSnapshot.Keys.weightUnit)
        defaults.set(sanitizedDistanceUnit, forKey: SettingsSnapshot.Keys.distanceUnit)
        defaults.set(trimmedRestDuration ?? "90", forKey: SettingsSnapshot.Keys.defaultRestDurationSec)

        defaults.set(settings.isHealthConnected ?? false, forKey: SettingsSnapshot.Keys.isHealthConnected)

        if let base64 = settings.profileImageBase64 {
            defaults.set(Data(base64Encoded: base64), forKey: SettingsSnapshot.Keys.profileImageData)
        } else {
            defaults.set(nil, forKey: SettingsSnapshot.Keys.profileImageData)
        }
    }

    private func stageRestoreSource(_ sourceURL: URL) throws -> URL {
        let stagingFolder = fileManager.temporaryDirectory.appendingPathComponent("MilestoneRestore", isDirectory: true)

        if !fileManager.fileExists(atPath: stagingFolder.path) {
            try fileManager.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        }

        let extensionValue = sourceURL.pathExtension.isEmpty ? "json" : sourceURL.pathExtension
        let destination = stagingFolder.appendingPathComponent(
            "restore-source-\(Self.timestampToken()).\(extensionValue)",
            isDirectory: false
        )

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            throw DataTransferError.unreadableFile(error.localizedDescription)
        }
    }

    private func writeFile(data: Data, filenamePrefix: String, pathExtension: String) throws -> URL {
        let filename = "\(filenamePrefix)-\(Self.timestampToken()).\(pathExtension)"
        do {
            let exportDirectory = try resolvePreferredExportDirectory()
            return try writeFile(data: data, filename: filename, to: exportDirectory)
        } catch DataTransferError.selectedExportFolderUnavailable,
                DataTransferError.failedToAccessSelectedExportFolder {
            clearExternalExportFolderSelection()
            let fallbackDirectory = ResolvedExportDirectory(
                url: try prepareFilesDirectory(),
                isExternal: false,
                displayName: "Milestone > Exports"
            )
            return try writeFile(data: data, filename: filename, to: fallbackDirectory)
        }
    }

    private func writeFile(
        data: Data,
        filename: String,
        to exportDirectory: ResolvedExportDirectory
    ) throws -> URL {
        let destination = exportDirectory.url.appendingPathComponent(filename, isDirectory: false)

        if exportDirectory.isExternal {
            let hasAccess = exportDirectory.url.startAccessingSecurityScopedResource()
            guard hasAccess else {
                throw DataTransferError.failedToAccessSelectedExportFolder
            }
            defer { exportDirectory.url.stopAccessingSecurityScopedResource() }
        }

        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func resolvePreferredExportDirectory() throws -> ResolvedExportDirectory {
        if let externalDirectory = try resolveExternalExportDirectory() {
            return externalDirectory
        }

        let fallbackURL = try prepareFilesDirectory()
        return ResolvedExportDirectory(
            url: fallbackURL,
            isExternal: false,
            displayName: "Milestone > Exports"
        )
    }

    private func resolveExternalExportDirectory() throws -> ResolvedExportDirectory? {
        guard let bookmarkData = defaults.data(forKey: Keys.externalExportFolderBookmark) else {
            return nil
        }

        var isStale = false
        let folderURL: URL

        do {
            folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            clearExternalExportFolderSelection()
            throw DataTransferError.selectedExportFolderUnavailable
        }

        if isStale {
            _ = try saveExternalExportFolderSelection(folderURL)
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory)
        guard exists, isDirectory.boolValue else {
            clearExternalExportFolderSelection()
            throw DataTransferError.selectedExportFolderUnavailable
        }

        return ResolvedExportDirectory(
            url: folderURL,
            isExternal: true,
            displayName: defaults.string(forKey: Keys.externalExportFolderName) ?? Self.displayName(for: folderURL)
        )
    }

    private static func timestampToken(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func displayName(for url: URL) -> String {
        let trimmed = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Selected Folder" : trimmed
    }

    private static func csvEscape(_ raw: String) -> String {
        let escaped = raw.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static var appVersionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        switch (shortVersion, build) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        default:
            return "unknown"
        }
    }

    private static func migratePayloadDistanceMetersToKilometers(_ payload: PayloadV1) -> PayloadV1 {
        PayloadV1(
            exercises: payload.exercises,
            sessions: payload.sessions,
            sessionExercises: payload.sessionExercises,
            sets: payload.sets.map { item in
                SetRecord(
                    id: item.id,
                    sessionExerciseID: item.sessionExerciseID,
                    setIndex: item.setIndex,
                    metricType: item.metricType,
                    reps: item.reps,
                    weightKg: item.weightKg,
                    distanceM: item.distanceM.map { $0 / 1000.0 },
                    durationSec: item.durationSec,
                    comment: item.comment,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            templates: payload.templates,
            templateExercises: payload.templateExercises.map { item in
                TemplateExerciseRecord(
                    id: item.id,
                    templateID: item.templateID,
                    exerciseID: item.exerciseID,
                    orderIndex: item.orderIndex,
                    targetSets: item.targetSets,
                    targetReps: item.targetReps,
                    targetWeightKg: item.targetWeightKg,
                    targetDistanceM: item.targetDistanceM.map { $0 / 1000.0 },
                    targetDurationSec: item.targetDurationSec,
                    notes: item.notes,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            bodyMetrics: payload.bodyMetrics,
            settings: payload.settings
        )
    }
}

struct AutomaticBackupService {
    private let defaults: UserDefaults
    private let dataTransferService: DataTransferService

    private enum Keys {
        static let enabled = "autoBackup.enabled"
        static let lastSuccessfulDay = "autoBackup.lastSuccessfulDay"
        static let lastSuccessfulDate = "autoBackup.lastSuccessfulDate"
    }

    init(
        defaults: UserDefaults = .standard,
        dataTransferService: DataTransferService = DataTransferService()
    ) {
        self.defaults = defaults
        self.dataTransferService = dataTransferService
    }

    var isEnabled: Bool {
        defaults.bool(forKey: Keys.enabled)
    }

    func setEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Keys.enabled)
    }

    func performBackupIfNeeded(dbQueue: DatabaseQueue, now: Date = Date()) throws -> DataTransferExportResult? {
        guard isEnabled else { return nil }

        let dayToken = Self.dayToken(for: now)
        guard defaults.string(forKey: Keys.lastSuccessfulDay) != dayToken else {
            return nil
        }

        let result = try dataTransferService.backup(dbQueue: dbQueue)
        defaults.set(dayToken, forKey: Keys.lastSuccessfulDay)
        defaults.set(now, forKey: Keys.lastSuccessfulDate)
        return result
    }

    func lastSuccessfulBackupSummary() -> String {
        guard let date = defaults.object(forKey: Keys.lastSuccessfulDate) as? Date else {
            return "No automatic backup has run yet."
        }

        let formatted = DateFormatter.localizedString(
            from: date,
            dateStyle: .medium,
            timeStyle: .short
        )
        return "Last automatic backup: \(formatted)"
    }

    private static func dayToken(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct PayloadEnvelopeV1: Codable {
    enum Kind: String, Codable {
        case backup
        case jsonExport = "json_export"
    }

    let kind: Kind
    let payloadVersion: Int
    let generatedAt: String
    let appVersion: String
    let payload: PayloadV1
}

private struct LegacyPayloadV0: Codable {
    let exercises: [ExerciseRecord]
    let sessions: [SessionRecord]
    let sessionExercises: [SessionExerciseRecord]
    let sets: [SetRecord]
    let templates: [TemplateRecord]
    let templateExercises: [TemplateExerciseRecord]
    let bodyMetrics: [BodyMetricRecord]
    let settings: SettingsSnapshot?

    enum CodingKeys: String, CodingKey {
        case exercises
        case sessions
        case sessionExercises = "session_exercises"
        case sets
        case templates
        case templateExercises = "template_exercises"
        case bodyMetrics = "body_metrics"
        case settings
    }

    func migratedToV1() -> PayloadV1 {
        PayloadV1(
            exercises: exercises,
            sessions: sessions,
            sessionExercises: sessionExercises,
            sets: sets,
            templates: templates,
            templateExercises: templateExercises,
            bodyMetrics: bodyMetrics,
            settings: settings
        )
    }
}

private struct PayloadV1: Codable {
    let exercises: [ExerciseRecord]
    let sessions: [SessionRecord]
    let sessionExercises: [SessionExerciseRecord]
    let sets: [SetRecord]
    let templates: [TemplateRecord]
    let templateExercises: [TemplateExerciseRecord]
    let bodyMetrics: [BodyMetricRecord]
    let settings: SettingsSnapshot?

    enum CodingKeys: String, CodingKey {
        case exercises
        case sessions
        case sessionExercises = "session_exercises"
        case sets
        case templates
        case templateExercises = "template_exercises"
        case bodyMetrics = "body_metrics"
        case settings
    }
}

private struct ExerciseRecord: Codable {
    let id: String
    let name: String
    let mediaURI: String?
    let type: String
    let category: String?
    let source: String
    let description: String?
    let targetArea: String?
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case mediaURI = "media_uri"
        case type
        case category = "exercise_category"
        case source = "exercise_source"
        case description
        case targetArea = "target_area"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(model: Exercise) {
        id = model.id
        name = model.name
        mediaURI = model.mediaURI
        type = model.type.rawValue
        category = model.category?.rawValue
        source = model.source.rawValue
        description = model.description
        targetArea = model.targetArea
        isArchived = model.isArchived
        createdAt = DateISO8601.string(from: model.createdAt)
        updatedAt = DateISO8601.string(from: model.updatedAt)
    }

    func toModel() throws -> Exercise {
        guard let parsedType = ExerciseType(rawValue: type) else {
            throw DataTransferError.invalidBackupPayload("Invalid exercise type: \(type)")
        }

        let parsedCategory: ExerciseCategory?
        if let category {
            guard let parsed = ExerciseCategory(rawValue: category) else {
                throw DataTransferError.invalidBackupPayload("Invalid exercise category: \(category)")
            }
            parsedCategory = parsed
        } else {
            parsedCategory = nil
        }

        guard let parsedSource = ExerciseSource(rawValue: source) else {
            throw DataTransferError.invalidBackupPayload("Invalid exercise source: \(source)")
        }

        return Exercise(
            id: id,
            name: name,
            mediaURI: mediaURI,
            type: parsedType,
            category: parsedCategory,
            source: parsedSource,
            description: description,
            targetArea: targetArea,
            isArchived: isArchived,
            createdAt: try DateISO8601.date(from: createdAt),
            updatedAt: try DateISO8601.date(from: updatedAt)
        )
    }
}

private struct SessionRecord: Codable {
    let id: String
    let name: String?
    let startDateTime: String
    let endDateTime: String?
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startDateTime = "start_datetime"
        case endDateTime = "end_datetime"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(model: Session) {
        id = model.id
        name = model.name
        startDateTime = DateISO8601.string(from: model.startDateTime)
        endDateTime = model.endDateTime.map(DateISO8601.string(from:))
        notes = model.notes
        createdAt = DateISO8601.string(from: model.createdAt)
        updatedAt = DateISO8601.string(from: model.updatedAt)
    }

    func toModel() throws -> Session {
        Session(
            id: id,
            name: name,
            startDateTime: try DateISO8601.date(from: startDateTime),
            endDateTime: try endDateTime.map(DateISO8601.date(from:)),
            notes: notes,
            createdAt: try DateISO8601.date(from: createdAt),
            updatedAt: try DateISO8601.date(from: updatedAt)
        )
    }
}

private struct SessionExerciseRecord: Codable {
    let id: String
    let sessionID: String
    let exerciseID: String
    let orderIndex: Int
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case exerciseID = "exercise_id"
        case orderIndex = "order_index"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(model: SessionExercise) {
        id = model.id
        sessionID = model.sessionID
        exerciseID = model.exerciseID
        orderIndex = model.orderIndex
        notes = model.notes
        createdAt = DateISO8601.string(from: model.createdAt)
        updatedAt = DateISO8601.string(from: model.updatedAt)
    }

    func toModel() throws -> SessionExercise {
        SessionExercise(
            id: id,
            sessionID: sessionID,
            exerciseID: exerciseID,
            orderIndex: orderIndex,
            notes: notes,
            createdAt: try DateISO8601.date(from: createdAt),
            updatedAt: try DateISO8601.date(from: updatedAt)
        )
    }
}

private struct SetRecord: Codable {
    let id: String
    let sessionExerciseID: String
    let setIndex: Int
    let metricType: String
    let reps: Int?
    let weightKg: Double?
    let distanceM: Double?
    let durationSec: Int?
    let comment: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case sessionExerciseID = "session_exercise_id"
        case setIndex = "set_index"
        case metricType = "metric_type"
        case reps
        case weightKg = "weight_kg"
        case distanceM = "distance_m"
        case durationSec = "duration_sec"
        case comment
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        sessionExerciseID: String,
        setIndex: Int,
        metricType: String,
        reps: Int?,
        weightKg: Double?,
        distanceM: Double?,
        durationSec: Int?,
        comment: String?,
        createdAt: String,
        updatedAt: String
    ) {
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
    }

    init(model: WorkoutSet) {
        id = model.id
        sessionExerciseID = model.sessionExerciseID
        setIndex = model.setIndex
        metricType = model.metricType.rawValue
        reps = model.reps
        weightKg = model.weightKg
        distanceM = model.distanceM
        durationSec = model.durationSec
        comment = model.comment
        createdAt = DateISO8601.string(from: model.createdAt)
        updatedAt = DateISO8601.string(from: model.updatedAt)
    }

    func toModel() throws -> WorkoutSet {
        guard let parsedMetricType = MetricType(rawValue: metricType) else {
            throw DataTransferError.invalidBackupPayload("Invalid metric type: \(metricType)")
        }

        return try WorkoutSet(
            id: id,
            sessionExerciseID: sessionExerciseID,
            setIndex: setIndex,
            metricType: parsedMetricType,
            reps: reps,
            weightKg: weightKg,
            distanceM: distanceM,
            durationSec: durationSec,
            comment: comment,
            createdAt: try DateISO8601.date(from: createdAt),
            updatedAt: try DateISO8601.date(from: updatedAt)
        )
    }
}

private struct TemplateRecord: Codable {
    let id: String
    let name: String
    let description: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(model: Template) {
        id = model.id
        name = model.name
        description = model.description
        createdAt = DateISO8601.string(from: model.createdAt)
        updatedAt = DateISO8601.string(from: model.updatedAt)
    }

    func toModel() throws -> Template {
        Template(
            id: id,
            name: name,
            description: description,
            createdAt: try DateISO8601.date(from: createdAt),
            updatedAt: try DateISO8601.date(from: updatedAt)
        )
    }
}

private struct TemplateExerciseRecord: Codable {
    let id: String
    let templateID: String
    let exerciseID: String
    let orderIndex: Int
    let targetSets: Int?
    let targetReps: Int?
    let targetWeightKg: Double?
    let targetDistanceM: Double?
    let targetDurationSec: Int?
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case templateID = "template_id"
        case exerciseID = "exercise_id"
        case orderIndex = "order_index"
        case targetSets = "target_sets"
        case targetReps = "target_reps"
        case targetWeightKg = "target_weight_kg"
        case targetDistanceM = "target_distance_m"
        case targetDurationSec = "target_duration_sec"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        templateID: String,
        exerciseID: String,
        orderIndex: Int,
        targetSets: Int?,
        targetReps: Int?,
        targetWeightKg: Double?,
        targetDistanceM: Double?,
        targetDurationSec: Int?,
        notes: String?,
        createdAt: String,
        updatedAt: String
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

    init(model: TemplateExercise) {
        id = model.id
        templateID = model.templateID
        exerciseID = model.exerciseID
        orderIndex = model.orderIndex
        targetSets = model.targetSets
        targetReps = model.targetReps
        targetWeightKg = model.targetWeightKg
        targetDistanceM = model.targetDistanceM
        targetDurationSec = model.targetDurationSec
        notes = model.notes
        createdAt = DateISO8601.string(from: model.createdAt)
        updatedAt = DateISO8601.string(from: model.updatedAt)
    }

    func toModel() throws -> TemplateExercise {
        TemplateExercise(
            id: id,
            templateID: templateID,
            exerciseID: exerciseID,
            orderIndex: orderIndex,
            targetSets: targetSets,
            targetReps: targetReps,
            targetWeightKg: targetWeightKg,
            targetDistanceM: targetDistanceM,
            targetDurationSec: targetDurationSec,
            notes: notes,
            createdAt: try DateISO8601.date(from: createdAt),
            updatedAt: try DateISO8601.date(from: updatedAt)
        )
    }
}

private struct BodyMetricRecord: Codable {
    let id: String
    let dateTime: String
    let bodyweightKg: Double?
    let bodyfatPct: Double?
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case dateTime = "datetime"
        case bodyweightKg = "bodyweight_kg"
        case bodyfatPct = "bodyfat_pct"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(model: BodyMetric) {
        id = model.id
        dateTime = DateISO8601.string(from: model.dateTime)
        bodyweightKg = model.bodyweightKg
        bodyfatPct = model.bodyfatPct
        notes = model.notes
        createdAt = DateISO8601.string(from: model.createdAt)
        updatedAt = DateISO8601.string(from: model.updatedAt)
    }

    func toModel() throws -> BodyMetric {
        BodyMetric(
            id: id,
            dateTime: try DateISO8601.date(from: dateTime),
            bodyweightKg: bodyweightKg,
            bodyfatPct: bodyfatPct,
            notes: notes,
            createdAt: try DateISO8601.date(from: createdAt),
            updatedAt: try DateISO8601.date(from: updatedAt)
        )
    }
}

private struct SettingsSnapshot: Codable {
    let firstName: String?
    let lastName: String?
    let bodyWeight: String?
    let bodyHeight: String?
    let age: String?
    let gender: String?
    let weightUnit: String?
    let distanceUnit: String?
    let defaultRestDurationSec: String?
    let isHealthConnected: Bool?
    let profileImageBase64: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case bodyWeight = "body_weight"
        case bodyHeight = "body_height"
        case age
        case gender
        case weightUnit = "weight_unit"
        case distanceUnit = "distance_unit"
        case defaultRestDurationSec = "default_rest_duration_sec"
        case isHealthConnected = "is_health_connected"
        case profileImageBase64 = "profile_image_base64"
    }

    init(defaults: UserDefaults) {
        firstName = defaults.string(forKey: Keys.firstName)
        lastName = defaults.string(forKey: Keys.lastName)
        bodyWeight = defaults.string(forKey: Keys.bodyWeight)
        bodyHeight = defaults.string(forKey: Keys.bodyHeight)
        age = defaults.string(forKey: Keys.age)
        gender = defaults.string(forKey: Keys.gender)
        weightUnit = defaults.string(forKey: Keys.weightUnit)
        distanceUnit = defaults.string(forKey: Keys.distanceUnit)
        defaultRestDurationSec = defaults.string(forKey: Keys.defaultRestDurationSec)
        isHealthConnected = defaults.object(forKey: Keys.isHealthConnected) as? Bool
        profileImageBase64 = defaults.data(forKey: Keys.profileImageData)?.base64EncodedString()
    }

    enum Keys {
        static let firstName = "settings.firstName"
        static let lastName = "settings.lastName"
        static let bodyWeight = "settings.bodyWeight"
        static let bodyHeight = "settings.bodyHeight"
        static let age = "settings.age"
        static let gender = "settings.gender"
        static let weightUnit = "settings.weightUnit"
        static let distanceUnit = "settings.distanceUnit"
        static let defaultRestDurationSec = "settings.defaultRestDurationSec"
        static let isHealthConnected = "settings.isHealthConnected"
        static let profileImageData = "settings.profileImageData"
    }
}
