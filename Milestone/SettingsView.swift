import SwiftUI
import Foundation
import GRDB
import PhotosUI
import UIKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        profileImageView
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())

                        Text(viewModel.fullNameDisplay)
                            .font(.app(.headline))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }

                Section("User Details") {
                    NavigationLink {
                        UserProfileView(viewModel: viewModel)
                    } label: {
                        Label("Edit Profile", systemImage: "person.crop.circle")
                    }
                }

                Section("Preferences") {
                    HStack {
                        Label("Weight Unit", systemImage: "scalemass")
                        Spacer()
                        Picker("Weight Unit", selection: $viewModel.weightUnit) {
                            ForEach(SettingsViewModel.WeightUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Label("Distance Unit", systemImage: "ruler")
                        Spacer()
                        Picker("Distance Unit", selection: $viewModel.distanceUnit) {
                            ForEach(SettingsViewModel.DistanceUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                Section("Access Health and Fitness Data") {
                    Toggle(isOn: $viewModel.isHealthConnected) {
                        Label("Connect HealthKit", systemImage: "heart.text.square")
                    }
                }

                Section("Data") {
                    NavigationLink {
                        DataHandlingView(viewModel: viewModel)
                    } label: {
                        Label("Data Handling", systemImage: "externaldrive")
                    }
                }

                Section("App") {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("About", systemImage: "info.circle")
                        Text("Milestone | v1.0\n\nDesigned for the love of training by Hardik Patil.\nBuilt local-first so your progress stays yours.\nSimple, friendly workout tracking for everyday consistency. ")
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentMargins(.top, 16, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: viewModel.weightUnit) { _, _ in viewModel.save() }
            .onChange(of: viewModel.distanceUnit) { _, _ in viewModel.save() }
            .onChange(of: viewModel.isHealthConnected) { _, _ in viewModel.save() }
            .alert("Settings", isPresented: .constant(viewModel.statusMessage != nil || viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.statusMessage = nil
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? viewModel.statusMessage ?? "")
            }
            .overlay(alignment: .top) {
                SettingsTopFadeNavigationBackground()
            }
        }
    }

    @ViewBuilder
    private var profileImageView: some View {
        if let image = viewModel.profileUIImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsTopFadeNavigationBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.85),
                Color(.systemBackground).opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 75)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
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
            case .lb: return "Pound"
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

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

    var profileUIImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }

    func toggleHealthConnection() {
        isHealthConnected.toggle()
        save()
    }

    func exportCSV() {
        statusMessage = "CSV export action is ready. File output wiring is next."
    }

    func exportJSON() {
        statusMessage = "JSON export action is ready. File output wiring is next."
    }

    func backup() {
        statusMessage = "Backup action is ready. Archive generation is next."
    }

    func restore() {
        statusMessage = "Restore action is ready. File import wiring is next."
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

struct DataHandlingView: View {
    @EnvironmentObject private var container: AppContainer
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingResetConfirmation = false

    var body: some View {
        Form {
            Section {
                dataRow(
                    title: "Export to CSV",
                    description: "Create a CSV file export of your logged workouts."
                )
                dataRow(
                    title: "Export to JSON",
                    description: "Create a JSON export for structured backup or migration."
                )
                dataRow(
                    title: "Backup",
                    description: "Create a full local backup snapshot of app data."
                )
                dataRow(
                    title: "Restore",
                    description: "Restore app data from a previously created backup."
                )
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset data")
                            .foregroundStyle(.red)
                        Text("Permanently clear all local workout, exercise, and template data.")
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("Data Handling")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset data", isPresented: $showingResetConfirmation) {
            Button("Yes", role: .destructive) {
                viewModel.resetData(dbQueue: container.dbQueue)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to reset the data?")
        }
    }

    @ViewBuilder
    private func dataRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(.primary)
            Text(description)
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct UserProfileView: View {
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
        Form {
            Section("Profile image") {
                VStack(spacing: 12) {
                    profileImagePreview
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Add profile image", systemImage: "photo")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Section {
                labeledTextField(
                    title: "First name",
                    text: $firstName
                )

                labeledTextField(
                    title: "Last name",
                    text: $lastName
                )
            } header: {
                Text("Name")
            } footer: {
                Text("Input your first and last name.")
            }

            Section {
                labeledTextField(
                    title: "Weight (\(viewModel.weightUnit.displayName))",
                    text: $bodyWeight,
                    keyboardType: .decimalPad
                )

                labeledTextField(
                    title: "Height (cm)",
                    text: $bodyHeight,
                    keyboardType: .numberPad
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Gender")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)

                    Picker("Gender", selection: $gender) {
                        ForEach(SettingsViewModel.Gender.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .labelsHidden()
                }
            } header: {
                Text("Body metrics")
            } footer: {
                Text("Input body metrics.")
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    profileImageData = data
                }
            }
        }
        .navigationTitle("User Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
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
        }
    }

    @ViewBuilder
    private var profileImagePreview: some View {
        if let data = profileImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func labeledTextField(
        title: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.app(.subheadline))
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
        }
    }
}
