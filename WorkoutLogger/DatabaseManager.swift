import Foundation
import GRDB

enum DatabaseError: Error {
    case applicationSupportUnavailable
}

final class DatabaseManager {
    static let shared = try! DatabaseManager()

    let dbQueue: DatabaseQueue

    init(fileManager: FileManager = .default) throws {
        let databaseURL = try Self.makeDatabaseURL(fileManager: fileManager)

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
        try Migrations.makeMigrator().migrate(dbQueue)
    }

    @discardableResult
    func writeInTransaction<T>(_ updates: (Database) throws -> T) throws -> T {
        try dbQueue.write { db in
            var result: T?
            try db.inTransaction {
                result = try updates(db)
                return .commit
            }
            return result!
        }
    }

    static func currentTimestampISO8601(date: Date = Date()) -> String {
        ISO8601DateFormatter.fractionalSeconds.string(from: date)
    }

    private static func makeDatabaseURL(fileManager: FileManager) throws -> URL {
        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw DatabaseError.applicationSupportUnavailable
        }

        let directory = applicationSupport
            .appendingPathComponent("Milestone", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent("milestone.sqlite", isDirectory: false)
    }
}

private extension ISO8601DateFormatter {
    static let fractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
