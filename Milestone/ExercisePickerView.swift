import SwiftUI

struct ExercisePickerView: View {
    struct AddedExerciseSelection: Identifiable, Hashable {
        var id: String { sessionExerciseID }
        let sessionExerciseID: String
        let exerciseName: String
        let exerciseType: ExerciseType
    }

    let sessionId: String
    let sessionCategoryName: String?
    let onDidAddExercise: (AddedExerciseSelection) -> Void

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = ExercisePickerViewModel()
    @State private var searchText = ""
    @State private var selectedCategoryTab = "All"
    @State private var isCreateExercisePresented = false

    private var categoryTabs: [String] {
        ["All"] + ExerciseCategory.allCases.map(\.pickerDisplayName)
    }

    private var selectedCategoryFilter: ExerciseCategory? {
        guard selectedCategoryTab != "All" else { return nil }
        return ExerciseCategory.allCases.first { $0.pickerDisplayName == selectedCategoryTab }
    }

    private var filteredExercises: [Exercise] {
        viewModel.filteredExercises(query: searchText, category: selectedCategoryFilter)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(UIAssetFloatingActionButtonStyle())

                        Text("Add Exercise")
                            .uiAssetText(.h2)
                            .foregroundStyle(UIAssetColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("New") {
                            isCreateExercisePresented = true
                        }
                        .buttonStyle(UIAssetTextActionButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    UIAssetTabFilter(
                        tabs: categoryTabs,
                        selectedTab: $selectedCategoryTab
                    )
                    .padding(.horizontal, 16)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if filteredExercises.isEmpty {
                                Text("No exercises found")
                                    .uiAssetText(.paragraph)
                                    .foregroundStyle(UIAssetColors.textSecondary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .uiAssetCardSurface(fill: UIAssetColors.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(filteredExercises) { exercise in
                                    Button {
                                        Task {
                                            await viewModel.addExistingExercise(
                                                sessionId: sessionId,
                                                exercise: exercise,
                                                sessionExerciseRepository: container.sessionExerciseRepository
                                            )

                                            if viewModel.errorMessage == nil,
                                               let added = viewModel.lastAddedExerciseSelection {
                                                onDidAddExercise(added)
                                                dismiss()
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(exercise.name)
                                                    .uiAssetText(.paragraph)
                                                    .foregroundStyle(UIAssetColors.textPrimary)
                                                Text(exercise.type.displayName)
                                                    .uiAssetText(.caption)
                                                    .foregroundStyle(UIAssetColors.textSecondary)
                                            }

                                            Spacer(minLength: 0)

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(UIAssetColors.textSecondary)
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .uiAssetCardSurface(fill: UIAssetColors.primary)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    .animation(nil, value: selectedCategoryTab)

                }
                .background(UIAssetColors.secondary.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(UIAssetColors.textSecondary)

                        TextField("Search exercises", text: $searchText)
                            .font(.app(.body))
                            .foregroundStyle(UIAssetColors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .fill(UIAssetColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .stroke(UIAssetColors.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .background(UIAssetColors.secondary)
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                .dismissKeyboardOnBackgroundTap()
                .sheet(isPresented: $isCreateExercisePresented) {
                    CreateExerciseView { input in
                        Task {
                            await viewModel.createAndAddExercise(
                                sessionId: sessionId,
                                input: input,
                                exerciseRepository: container.exerciseRepository,
                                sessionExerciseRepository: container.sessionExerciseRepository
                            )

                            if viewModel.errorMessage == nil,
                               let added = viewModel.lastAddedExerciseSelection {
                                isCreateExercisePresented = false
                                onDidAddExercise(added)
                                dismiss()
                            }
                        }
                    }
                }
                .task {
                    await viewModel.loadExercises(repository: container.exerciseRepository)
                }

                if let error = viewModel.errorMessage {
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.24))
                            .ignoresSafeArea()

                        UIAssetAlertDialog(
                            title: "Exercise Error",
                            message: error,
                            cancelTitle: "Close",
                            destructiveTitle: "OK"
                        ) {
                            viewModel.errorMessage = nil
                        } onDestructive: {
                            viewModel.errorMessage = nil
                        }
                        .padding(.horizontal, 16)
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

@MainActor
final class ExercisePickerViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    @Published var errorMessage: String?
    @Published var lastAddedExerciseSelection: ExercisePickerView.AddedExerciseSelection?

    func loadExercises(repository: ExerciseRepository) async {
        do {
            exercises = try repository.fetchAllExercises(includeArchived: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func filteredExercises(query: String, category: ExerciseCategory?) -> [Exercise] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let categoryFiltered = exercises.filter { exercise in
            guard let category else { return true }
            return exercise.category == category
        }

        guard !trimmed.isEmpty else { return categoryFiltered }

        return categoryFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func addExistingExercise(
        sessionId: String,
        exercise: Exercise,
        sessionExerciseRepository: SessionExerciseRepository
    ) async {
        do {
            let nextOrder = try sessionExerciseRepository.fetchSessionExercises(sessionId: sessionId).count + 1
            let sessionExercise = try sessionExerciseRepository.addExerciseToSession(
                sessionId: sessionId,
                exerciseId: exercise.id,
                orderIndex: nextOrder,
                notes: nil
            )
            lastAddedExerciseSelection = ExercisePickerView.AddedExerciseSelection(
                sessionExerciseID: sessionExercise.id,
                exerciseName: exercise.name,
                exerciseType: exercise.type
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createAndAddExercise(
        sessionId: String,
        input: CreateExerciseInput,
        exerciseRepository: ExerciseRepository,
        sessionExerciseRepository: SessionExerciseRepository
    ) async {
        do {
            let exercise = try exerciseRepository.createExercise(
                name: input.name,
                type: input.type,
                category: input.category,
                description: input.description,
                targetArea: input.targetArea,
                mediaUri: input.mediaURI
            )

            let nextOrder = try sessionExerciseRepository.fetchSessionExercises(sessionId: sessionId).count + 1
            let sessionExercise = try sessionExerciseRepository.addExerciseToSession(
                sessionId: sessionId,
                exerciseId: exercise.id,
                orderIndex: nextOrder,
                notes: nil
            )
            lastAddedExerciseSelection = ExercisePickerView.AddedExerciseSelection(
                sessionExerciseID: sessionExercise.id,
                exerciseName: exercise.name,
                exerciseType: exercise.type
            )

            exercises = try exerciseRepository.fetchAllExercises(includeArchived: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension ExerciseType {
    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .cardio: return "Cardio"
        case .functional: return "Functional"
        }
    }
}

private extension ExerciseCategory {
    var pickerDisplayName: String {
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
    ExercisePickerView(sessionId: "session", sessionCategoryName: "Push", onDidAddExercise: { _ in })
}
