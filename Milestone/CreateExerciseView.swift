import SwiftUI

struct CreateExerciseInput {
    let name: String
    let type: ExerciseType
    let category: ExerciseCategory
    let description: String?
    let targetArea: String?
    let mediaURI: String?
}

struct CreateExerciseView: View {
    let title: String
    let confirmButtonTitle: String
    let onSave: (CreateExerciseInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateExerciseViewModel

    init(
        title: String = "New Exercise",
        confirmButtonTitle: String = "Save",
        initialInput: CreateExerciseInput? = nil,
        onSave: @escaping (CreateExerciseInput) -> Void
    ) {
        self.title = title
        self.confirmButtonTitle = confirmButtonTitle
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: CreateExerciseViewModel(initialInput: initialInput))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $viewModel.name)

                    Picker("Type", selection: $viewModel.type) {
                        Text("Weight").tag(ExerciseType.weight)
                        Text("Cardio").tag(ExerciseType.cardio)
                        Text("Functional").tag(ExerciseType.functional)
                    }

                    Picker("Category", selection: $viewModel.category) {
                        Text("Push").tag(ExerciseCategory.push)
                        Text("Pull").tag(ExerciseCategory.pull)
                        Text("Legs").tag(ExerciseCategory.legs)
                        Text("Core").tag(ExerciseCategory.core)
                        Text("Cardio").tag(ExerciseCategory.cardio)
                    }

                    TextField("Description", text: $viewModel.description, axis: .vertical)
                    TextField("Target Area", text: $viewModel.targetArea)
                    TextField("Media GIF URL", text: $viewModel.mediaURI)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmButtonTitle) {
                        do {
                            let input = try viewModel.makeInput()
                            onSave(input)
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .alert("Invalid Exercise", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

@MainActor
final class CreateExerciseViewModel: ObservableObject {
    @Published var name = ""
    @Published var type: ExerciseType = .weight
    @Published var category: ExerciseCategory = .push
    @Published var description = ""
    @Published var targetArea = ""
    @Published var mediaURI = ""
    @Published var errorMessage: String?

    init(initialInput: CreateExerciseInput? = nil) {
        guard let initialInput else { return }
        name = initialInput.name
        type = initialInput.type
        category = initialInput.category
        description = initialInput.description ?? ""
        targetArea = initialInput.targetArea ?? ""
        mediaURI = initialInput.mediaURI ?? ""
    }

    func makeInput() throws -> CreateExerciseInput {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }

        return CreateExerciseInput(
            name: trimmedName,
            type: type,
            category: category,
            description: description.nilIfBlank,
            targetArea: targetArea.nilIfBlank,
            mediaURI: mediaURI.nilIfBlank
        )
    }

    enum ValidationError: Error, LocalizedError {
        case emptyName

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Name is required."
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    CreateExerciseView { _ in }
}
