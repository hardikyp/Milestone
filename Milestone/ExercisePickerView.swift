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
    @State private var isCreateExercisePresented = false

    private var sessionCategory: ExerciseCategory? {
        guard let sessionCategoryName else { return nil }
        return ExerciseCategory.fromSessionCategoryName(sessionCategoryName)
    }

    var body: some View {
        NavigationStack {
            List(viewModel.filteredExercises(query: searchText, category: sessionCategory)) { exercise in
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                        Text(exercise.type.displayName)
                            .font(.app(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("+ New Exercise") {
                        isCreateExercisePresented = true
                    }
                }
            }
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
            .alert("Exercise Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
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
    static func fromSessionCategoryName(_ value: String) -> ExerciseCategory? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "push": return .push
        case "pull": return .pull
        case "legs": return .legs
        case "core": return .core
        case "cardio": return .cardio
        default: return nil
        }
    }
}

#Preview {
    ExercisePickerView(sessionId: "session", sessionCategoryName: "Push", onDidAddExercise: { _ in })
}
