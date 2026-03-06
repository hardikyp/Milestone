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
            ZStack {
                UIAssetInlineDropdownHost {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(UIAssetFloatingActionButtonStyle())

                            Text(title)
                                .uiAssetText(.h2)
                                .foregroundStyle(UIAssetColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(confirmButtonTitle) {
                                do {
                                    let input = try viewModel.makeInput()
                                    onSave(input)
                                } catch {
                                    viewModel.errorMessage = error.localizedDescription
                                }
                            }
                            .buttonStyle(UIAssetTextActionButtonStyle())
                            .frame(minWidth: 92, alignment: .trailing)
                        }
                        .padding(.bottom, 4)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercise")
                                .uiAssetText(.footnote)
                                .foregroundStyle(UIAssetColors.textSecondary)

                            UIAssetTextField(
                                title: "Name",
                                placeholder: "Exercise name",
                                text: $viewModel.name
                            )

                            dropdownField(
                                title: "Type",
                                options: exerciseTypeTitles,
                                selection: exerciseTypeSelection,
                                width: 150
                            )
                            .zIndex(30)

                            dropdownField(
                                title: "Category",
                                options: exerciseCategoryTitles,
                                selection: exerciseCategorySelection,
                                width: 170
                            )
                            .zIndex(29)

                            UIAssetTextField(
                                title: "Target Area",
                                placeholder: "Chest, shoulders, glutes...",
                                text: $viewModel.targetArea
                            )

                            UIAssetTextField(
                                title: "Media GIF URL",
                                placeholder: "https://... or local path",
                                text: $viewModel.mediaURI,
                                keyboardType: .URL
                            )

                            multilineField(
                                title: "Description",
                                placeholder: "Write step-by-step instructions...",
                                text: $viewModel.description
                            )
                        }
                        .padding(16)
                        .uiAssetCardSurface(fill: UIAssetColors.primary)
                    }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                }
                .background(UIAssetColors.secondary.ignoresSafeArea())
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                .dismissKeyboardOnBackgroundTap()

                if let error = viewModel.errorMessage {
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.24))
                            .ignoresSafeArea()

                        UIAssetAlertDialog(
                            title: "Invalid Exercise",
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
                }
            }
        }
    }

    @ViewBuilder
    private func dropdownField(
        title: String,
        options: [String],
        selection: Binding<String>,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .uiAssetText(.footnote)
                .foregroundStyle(UIAssetColors.textSecondary)

            UIAssetSettingsInlineDropdown(
                options: options,
                selected: selection,
                panelAlignment: .leading,
                panelWidth: width,
                textStyle: .paragraph
            )
        }
    }

    @ViewBuilder
    private func multilineField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .uiAssetText(.footnote)
                .foregroundStyle(UIAssetColors.textSecondary)

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(UIAssetTextStyle.paragraph.font)
                        .foregroundStyle(UIAssetColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: text)
                    .font(UIAssetTextStyle.paragraph.font)
                    .foregroundStyle(UIAssetColors.textPrimary)
                    .frame(minHeight: 130)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .scrollContentBackground(.hidden)
            }
            .background(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .fill(UIAssetColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .stroke(UIAssetColors.border, lineWidth: 1)
            )
        }
    }

    private var exerciseTypeTitles: [String] {
        ExerciseType.allCases.map(\.createViewDisplayName)
    }

    private var exerciseCategoryTitles: [String] {
        ExerciseCategory.allCases.map(\.createViewDisplayName)
    }

    private var exerciseTypeSelection: Binding<String> {
        Binding {
            viewModel.type.createViewDisplayName
        } set: { selected in
            if let matched = ExerciseType.allCases.first(where: { $0.createViewDisplayName == selected }) {
                viewModel.type = matched
            }
        }
    }

    private var exerciseCategorySelection: Binding<String> {
        Binding {
            viewModel.category.createViewDisplayName
        } set: { selected in
            if let matched = ExerciseCategory.allCases.first(where: { $0.createViewDisplayName == selected }) {
                viewModel.category = matched
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

private extension ExerciseType {
    var createViewDisplayName: String {
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
    var createViewDisplayName: String {
        switch self {
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .core: return "Core"
        case .cardio: return "Cardio"
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
