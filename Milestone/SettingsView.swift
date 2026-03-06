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

    var body: some View {
        NavigationStack {
            UIAssetInlineDropdownHost {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    Text("Settings")
                        .uiAssetText(.h2)
                        .foregroundStyle(UIAssetColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Profile")
                            .uiAssetText(.caption)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        HStack(spacing: 12) {
                            profileImageView
                                .frame(width: 52, height: 52)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.fullNameDisplay)
                                    .uiAssetText(.h4)
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

                    preferencesCard

                    UIAssetSettingsCategoryCard(category: "Health and Fitness Data", bottomPadding: 8) {
                        UIAssetSettingsRow(symbol: "heart.text.square", title: "Connect HealthKit", showsDivider: false) {
                            UIAssetSettingsInlineToggle(isOn: $viewModel.isHealthConnected)
                        }
                    }

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
                                .uiAssetText(.h5)
                                .foregroundStyle(UIAssetColors.textPrimary)
                        }

                        Text("Milestone | v1.0\n\nDesigned for the love of training by Hardik Patil.\nBuilt local-first so your progress stays yours.\nSimple, friendly workout tracking for everyday consistency.")
                            .uiAssetText(.footnote)
                            .foregroundStyle(UIAssetColors.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .uiAssetCardSurface(fill: UIAssetColors.primary)
                }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .dismissKeyboardOnBackgroundTap()
            .onChange(of: viewModel.weightUnit) { _, _ in viewModel.save() }
            .onChange(of: viewModel.distanceUnit) { _, _ in viewModel.save() }
            .onChange(of: viewModel.isHealthConnected) { _, _ in viewModel.save() }
            .alert("Settings", isPresented: statusAlertPresented) {
                Button("OK") {
                    viewModel.statusMessage = nil
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? viewModel.statusMessage ?? "")
            }
        }
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
                        .stroke(UIAssetColors.border, lineWidth: 1)
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
                        .stroke(UIAssetColors.border, lineWidth: 1)
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

            UIAssetSettingsRow(symbol: "ruler", title: "Distance Unit", showsDivider: false) {
                UIAssetSettingsInlineDropdown(
                    options: SettingsViewModel.DistanceUnit.allCases.map(\.displayName),
                    selected: distanceUnitDisplaySelection,
                    id: "settings.preferences.distanceUnit",
                    activeDropdownID: $activePreferencesDropdownID,
                    panelWidth: 168
                )
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

    private var statusAlertPresented: Binding<Bool> {
        Binding {
            viewModel.statusMessage != nil || viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.statusMessage = nil
                viewModel.errorMessage = nil
            }
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

    @Published var isHealthConnected: Bool
    @Published var profileImageData: Data?
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let dataTransferService: DataTransferService

    init(
        defaults: UserDefaults = .standard,
        dataTransferService: DataTransferService = DataTransferService()
    ) {
        self.defaults = defaults
        self.dataTransferService = dataTransferService

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
        isHealthConnected = defaults.bool(forKey: Keys.isHealthConnected)
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

        defaults.set(isHealthConnected, forKey: Keys.isHealthConnected)
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
        performTransfer {
            try dataTransferService.exportCSV(dbQueue: dbQueue)
        }
    }

    func exportJSON(dbQueue: DatabaseQueue) -> DataTransferExportResult? {
        performTransfer {
            try dataTransferService.exportJSON(dbQueue: dbQueue)
        }
    }

    func backup(dbQueue: DatabaseQueue) -> DataTransferExportResult? {
        performTransfer {
            try dataTransferService.backup(dbQueue: dbQueue)
        }
    }

    func restore(from fileURL: URL, dbQueue: DatabaseQueue) -> DataTransferRestoreResult? {
        do {
            let result = try dataTransferService.restore(from: fileURL, dbQueue: dbQueue)
            statusMessage = "\(result.summary) Imported from \(result.stagedURL.path)."
            errorMessage = nil
            return result
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            return nil
        }
    }

    func dataFolderPath() -> String {
        dataTransferService.appDataFolderPath()
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

    private func performTransfer(_ action: () throws -> DataTransferExportResult) -> DataTransferExportResult? {
        do {
            let result = try action()
            statusMessage = result.summary
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
    private struct SharePayload: Identifiable {
        let id = UUID()
        let title: String
        let fileURL: URL
    }

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingResetConfirmation = false
    @State private var activeSharePayload: SharePayload?
    @State private var isRestoreImporterPresented = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsScreenHeader(title: "Data Handling", onBack: { dismiss() })

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Export and Backup")
                            .uiAssetText(.caption)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        Text("Files folder: \(viewModel.dataFolderPath())")
                            .uiAssetText(.footnote)
                            .foregroundStyle(UIAssetColors.textSecondary)

                        dataActionCard(
                            symbol: "tablecells",
                            title: "Export to CSV",
                            description: "Create a CSV file export of your logged workouts.",
                            action: {
                                guard let result = viewModel.exportCSV(dbQueue: container.dbQueue) else {
                                    return
                                }
                                activeSharePayload = SharePayload(
                                    title: "CSV Export",
                                    fileURL: result.fileURL
                                )
                            }
                        )

                        dataActionCard(
                            symbol: "curlybraces",
                            title: "Export to JSON",
                            description: "Create a JSON export for structured backup or migration.",
                            action: {
                                guard let result = viewModel.exportJSON(dbQueue: container.dbQueue) else {
                                    return
                                }
                                activeSharePayload = SharePayload(
                                    title: "JSON Export",
                                    fileURL: result.fileURL
                                )
                            }
                        )

                        dataActionCard(
                            symbol: "externaldrive.badge.icloud",
                            title: "Backup",
                            description: "Create a full local backup snapshot of app data.",
                            action: {
                                guard let result = viewModel.backup(dbQueue: container.dbQueue) else {
                                    return
                                }
                                activeSharePayload = SharePayload(
                                    title: "Backup",
                                    fileURL: result.fileURL
                                )
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
                                .uiAssetText(.footnote)
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
        }
        .background(UIAssetColors.secondary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
        .sheet(item: $activeSharePayload) { payload in
            ActivityShareSheet(activityItems: [payload.fileURL]) { completed, activityType in
                if completed {
                    let destination = activityType?.rawValue ?? "share destination"
                    viewModel.statusMessage = "\(payload.title) shared via \(destination). File: \(payload.fileURL.path)"
                } else {
                    viewModel.statusMessage = "\(payload.title) saved at \(payload.fileURL.path)"
                }
            }
        }
        .alert("Data Handling", isPresented: statusAlertPresented) {
            Button("OK") {
                viewModel.statusMessage = nil
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? viewModel.statusMessage ?? "")
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
                        .uiAssetText(.h5)
                        .foregroundStyle(UIAssetColors.textPrimary)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UIAssetColors.textSecondary)
                }

                Text(description)
                    .uiAssetText(.footnote)
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

    private var statusAlertPresented: Binding<Bool> {
        Binding {
            viewModel.statusMessage != nil || viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.statusMessage = nil
                viewModel.errorMessage = nil
            }
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
                        .uiAssetText(.caption)
                        .foregroundStyle(UIAssetColors.textSecondary)

                    VStack(spacing: 12) {
                        profileImagePreview
                            .frame(width: 96, height: 96)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text("Choose image")
                                .font(.app(.subheadline))
                                .foregroundStyle(UIAssetColors.accent)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                                        .fill(UIAssetColors.accentSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                                        .stroke(UIAssetColors.accent.opacity(0.25), lineWidth: 1)
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
                        .uiAssetText(.caption)
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
                        .uiAssetText(.caption)
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
                            .uiAssetText(.caption)
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
                        .stroke(UIAssetColors.border, lineWidth: 1)
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
                        .stroke(UIAssetColors.border, lineWidth: 1)
                )
        }
    }

    private func profileNameInput(
        placeholder: String,
        text: Binding<String>,
        field: ProfileField
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.app(.body))
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
                        ? UIAssetColors.accent.opacity(0.7)
                        : UIAssetColors.border.opacity(1.6),
                        lineWidth: 1
                    )
            )
            .focused($focusedProfileField, equals: field)
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

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: (_ completed: Bool, _ activityType: UIActivity.ActivityType?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete(completed, activityType)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
