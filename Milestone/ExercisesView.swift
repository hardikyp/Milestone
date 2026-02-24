import SwiftUI
import WebKit

struct ExercisesView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = ExercisesViewModel()
    @State private var isCreateExercisePresented = false
    @State private var pendingDeleteExercise: Exercise?
    @State private var selectedCategoryFilter: ExerciseCategory?
    @State private var navigationPath: [String] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Exercises")
                        .font(.app(.title))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        isCreateExercisePresented = true
                    } label: {
                        HStack(spacing: -6) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 38, height: 38)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(BouncyOpaqueButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(height: 1)

                    HStack(spacing: 0) {
                        filterTab(title: "All", category: nil)
                        ForEach(ExerciseCategory.allCases, id: \.rawValue) { category in
                            filterTab(title: category.displayName, category: category)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                List(filteredExercises) { exercise in
                    Button {
                        navigationPath.append(exercise.id)
                    } label: {
                        exerciseRow(exercise)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if exercise.source != .seeded {
                            Button {
                                pendingDeleteExercise = exercise
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isCreateExercisePresented) {
                CreateExerciseView { input in
                    Task {
                        await viewModel.createExercise(
                            input: input,
                            repository: container.exerciseRepository
                        )

                        if viewModel.errorMessage == nil {
                            isCreateExercisePresented = false
                        }
                    }
                }
            }
            .task {
                await viewModel.loadExercises(repository: container.exerciseRepository)
            }
            .alert("Exercise Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert(
                "Delete Exercise",
                isPresented: Binding(
                    get: { pendingDeleteExercise != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingDeleteExercise = nil
                        }
                    }
                )
            ) {
                Button("Yes", role: .destructive) {
                    guard let exercise = pendingDeleteExercise else { return }
                    pendingDeleteExercise = nil
                    Task {
                        await viewModel.deleteExercise(
                            id: exercise.id,
                            repository: container.exerciseRepository
                        )
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteExercise = nil
                }
            } message: {
                Text("Are you sure you want to delete this exercise?")
            }
            .navigationDestination(for: String.self) { exerciseID in
                if let exercise = viewModel.exercises.first(where: { $0.id == exerciseID }) {
                    ExerciseDetailView(exercise: exercise) { updated in
                        viewModel.replaceExercise(updated)
                    } onDidDelete: { deletedID in
                        viewModel.removeExercise(id: deletedID)
                    }
                } else {
                    Text("Exercise not found")
                }
            }
        }
    }

    private var filteredExercises: [Exercise] {
        guard let selectedCategoryFilter else {
            return viewModel.exercises
        }
        return viewModel.exercises.filter { $0.category == selectedCategoryFilter }
    }

    @ViewBuilder
    private func filterTab(title: String, category: ExerciseCategory?) -> some View {
        let isSelected = selectedCategoryFilter == category
        Button {
            selectedCategoryFilter = category
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.app(.subheadline))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                Rectangle()
                    .fill(isSelected ? Color.primary : Color.clear)
                    .frame(height: 3)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.listSymbolName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(exercise.name)
                    if exercise.source == .user {
                        Text("User")
                            .font(.app(.caption2))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                Text("\(exercise.category?.displayName ?? "Uncategorized") • \(exercise.type.displayName)")
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

private struct BouncyOpaqueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

@MainActor
final class ExercisesViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var errorMessage: String?

    func loadExercises(repository: ExerciseRepository) async {
        do {
            exercises = try repository.fetchAllExercises(includeArchived: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createExercise(input: CreateExerciseInput, repository: ExerciseRepository) async {
        do {
            _ = try repository.createExercise(
                name: input.name,
                type: input.type,
                category: input.category,
                description: input.description,
                targetArea: input.targetArea,
                mediaUri: input.mediaURI
            )

            exercises = try repository.fetchAllExercises(includeArchived: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replaceExercise(_ exercise: Exercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else {
            return
        }
        exercises[index] = exercise
    }

    func removeExercise(id: String) {
        exercises.removeAll { $0.id == id }
    }

    func deleteExercise(id: String, repository: ExerciseRepository) async {
        do {
            try repository.deleteExercise(id: id)
            removeExercise(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ExerciseDetailView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var exercise: Exercise
    @State private var isEditPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var errorMessage: String?

    private let onDidUpdate: (Exercise) -> Void
    private let onDidDelete: (String) -> Void

    init(
        exercise: Exercise,
        onDidUpdate: @escaping (Exercise) -> Void,
        onDidDelete: @escaping (String) -> Void
    ) {
        self._exercise = State(initialValue: exercise)
        self.onDidUpdate = onDidUpdate
        self.onDidDelete = onDidDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Button {
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
                    .buttonStyle(BouncyOpaqueButtonStyle())

                    Text(exercise.name)
                        .font(.app(.title2))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        isEditPresented = true
                    } label: {
                        Text("Edit")
                            .font(.app(.subheadline))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black)
                            )
                    }
                    .buttonStyle(BouncyOpaqueButtonStyle())
                }

                if let mediaURI = exercise.mediaURI,
                   let url = Self.resolvedMediaURL(from: mediaURI) {
                    GIFWebView(url: url)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, -16)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, -16)
                        .overlay {
                            Text("No GIF available")
                                .foregroundStyle(.secondary)
                        }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Category: \(exercise.category?.displayName ?? "Uncategorized")")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Type: \(exercise.type.displayName)")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                }

                if let targetArea = exercise.targetArea,
                   !targetArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Target area: \(targetArea)")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                }

                Text("How to do")
                    .font(.app(.headline))
                    .fontWeight(.bold)

                if instructionLines.isEmpty {
                    Text("No instructions available yet.")
                        .font(.app(.body))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(instructionLines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(line)
                                    .fontWeight(.regular)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .font(.app(.body))
                }

                if exercise.source != .seeded {
                    Divider()
                        .padding(.top, 8)

                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Exercise")
                            Spacer()
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isEditPresented) {
            CreateExerciseView(
                title: "Edit Exercise",
                confirmButtonTitle: "Update",
                initialInput: exercise.createExerciseInput
            ) { input in
                Task {
                    await updateExercise(input)
                }
            }
        }
        .alert("Exercise Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert(
            "Delete Exercise",
            isPresented: $isDeleteConfirmationPresented
        ) {
            Button("Yes", role: .destructive) {
                Task {
                    await deleteExercise()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this exercise?")
        }
    }

    private func updateExercise(_ input: CreateExerciseInput) async {
        do {
            let updated = try container.exerciseRepository.updateExercise(
                id: exercise.id,
                name: input.name,
                type: input.type,
                category: input.category,
                description: input.description,
                targetArea: input.targetArea,
                mediaUri: input.mediaURI
            )
            exercise = updated
            onDidUpdate(updated)
            isEditPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteExercise() async {
        do {
            try container.exerciseRepository.deleteExercise(id: exercise.id)
            onDidDelete(exercise.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func resolvedMediaURL(from rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        if let url = URL(string: value), let scheme = url.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" || scheme == "file" {
                return url
            }
        }

        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value)
        }

        let nsValue = value as NSString
        let fullName = nsValue.lastPathComponent
        let fileName = (fullName as NSString).deletingPathExtension
        let ext = (fullName as NSString).pathExtension
        let directory = nsValue.deletingLastPathComponent
        let subdirectory = directory.isEmpty ? nil : directory

        if !fileName.isEmpty, !ext.isEmpty,
           let bundleURL = Bundle.main.url(
            forResource: fileName,
            withExtension: ext,
            subdirectory: subdirectory
           ) {
            return bundleURL
        }

        #if DEBUG
        let sourceFileDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let localURL = sourceFileDirectory.appendingPathComponent(value)
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }
        #endif

        return nil
    }

    private var instructionLines: [String] {
        guard let description = exercise.description else {
            return []
        }

        return description
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct GIFWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.contentMode = .scaleAspectFit
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if url.isFileURL {
            let accessURL = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: accessURL)
        } else {
            webView.load(URLRequest(url: url))
        }
    }
}

private extension Exercise {
    var createExerciseInput: CreateExerciseInput {
        CreateExerciseInput(
            name: name,
            type: type,
            category: category ?? .push,
            description: description,
            targetArea: targetArea,
            mediaURI: mediaURI
        )
    }

    var listSymbolName: String {
        if category == .core {
            return "figure.core.training.circle.fill"
        }
        if category == .cardio || type == .cardio {
            return "figure.run.circle.fill"
        }
        return "figure.strengthtraining.traditional.circle.fill"
    }
}

private extension ExerciseType {
    var displayName: String {
        switch self {
        case .weight:
            return "Weight"
        case .cardio:
            return "Cardio"
        case .functional:
            return "Functional"
        }
    }
}

private extension ExerciseCategory {
    var displayName: String {
        switch self {
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .core: return "Core"
        case .cardio: return "Cardio"
        }
    }
}

#Preview {
    ExercisesView()
}
