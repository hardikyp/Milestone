import SwiftUI
import Foundation
import GRDB
import PhotosUI
import UIKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.app(.title))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle("Profile")
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        HStack(spacing: 12) {
                            profileImageView
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.fullNameDisplay)
                                    .font(.app(.headline))

                                Text(viewModel.genderAgeDisplay)
                                    .font(.app(.subheadline))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Divider()

                        NavigationLink {
                            UserProfileView(viewModel: viewModel)
                        } label: {
                            settingsRow(icon: "person.crop.circle", title: "Modify Details")
                        }
                    }
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Preferences")

                        HStack(spacing: 12) {
                            Label("Weight Unit", systemImage: "scalemass")
                            Spacer()
                            inlineUnitPicker(
                                options: SettingsViewModel.WeightUnit.allCases,
                                selected: viewModel.weightUnit
                            ) { unit in
                                viewModel.weightUnit = unit
                            }
                        }

                        Divider()

                        HStack(spacing: 12) {
                            Label("Distance Unit", systemImage: "ruler")
                            Spacer()
                            inlineUnitPicker(
                                options: SettingsViewModel.DistanceUnit.allCases,
                                selected: viewModel.distanceUnit
                            ) { unit in
                                viewModel.distanceUnit = unit
                            }
                        }
                    }
                    .padding(16)
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Health and Fitness Data")

                        HStack(spacing: 12) {
                            Label("Connect HealthKit", systemImage: "heart.text.square")
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    viewModel.isHealthConnected.toggle()
                                }
                            } label: {
                                ZStack(alignment: viewModel.isHealthConnected ? .trailing : .leading) {
                                    Capsule(style: .continuous)
                                        .fill(viewModel.isHealthConnected ? Color.black : Color.secondary.opacity(0.25))
                                        .frame(width: 52, height: 30)
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                        .padding(3)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle("Data handling")
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        NavigationLink {
                            DataHandlingView(viewModel: viewModel)
                        } label: {
                            settingsRow(icon: "externaldrive", title: "Data")
                        }
                    }
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 16) {
                        Label("About", systemImage: "info.circle")
                        Text("Milestone | v1.0\n\nDesigned for the love of training by Hardik Patil.\nBuilt local-first so your progress stays yours.\nSimple, friendly workout tracking for everyday consistency.")
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(cardBackground)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func settingsRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22, height: 22)
            Text(title)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func inlineUnitPicker<Option: CaseIterable & Identifiable>(
        options: Option.AllCases,
        selected: Option,
        onSelect: @escaping (Option) -> Void
    ) -> some View where Option: RawRepresentable, Option.RawValue == String {
        HStack(spacing: 0) {
            ForEach(Array(options), id: \.id) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option.rawValue.uppercased())
                        .font(.app(.caption))
                        .foregroundStyle(selected.id == option.id ? Color.primary : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.primary)
                                .frame(height: selected.id == option.id ? 2 : 0)
                                .padding(.horizontal, 4)
                        }
                }
                .buttonStyle(.plain)

                if option.id != Array(options).last?.id {
                    Divider()
                        .frame(height: 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.app(.subheadline))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    BouncyPressableButton {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 36, height: 36)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    Text("Data Handling")
                        .font(.app(.title))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    dataRow(
                        title: "Export to CSV",
                        description: "Create a CSV file export of your logged workouts."
                    )
                    Divider()
                    dataRow(
                        title: "Export to JSON",
                        description: "Create a JSON export for structured backup or migration."
                    )
                    Divider()
                    dataRow(
                        title: "Backup",
                        description: "Create a full local backup snapshot of app data."
                    )
                    Divider()
                    dataRow(
                        title: "Restore",
                        description: "Restore app data from a previously created backup."
                    )
                }
                .padding(16)
                .background(dataCardBackground)

                BouncyPressableButton {
                    showingResetConfirmation = true
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reset data")
                            .foregroundStyle(.red)
                        Text("Permanently clear all local workout, exercise, and template data.")
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(dataCardBackground)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

    private var dataCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    BouncyPressableButton {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 36, height: 36)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    Text("User Profile")
                        .font(.app(.title))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    BouncyPressableButton {
                        saveAndDismiss()
                    } label: {
                        Text("Save")
                            .font(.app(.subheadline))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black)
                            )
                    }
                }

                VStack(spacing: 12) {
                    profileImagePreview
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Add profile image", systemImage: "photo")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(16)
                .background(profileCardBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Name")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)

                    labeledTextField(
                        title: "First name",
                        text: $firstName
                    )
                    labeledTextField(
                        title: "Last name",
                        text: $lastName
                    )
                }
                .padding(16)
                .background(profileCardBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Body metrics")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)

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
                    labeledTextField(
                        title: "Age",
                        text: $age,
                        keyboardType: .numberPad
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gender")
                            .font(.app(.subheadline))
                            .foregroundStyle(.secondary)

                        genderSelector
                    }
                }
                .padding(16)
                .background(profileCardBackground)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    profileImageData = data
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
                .padding(.vertical, 6)
            Divider()
        }
    }

    private var profileCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
    }

    private var genderGridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    @ViewBuilder
    private var genderSelector: some View {
        LazyVGrid(columns: genderGridColumns, spacing: 8) {
            ForEach(SettingsViewModel.Gender.allCases) { option in
                Button {
                    gender = option
                } label: {
                    Text(option.displayName)
                        .font(.app(.caption))
                        .foregroundStyle(gender == option ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(gender == option ? Color.black : Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.black.opacity(gender == option ? 0 : 0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
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

private struct BouncyPressableButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @GestureState private var isPressed = false

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .opacity(1)
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
    }
}
