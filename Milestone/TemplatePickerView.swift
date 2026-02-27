import SwiftUI

struct TemplatePickerView: View {
    var onStart: (_ templateId: String, _ precreateSets: Bool) -> Void

    private enum CreationSheet: Identifiable {
        case fromSession
        case fromScratch

        var id: String {
            switch self {
            case .fromSession: return "fromSession"
            case .fromScratch: return "fromScratch"
            }
        }
    }

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplatePickerViewModel()
    @State private var precreateSets = false
    @State private var creationSheet: CreationSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Text("Start from Template")
                                .uiAssetText(.h2)
                                .foregroundStyle(UIAssetColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(UIAssetTextActionButtonStyle())
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pre-create target sets")
                                    .uiAssetText(.h5)
                                    .foregroundStyle(UIAssetColors.textPrimary)

                                Text("Auto-fill sets from template targets")
                                    .uiAssetText(.caption)
                                    .foregroundStyle(UIAssetColors.textSecondary)
                            }

                            Spacer(minLength: 0)

                            UIAssetSettingsInlineToggle(isOn: $precreateSets)
                        }
                            .padding(16)
                            .uiAssetCardSurface(fill: UIAssetColors.primary)

                        HStack(spacing: 12) {
                            UIAssetTiledButton(
                                systemImage: "clock.arrow.circlepath",
                                label: "New",
                                description: "From session",
                                variant: .primary
                            ) {
                                creationSheet = .fromSession
                            }

                            UIAssetTiledButton(
                                systemImage: "square.and.pencil",
                                label: "New",
                                description: "Template",
                                variant: .secondary
                            ) {
                                creationSheet = .fromScratch
                            }
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Templates")
                                .uiAssetText(.h5)
                                .foregroundStyle(UIAssetColors.textPrimary)

                            if viewModel.templates.isEmpty {
                                Text("No templates available")
                                    .uiAssetText(.paragraph)
                                    .foregroundStyle(UIAssetColors.textSecondary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .uiAssetCardSurface(fill: UIAssetColors.primary)
                            } else {
                                ForEach(viewModel.templates) { template in
                                    Button {
                                        onStart(template.id, precreateSets)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(template.name)
                                                    .uiAssetText(.subtitle)
                                                    .foregroundStyle(UIAssetColors.textPrimary)
                                                if let description = template.description, !description.isEmpty {
                                                    Text(description)
                                                        .uiAssetText(.caption)
                                                        .foregroundStyle(UIAssetColors.textSecondary)
                                                }
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
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .background(UIAssetColors.secondary.ignoresSafeArea())
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)

                if let error = viewModel.errorMessage {
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.24))
                            .ignoresSafeArea()

                        UIAssetAlertDialog(
                            title: "Template Error",
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
            .task {
                await viewModel.load(templateRepository: container.templateRepository)
            }
            .sheet(item: $creationSheet) { sheet in
                switch sheet {
                case .fromSession:
                    CreateTemplateFromSessionView {
                        Task {
                            await viewModel.load(templateRepository: container.templateRepository)
                        }
                    }
                    .environmentObject(container)

                case .fromScratch:
                    CreateTemplateView {
                        Task {
                            await viewModel.load(templateRepository: container.templateRepository)
                        }
                    }
                    .environmentObject(container)
                }
            }
        }
    }
}

@MainActor
final class TemplatePickerViewModel: ObservableObject {
    @Published var templates: [Template] = []
    @Published var errorMessage: String?

    func load(templateRepository: TemplateRepository) async {
        do {
            templates = try templateRepository.fetchTemplates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    TemplatePickerView { _, _ in }
}

struct CreateTemplateView: View {
    var onCreated: () -> Void

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateTemplateViewModel()

    var body: some View {
        NavigationStack {
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

                            Text("New Template")
                                .uiAssetText(.h2)
                                .foregroundStyle(UIAssetColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button("Save") {
                                Task {
                                    await viewModel.create(templateRepository: container.templateRepository)
                                    if viewModel.errorMessage == nil {
                                        onCreated()
                                        dismiss()
                                    }
                                }
                            }
                            .buttonStyle(UIAssetTextActionButtonStyle())
                            .disabled(!viewModel.canSave)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Template")
                                .uiAssetText(.paragraph)
                                .foregroundStyle(UIAssetColors.textPrimary)

                            UIAssetTextField(
                                title: "Template name",
                                placeholder: "e.g. Push Hypertrophy A",
                                text: $viewModel.templateName
                            )

                            UIAssetTextField(
                                title: "Description",
                                placeholder: "Optional notes for this template",
                                text: $viewModel.description
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .uiAssetCardSurface(fill: UIAssetColors.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .scrollContentBackground(.hidden)
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .alert("Create Template Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

@MainActor
final class CreateTemplateViewModel: ObservableObject {
    @Published var templateName: String = ""
    @Published var description: String = ""
    @Published var errorMessage: String?

    var canSave: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func create(templateRepository: TemplateRepository) async {
        do {
            _ = try templateRepository.createTemplate(
                name: templateName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
