import SwiftUI
import Foundation
import GRDB
import CryptoKit
#if DEBUG
import Darwin
#endif

@main
struct MilestoneApp: App {
    @StateObject private var container: AppContainer

    init() {
        do {
            #if DEBUG
            let processInfo = ProcessInfo.processInfo
            let shouldRunSelfTests = processInfo.environment["MILESTONE_RUN_DATA_TRANSFER_SELF_TESTS"] == "1"
                || processInfo.arguments.contains("--run-data-transfer-self-tests")
            let shouldRunDeviceSmoke = processInfo.environment["MILESTONE_RUN_DATA_TRANSFER_DEVICE_SMOKE"] == "1"
                || processInfo.arguments.contains("--run-data-transfer-device-smoke")

            if shouldRunSelfTests {
                do {
                    try DataTransferServiceSelfTests.runAll()
                    print("MILESTONE_DATA_TRANSFER_SELF_TESTS: PASS")
                    exit(0)
                } catch {
                    print("MILESTONE_DATA_TRANSFER_SELF_TESTS: FAIL - \(error.localizedDescription)")
                    exit(1)
                }
            }

            if shouldRunDeviceSmoke {
                do {
                    let databaseManager = try DatabaseManager()
                    let service = DataTransferService()
                    let csv = try service.exportCSV(dbQueue: databaseManager.dbQueue)
                    let json = try service.exportJSON(dbQueue: databaseManager.dbQueue)
                    let backup = try service.backup(dbQueue: databaseManager.dbQueue)
                    let restore = try service.restore(from: backup.fileURL, dbQueue: databaseManager.dbQueue)
                    print("MILESTONE_DATA_TRANSFER_DEVICE_SMOKE: PASS")
                    print("CSV: \(csv.fileURL.path)")
                    print("JSON: \(json.fileURL.path)")
                    print("BACKUP: \(backup.fileURL.path)")
                    print("RESTORE: \(restore.summary)")
                    exit(0)
                } catch {
                    print("MILESTONE_DATA_TRANSFER_DEVICE_SMOKE: FAIL - \(error.localizedDescription)")
                    exit(1)
                }
            }
            #endif

            AppTypography.configure()
            let databaseManager = try DatabaseManager()
            let appContainer = AppContainer(databaseManager: databaseManager)
            try ExerciseSeedService(
                exerciseRepository: appContainer.exerciseRepository
            ).seedIfNeeded()
            _container = StateObject(wrappedValue: appContainer)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, .app(.body))
                .environmentObject(container)
                .preferredColorScheme(.light)
        }
    }
}

private struct ExerciseSeedService {
    private let exerciseRepository: ExerciseRepository
    private let defaults: UserDefaults
    private let seedFingerprintKey = "seed.exercises.fingerprint"

    init(exerciseRepository: ExerciseRepository, defaults: UserDefaults = .standard) {
        self.exerciseRepository = exerciseRepository
        self.defaults = defaults
    }

    func seedIfNeeded() throws {
        let seedData = try loadSeedData()
        let payloads = try loadSeedPayloads(from: seedData)
        try exerciseRepository.reconcileSeededExerciseSources(seedIDs: payloads.map(\.id))

        let fingerprint = Self.sha256Hex(seedData)
        let currentFingerprint = defaults.string(forKey: seedFingerprintKey)
        let hasAnyExercises = try exerciseRepository.hasAnyExercises()

        guard currentFingerprint != fingerprint || !hasAnyExercises else {
            return
        }

        _ = try exerciseRepository.upsertSeedExercises(payloads)
        defaults.set(fingerprint, forKey: seedFingerprintKey)
    }

    private func loadSeedPayloads(from data: Data) throws -> [SeedExercisePayload] {
        let decoder = JSONDecoder()
        return try decoder.decode([SeedExercisePayload].self, from: data)
    }

    private func loadSeedData() throws -> Data {
        if let bundleURL = Bundle.main.url(forResource: "SeedExercises", withExtension: "json") {
            return try Data(contentsOf: bundleURL)
        }

        #if DEBUG
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("SeedExercises.json")
        if FileManager.default.fileExists(atPath: sourcePath.path) {
            return try Data(contentsOf: sourcePath)
        }
        #endif

        guard let fallbackData = Self.fallbackSeedJSON.data(using: .utf8) else {
            throw RepositoryError.invalidSeedData
        }
        return fallbackData
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static let fallbackSeedJSON = """
    [
      {
        "id": "seed-push-up",
        "name": "Push-up",
        "type": "functional",
        "category": "push",
        "description": "Start in a plank position, lower chest, then press back up.",
        "target_area": "Chest",
        "media_uri": null
      },
      {
        "id": "seed-squat",
        "name": "Bodyweight Squat",
        "type": "functional",
        "category": "legs",
        "description": "Sit hips back and down, then stand back up.",
        "target_area": "Legs",
        "media_uri": null
      },
      {
        "id": "seed-row",
        "name": "Dumbbell Row",
        "type": "weight",
        "category": "pull",
        "description": "Pull dumbbell to hip while keeping torso stable.",
        "target_area": "Back",
        "media_uri": null
      }
    ]
    """
}
