import SwiftUI
import Foundation
import GRDB
import PhotosUI
import UIKit
import UniformTypeIdentifiers

enum AppUnitPreferences {
    static let weightUnitKey = "settings.weightUnit"
    static let distanceUnitKey = "settings.distanceUnit"

    static func weightUnit(defaults: UserDefaults = .standard) -> SettingsViewModel.WeightUnit {
        guard
            let raw = defaults.string(forKey: weightUnitKey),
            let parsed = SettingsViewModel.WeightUnit(rawValue: raw)
        else {
            return .kg
        }
        return parsed
    }

    static func distanceUnit(defaults: UserDefaults = .standard) -> SettingsViewModel.DistanceUnit {
        guard
            let raw = defaults.string(forKey: distanceUnitKey),
            let parsed = SettingsViewModel.DistanceUnit(rawValue: raw)
        else {
            return .km
        }
        return parsed
    }
}

enum AppAppearancePreferences {
    static let followsSystemKey = "settings.appearance.followsSystem"
    static let darkModeEnabledKey = "settings.appearance.darkModeEnabled"
}

enum UnitConverter {
    private static let kilogramsPerPound = 0.453_592_37
    private static let kilometersPerMile = 1.609_344

    static func weightToDisplay(_ kilograms: Double, unit: SettingsViewModel.WeightUnit) -> Double {
        switch unit {
        case .kg:
            return kilograms
        case .lb:
            return kilograms / kilogramsPerPound
        }
    }

    static func weightToKilograms(_ value: Double, unit: SettingsViewModel.WeightUnit) -> Double {
        switch unit {
        case .kg:
            return value
        case .lb:
            return value * kilogramsPerPound
        }
    }

    static func distanceToDisplay(_ kilometers: Double, unit: SettingsViewModel.DistanceUnit) -> Double {
        switch unit {
        case .km:
            return kilometers
        case .miles:
            return kilometers / kilometersPerMile
        }
    }

    static func distanceToKilometers(_ value: Double, unit: SettingsViewModel.DistanceUnit) -> Double {
        switch unit {
        case .km:
            return value
        case .miles:
            return value * kilometersPerMile
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var activePreferencesDropdownID: String?
    @State private var showingStatusDialog = false

    var body: some View {
        NavigationStack {
            UIAssetInlineDropdownHost {
                ZStack {
                    settingsScrollView
                    settingsStatusDialog
                }
            }
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .dismissKeyboardOnBackgroundTap()
            .onChange(of: viewModel.weightUnit) { _, _ in viewModel.save() }
            .onChange(of: viewModel.distanceUnit) { _, _ in viewModel.save() }
            .onChange(of: viewModel.followsSystemAppearance) { _, _ in viewModel.save() }
            .onChange(of: viewModel.isDarkModeEnabled) { _, _ in viewModel.save() }
            .onChange(of: viewModel.isHealthConnected) { _, _ in viewModel.save() }
            .onChange(of: viewModel.statusMessage != nil || viewModel.errorMessage != nil) { _, isPresented in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingStatusDialog = isPresented
                }
            }
        }
    }

    private var settingsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .uiAssetText(.h2)
                    .foregroundStyle(UIAssetColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                profileCard
                preferencesCard
                healthCard
                designSystemCard
                dataHandlingCard
                aboutCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var settingsStatusDialog: some View {
        if showingStatusDialog {
            Rectangle()
                .fill(Color.black.opacity(0.24))
                .ignoresSafeArea()
                .onTapGesture {
                    dismissStatusDialog()
                }

            UIAssetAlertDialog(
                title: "Settings",
                message: viewModel.errorMessage ?? viewModel.statusMessage ?? "",
                cancelTitle: "OK",
                destructiveTitle: "Close"
            ) {
                dismissStatusDialog()
            } onDestructive: {
                dismissStatusDialog()
            }
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Profile")
                .uiAssetText(.subtitle)
                .foregroundStyle(UIAssetColors.textSecondary)

            HStack(spacing: 12) {
                profileImageView
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.fullNameDisplay)
                        .uiAssetText(.h3)
                        .foregroundStyle(UIAssetColors.textPrimary)

                    Text(viewModel.genderAgeDisplay)
                        .uiAssetText(.footnote)
                        .foregroundStyle(UIAssetColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            NavigationLink {
                UserProfileView(viewModel: viewModel)
            } label: {
                UIAssetSettingsRow(symbol: "person.crop.circle", title: "Modify Details", showsDivider: false) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UIAssetColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .uiAssetCardSurface(fill: UIAssetColors.primary)
    }

    private var healthCard: some View {
        UIAssetSettingsCategoryCard(category: "Health and Fitness Data", bottomPadding: 8) {
            UIAssetSettingsRow(symbol: "heart.text.square", title: "Connect HealthKit", showsDivider: false) {
                UIAssetSettingsInlineToggle(isOn: $viewModel.isHealthConnected)
            }
        }
    }

    private var designSystemCard: some View {
        UIAssetSettingsCategoryCard(category: "Design System", bottomPadding: 8) {
            NavigationLink {
                UIAssetsCatalogView()
            } label: {
                UIAssetSettingsRow(symbol: "paintpalette", title: "UI Assets", showsDivider: false) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UIAssetColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var dataHandlingCard: some View {
        UIAssetSettingsCategoryCard(category: "Data Handling", bottomPadding: 8) {
            NavigationLink {
                DataHandlingView(viewModel: viewModel)
            } label: {
                UIAssetSettingsRow(symbol: "externaldrive", title: "Data", showsDivider: false) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UIAssetColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIAssetColors.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(UIAssetColors.accentSecondary)
                    )

                Text("About this app")
                    .uiAssetText(.h3)
                    .foregroundStyle(UIAssetColors.textPrimary)
            }

            Text("Milestone | v1.0\n\nDesigned for the love of training by Hardik Patil.\nBuilt local-first so your progress stays yours.\nSimple, friendly workout tracking for everyday consistency.")
                .uiAssetText(.subtitle)
                .foregroundStyle(UIAssetColors.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .uiAssetCardSurface(fill: UIAssetColors.primary)
    }

    @ViewBuilder
    private var profileImageView: some View {
        if let image = viewModel.profileUIImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(UIAssetColors.border, lineWidth: 0)
                )
        } else {
            Circle()
                .fill(UIAssetColors.accentSecondary)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(UIAssetColors.accent)
                )
                .overlay(
                    Circle()
                        .stroke(UIAssetColors.border, lineWidth: 0)
                )
        }
    }

    private var preferencesCard: some View {
        UIAssetSettingsCategoryCard(category: "Preferences", bottomPadding: 8) {
            UIAssetSettingsRow(symbol: "scalemass", title: "Weight Unit", showsDivider: true) {
                UIAssetSettingsInlineDropdown(
                    options: SettingsViewModel.WeightUnit.allCases.map(\.displayName),
                    selected: weightUnitDisplaySelection,
                    id: "settings.preferences.weightUnit",
                    activeDropdownID: $activePreferencesDropdownID,
                    panelWidth: 168
                )
            }

            UIAssetSettingsRow(symbol: "ruler", title: "Distance Unit", showsDivider: true) {
                UIAssetSettingsInlineDropdown(
                    options: SettingsViewModel.DistanceUnit.allCases.map(\.displayName),
                    selected: distanceUnitDisplaySelection,
                    id: "settings.preferences.distanceUnit",
                    activeDropdownID: $activePreferencesDropdownID,
                    panelWidth: 168
                )
            }

            UIAssetSettingsRow(symbol: "moon.fill", title: "Dark Mode", showsDivider: true) {
                UIAssetSettingsInlineToggle(isOn: darkModeSelection)
                    .disabled(viewModel.followsSystemAppearance)
                    .opacity(viewModel.followsSystemAppearance ? 0.45 : 1)
            }

            UIAssetSettingsRow(symbol: "iphone", title: "Use System Appearance", showsDivider: false) {
                UIAssetSettingsInlineToggle(isOn: $viewModel.followsSystemAppearance)
            }
        }
    }

    private var weightUnitDisplaySelection: Binding<String> {
        Binding {
            viewModel.weightUnit.displayName
        } set: { selected in
            if let value = SettingsViewModel.WeightUnit.allCases.first(where: { $0.displayName == selected }) {
                viewModel.weightUnit = value
            }
        }
    }

    private var distanceUnitDisplaySelection: Binding<String> {
        Binding {
            viewModel.distanceUnit.displayName
        } set: { selected in
            if let value = SettingsViewModel.DistanceUnit.allCases.first(where: { $0.displayName == selected }) {
                viewModel.distanceUnit = value
            }
        }
    }

    private func dismissStatusDialog() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingStatusDialog = false
            viewModel.statusMessage = nil
            viewModel.errorMessage = nil
        }
    }

    private var darkModeSelection: Binding<Bool> {
        Binding {
            viewModel.isDarkModeEnabled
        } set: { isOn in
            viewModel.isDarkModeEnabled = isOn
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(
            AppContainer(databaseManager: try! DatabaseManager())
        )
}

@MainActor
final class SettingsViewModel: ObservableObject {
    enum Gender: String, CaseIterable, Identifiable {
        case male
        case female
        case nonBinary = "non_binary"
        case preferNotToSay = "prefer_not_to_say"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            case .nonBinary: return "Non-binary"
            case .preferNotToSay: return "Prefer not to say"
            }
        }
    }

    enum WeightUnit: String, CaseIterable, Identifiable {
        case kg
        case lb

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .kg: return "Kilogram"
            case .lb: return "Pounds"
            }
        }
    }

    enum DistanceUnit: String, CaseIterable, Identifiable {
        case km
        case miles

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .km: return "Kilometer"
            case .miles: return "Mile"
            }
        }
    }

    @Published var firstName: String
    @Published var lastName: String
    @Published var bodyWeight: String
    @Published var bodyHeight: String
    @Published var age: String
    @Published var gender: Gender

    @Published var weightUnit: WeightUnit
    @Published var distanceUnit: DistanceUnit
    @Published var defaultRestDurationSec: String
    @Published var followsSystemAppearance: Bool
    @Published var isDarkModeEnabled: Bool

    @Published var isHealthConnected: Bool
    @Published var isAutomaticBackupEnabled: Bool
    @Published var profileImageData: Data?
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let dataTransferService: DataTransferService
    private let automaticBackupService: AutomaticBackupService

    init(
        defaults: UserDefaults = .standard,
        dataTransferService: DataTransferService = DataTransferService(),
        automaticBackupService: AutomaticBackupService = AutomaticBackupService()
    ) {
        self.defaults = defaults
        self.dataTransferService = dataTransferService
        self.automaticBackupService = automaticBackupService

        firstName = defaults.string(forKey: Keys.firstName) ?? ""
        lastName = defaults.string(forKey: Keys.lastName) ?? ""
        bodyWeight = defaults.string(forKey: Keys.bodyWeight) ?? ""
        bodyHeight = defaults.string(forKey: Keys.bodyHeight) ?? ""
        age = defaults.string(forKey: Keys.age) ?? ""

        if let raw = defaults.string(forKey: Keys.gender), let parsed = Gender(rawValue: raw) {
            gender = parsed
        } else {
            gender = .preferNotToSay
        }

        if let raw = defaults.string(forKey: Keys.weightUnit), let parsed = WeightUnit(rawValue: raw) {
            weightUnit = parsed
        } else {
            weightUnit = .kg
        }

        if let raw = defaults.string(forKey: Keys.distanceUnit), let parsed = DistanceUnit(rawValue: raw) {
            distanceUnit = parsed
        } else {
            distanceUnit = .km
        }

        defaultRestDurationSec = defaults.string(forKey: Keys.defaultRestDurationSec) ?? "90"
        followsSystemAppearance = defaults.bool(forKey: Keys.followsSystemAppearance)
        isDarkModeEnabled = defaults.bool(forKey: Keys.isDarkModeEnabled)
        isHealthConnected = defaults.bool(forKey: Keys.isHealthConnected)
        isAutomaticBackupEnabled = automaticBackupService.isEnabled
        profileImageData = defaults.data(forKey: Keys.profileImageData)
    }

    func save() {
        defaults.set(firstName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.firstName)
        defaults.set(lastName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.lastName)
        defaults.set(bodyWeight.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.bodyWeight)
        defaults.set(bodyHeight.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.bodyHeight)
        defaults.set(age.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.age)
        defaults.set(gender.rawValue, forKey: Keys.gender)

        defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit)
        defaults.set(distanceUnit.rawValue, forKey: Keys.distanceUnit)
        defaults.set(defaultRestDurationSec.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.defaultRestDurationSec)
        defaults.set(followsSystemAppearance, forKey: Keys.followsSystemAppearance)
        defaults.set(isDarkModeEnabled, forKey: Keys.isDarkModeEnabled)

        defaults.set(isHealthConnected, forKey: Keys.isHealthConnected)
        automaticBackupService.setEnabled(isAutomaticBackupEnabled)
        defaults.set(profileImageData, forKey: Keys.profileImageData)
    }

    func saveUserDetails(
        firstName: String,
        lastName: String,
        bodyWeight: String,
        bodyHeight: String,
        age: String,
        gender: Gender,
        profileImageData: Data?
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.bodyWeight = bodyWeight
        self.bodyHeight = bodyHeight
        self.age = age
        self.gender = gender
        self.profileImageData = profileImageData
        save()
    }

    var fullNameDisplay: String {
        let fullName = "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? "Your Name" : fullName
    }

    var lastNameDisplay: String {
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        return last.isEmpty ? "Last name" : last
    }

    var ageDisplay: String {
        let value = age.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return "Age not set"
        }
        return "Age \(value)"
    }

    var genderAgeDisplay: String {
        let ageValue = age.trimmingCharacters(in: .whitespacesAndNewlines)
        let agePart = ageValue.isEmpty ? "Age not set" : ageValue
        return "\(gender.displayName), \(agePart)"
    }

    var profileUIImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }

    func toggleHealthConnection() {
        isHealthConnected.toggle()
        save()
    }

    func exportCSV(dbQueue: DatabaseQueue) -> DataTransferExportResult? {
        performTransfer(successTitle: "CSV export") {
            try dataTransferService.exportCSV(dbQueue: dbQueue)
        }
    }

    func exportJSON(dbQueue: DatabaseQueue) -> DataTransferExportResult? {
        performTransfer(successTitle: "JSON export") {
            try dataTransferService.exportJSON(dbQueue: dbQueue)
        }
    }

    func backup(dbQueue: DatabaseQueue) -> DataTransferExportResult? {
        performTransfer(successTitle: "Backup") {
            try dataTransferService.backup(dbQueue: dbQueue)
        }
    }

    var exportDestinationDetail: String {
        dataTransferService.exportDestinationInfo().detail
    }

    var exportDestinationDisplayName: String {
        dataTransferService.exportDestinationInfo().displayName
    }

    var hasExternalExportFolderSelection: Bool {
        dataTransferService.hasExternalExportFolderSelection()
    }

    var exportDestinationSurvivalMessage: String {
        if hasExternalExportFolderSelection {
            return "NOTE: Exports in the selected folder survive app deletion."
        }
        return "NOTE: App-local exports are deleted when the app is removed."
    }

    var automaticBackupSummary: String {
        automaticBackupService.lastSuccessfulBackupSummary()
    }

    var automaticBackupDestinationSummary: String {
        "Automatic backups use \(exportDestinationDetail)."
    }

    var automaticBackupScheduleSummary: String {
        "Runs once per day when the app becomes active."
    }

    func saveExternalExportFolderSelection(_ folderURL: URL) {
        do {
            let destination = try dataTransferService.saveExternalExportFolderSelection(folderURL)
            statusMessage = "Export folder set to \(destination.displayName). New exports will be saved there automatically."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func clearExternalExportFolderSelection() {
        dataTransferService.clearExternalExportFolderSelection()
        statusMessage = "External export folder cleared. Exports will be saved to Files > On My iPhone > Milestone > Exports."
        errorMessage = nil
    }

    func restore(from fileURL: URL, dbQueue: DatabaseQueue) -> DataTransferRestoreResult? {
        do {
            let result = try dataTransferService.restore(from: fileURL, dbQueue: dbQueue)
            statusMessage = result.summary
            errorMessage = nil
            return result
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            return nil
        }
    }

    func resetData(dbQueue: DatabaseQueue) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM sets")
                try db.execute(sql: "DELETE FROM session_exercises")
                try db.execute(sql: "DELETE FROM sessions")
                try db.execute(sql: "DELETE FROM template_exercises")
                try db.execute(sql: "DELETE FROM templates")
                try db.execute(sql: "DELETE FROM exercises")
                try db.execute(sql: "DELETE FROM body_metrics")
            }
            statusMessage = "All workout data has been reset."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performTransfer(
        successTitle: String,
        _ action: () throws -> DataTransferExportResult
    ) -> DataTransferExportResult? {
        do {
            let result = try action()
            let destination = dataTransferService.exportDestinationInfo()
            statusMessage = "\(successTitle) saved as \(result.fileURL.lastPathComponent) in \(destination.detail)."
            errorMessage = nil
            return result
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            return nil
        }
    }

    private enum Keys {
        static let firstName = "settings.firstName"
        static let lastName = "settings.lastName"
        static let bodyWeight = "settings.bodyWeight"
        static let bodyHeight = "settings.bodyHeight"
        static let age = "settings.age"
        static let gender = "settings.gender"

        static let weightUnit = "settings.weightUnit"
        static let distanceUnit = "settings.distanceUnit"
        static let defaultRestDurationSec = "settings.defaultRestDurationSec"
        static let followsSystemAppearance = AppAppearancePreferences.followsSystemKey
        static let isDarkModeEnabled = AppAppearancePreferences.darkModeEnabledKey

        static let isHealthConnected = "settings.isHealthConnected"
        static let profileImageData = "settings.profileImageData"
    }
}

private struct SettingsScreenHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    let trailing: Trailing

    init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing()
    }

    init(title: String, onBack: @escaping () -> Void) where Trailing == EmptyView {
        self.init(title: title, onBack: onBack) {
            EmptyView()
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(UIAssetFloatingActionButtonStyle())

            Text(title)
                .uiAssetText(.h2)
                .foregroundStyle(UIAssetColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.bottom, 4)
    }
}

struct DataHandlingView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingResetConfirmation = false
    @State private var isRestoreImporterPresented = false
    @State private var showingTransferStatusDialog = false
    @State private var isExportFolderPickerPresented = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsScreenHeader(title: "Data Handling", onBack: { dismiss() })

                        Text("Current destination:\n\(viewModel.exportDestinationDetail)")
                            .uiAssetText(.subtitle)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        Text(viewModel.exportDestinationSurvivalMessage)
                            .uiAssetText(.subtitle)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        UIAssetSettingsCategoryCard(category: "Automatic Backup", bottomPadding: 8) {
                            VStack(alignment: .leading, spacing: 12) {
                                UIAssetSettingsRow(
                                    symbol: "clock.arrow.circlepath",
                                    title: "Daily Auto Backup",
                                    showsDivider: false
                                ) {
                                    UIAssetSettingsInlineToggle(isOn: $viewModel.isAutomaticBackupEnabled)
                                }

                                Text(viewModel.automaticBackupScheduleSummary)
                                    .uiAssetText(.subtitle)
                                    .foregroundStyle(UIAssetColors.textSecondary)

                                Text(viewModel.automaticBackupDestinationSummary)
                                    .uiAssetText(.subtitle)
                                    .foregroundStyle(UIAssetColors.textSecondary)

                                Text(viewModel.automaticBackupSummary)
                                    .uiAssetText(.subtitle)
                                    .foregroundStyle(UIAssetColors.textSecondary)
                            }
                        }

                        dataActionCard(
                            symbol: "folder.badge.plus",
                            title: "Choose Export Folder",
                            description: "Pick a Files folder once and future exports will be saved there automatically.",
                            action: {
                                isExportFolderPickerPresented = true
                            }
                        )

                        if viewModel.hasExternalExportFolderSelection {
                            dataActionCard(
                                symbol: "folder.badge.minus",
                                title: "Use App Folder Instead",
                                description: "Stop using the custom export folder and save back into the app's Files folder.",
                                action: {
                                    viewModel.clearExternalExportFolderSelection()
                                }
                            )
                        }

                        dataActionCard(
                            symbol: "tablecells",
                            title: "Export to CSV",
                            description: "Create a CSV file export of your logged workouts.",
                            action: {
                                _ = viewModel.exportCSV(dbQueue: container.dbQueue)
                            }
                        )

                        dataActionCard(
                            symbol: "curlybraces",
                            title: "Export to JSON",
                            description: "Create a JSON export for structured backup or migration.",
                            action: {
                                _ = viewModel.exportJSON(dbQueue: container.dbQueue)
                            }
                        )

                        dataActionCard(
                            symbol: "externaldrive.badge.icloud",
                            title: "Backup",
                            description: "Create a full local backup snapshot of app data.",
                            action: {
                                _ = viewModel.backup(dbQueue: container.dbQueue)
                            }
                        )

                        dataActionCard(
                            symbol: "arrow.triangle.2.circlepath",
                            title: "Restore",
                            description: "Restore app data from a previously created backup.",
                            action: {
                                isRestoreImporterPresented = true
                            }
                        )
                    }

                    UIAssetSettingsCategoryCard(category: "Danger Zone") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Permanently clear all local workout, exercise, and template data.")
                                .uiAssetText(.h3)
                                .foregroundStyle(UIAssetColors.textSecondary)

                            Button("Reset data") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingResetConfirmation = true
                                }
                            }
                            .buttonStyle(UIAssetButtonStyle(variant: .destructive))
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            if showingResetConfirmation {
                Rectangle()
                    .fill(Color.black.opacity(0.24))
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingResetConfirmation = false
                        }
                    }

                UIAssetAlertDialog(
                    title: "Reset data?",
                    message: "Are you sure you want to reset the data?",
                    cancelTitle: "Cancel",
                    destructiveTitle: "Reset"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingResetConfirmation = false
                    }
                } onDestructive: {
                    viewModel.resetData(dbQueue: container.dbQueue)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingResetConfirmation = false
                    }
                }
                .padding(.horizontal, 16)
                .transition(.scale.combined(with: .opacity))
            }

            if showingTransferStatusDialog {
                Rectangle()
                    .fill(Color.black.opacity(0.24))
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissTransferStatusDialog()
                    }

                UIAssetAlertDialog(
                    title: "Data Handling",
                    message: viewModel.errorMessage ?? viewModel.statusMessage ?? "",
                    cancelTitle: "OK",
                    destructiveTitle: "Close"
                ) {
                    dismissTransferStatusDialog()
                } onDestructive: {
                    dismissTransferStatusDialog()
                }
                .padding(.horizontal, 16)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .background(UIAssetColors.secondary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isExportFolderPickerPresented) {
            ExportFolderPicker { folderURL in
                isExportFolderPickerPresented = false
                viewModel.saveExternalExportFolderSelection(folderURL)
            } onCancel: {
                isExportFolderPickerPresented = false
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $isRestoreImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let first = urls.first else {
                    viewModel.errorMessage = "No file selected for restore."
                    return
                }
                let hasScopedAccess = first.startAccessingSecurityScopedResource()
                defer {
                    if hasScopedAccess {
                        first.stopAccessingSecurityScopedResource()
                    }
                }
                _ = viewModel.restore(from: first, dbQueue: container.dbQueue)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: viewModel.statusMessage != nil || viewModel.errorMessage != nil) { _, isPresented in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingTransferStatusDialog = isPresented
            }
        }
        .onChange(of: viewModel.isAutomaticBackupEnabled) { _, _ in
            viewModel.save()
        }
    }

    @ViewBuilder
    private func dataActionCard(
        symbol: String,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(UIAssetColors.accent)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(UIAssetColors.accentSecondary)
                        )

                    Text(title)
                        .uiAssetText(.paragraphSemibold)
                        .foregroundStyle(UIAssetColors.textPrimary)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UIAssetColors.textSecondary)
                }

                Text(description)
                    .uiAssetText(.subtitle)
                    .foregroundStyle(UIAssetColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .uiAssetCardSurface(fill: UIAssetColors.primary)
    }

    private func dismissTransferStatusDialog() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingTransferStatusDialog = false
            viewModel.statusMessage = nil
            viewModel.errorMessage = nil
        }
    }
}

private struct ExportFolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder],
            asCopy: false
        )
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }
    }
}

struct UserProfileView: View {
    private enum ProfileField: Hashable {
        case firstName
        case lastName
    }

    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String
    @State private var lastName: String
    @State private var bodyHeight: String
    @State private var bodyWeight: String
    @State private var age: String
    @State private var gender: SettingsViewModel.Gender
    @State private var profileImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var focusedProfileField: ProfileField?

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        _firstName = State(initialValue: viewModel.firstName)
        _lastName = State(initialValue: viewModel.lastName)
        _bodyHeight = State(initialValue: viewModel.bodyHeight)
        _bodyWeight = State(initialValue: viewModel.bodyWeight)
        _age = State(initialValue: viewModel.age)
        _gender = State(initialValue: viewModel.gender)
        _profileImageData = State(initialValue: viewModel.profileImageData)
    }

    var body: some View {
        UIAssetInlineDropdownHost {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                SettingsScreenHeader(title: "User Profile", onBack: { dismiss() }) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .buttonStyle(UIAssetTextActionButtonStyle())
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile Picture")
                        .uiAssetText(.subtitle)
                        .foregroundStyle(UIAssetColors.textSecondary)

                    VStack(spacing: 12) {
                        profileImagePreview
                            .frame(width: 96, height: 96)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text("Choose image")
                                .uiAssetText(.paragraph)
                                .foregroundStyle(UIAssetColors.accent)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                                        .fill(UIAssetColors.accentSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                                        .stroke(UIAssetColors.accent.opacity(0.25), lineWidth: 0)
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: 180)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
                .uiAssetCardSurface(fill: UIAssetColors.primary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Name")
                        .uiAssetText(.subtitle)
                        .foregroundStyle(UIAssetColors.textSecondary)

                    HStack(spacing: 10) {
                        profileNameInput(
                            placeholder: "First",
                            text: $firstName,
                            field: .firstName
                        )

                        profileNameInput(
                            placeholder: "Last",
                            text: $lastName,
                            field: .lastName
                        )
                    }
                }
                .padding(16)
                .uiAssetCardSurface(fill: UIAssetColors.primary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Body Metrics")
                        .uiAssetText(.subtitle)
                        .foregroundStyle(UIAssetColors.textSecondary)

                    UIAssetTextField(
                        title: "Weight (\(viewModel.weightUnit.displayName))",
                        placeholder: "Enter weight",
                        text: $bodyWeight,
                        keyboardType: .decimalPad
                    )

                    UIAssetTextField(
                        title: "Height (cm)",
                        placeholder: "Enter height",
                        text: $bodyHeight,
                        keyboardType: .numberPad
                    )

                    UIAssetTextField(
                        title: "Age",
                        placeholder: "Enter age",
                        text: $age,
                        keyboardType: .numberPad
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender")
                            .uiAssetText(.subtitle)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        UIAssetSettingsInlineDropdown(
                            options: genderOptions,
                            selected: genderSelection,
                            expansionDirection: .up,
                            panelAlignment: .leading,
                            panelWidth: 180
                        )
                    }
                }
                .padding(16)
                .uiAssetCardSurface(fill: UIAssetColors.primary)
                .zIndex(20)
            }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .background(UIAssetColors.secondary.ignoresSafeArea())
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    profileImageData = data
                }
            }
        }
        .dismissKeyboardOnBackgroundTap()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var profileImagePreview: some View {
        if let data = profileImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(UIAssetColors.border, lineWidth: 0)
                )
        } else {
            Circle()
                .fill(UIAssetColors.accentSecondary.opacity(0.6))
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(UIAssetColors.accent)
                )
                .overlay(
                    Circle()
                        .stroke(UIAssetColors.border, lineWidth: 0)
                )
        }
    }

    private func profileNameInput(
        placeholder: String,
        text: Binding<String>,
        field: ProfileField
    ) -> some View {
        TextField(placeholder, text: text)
            .font(UIAssetTextStyle.paragraph.font)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                    .fill(UIAssetColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                    .stroke(
                        focusedProfileField == field
                        ? UIAssetControlBorderColors.active
                        : UIAssetControlBorderColors.muted,
                        lineWidth: 1
                    )
            )
            .focused($focusedProfileField, equals: field)
            .animation(.easeInOut(duration: 0.18), value: focusedProfileField == field)
    }

    private var genderOptions: [String] {
        SettingsViewModel.Gender.allCases.map(\.displayName)
    }

    private var genderSelection: Binding<String> {
        Binding {
            gender.displayName
        } set: { selected in
            if let matched = SettingsViewModel.Gender.allCases.first(where: { $0.displayName == selected }) {
                gender = matched
            }
        }
    }

    private func saveAndDismiss() {
        viewModel.saveUserDetails(
            firstName: firstName,
            lastName: lastName,
            bodyWeight: bodyWeight,
            bodyHeight: bodyHeight,
            age: age,
            gender: gender,
            profileImageData: profileImageData
        )
        dismiss()
    }
}
