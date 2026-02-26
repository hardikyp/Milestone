import SwiftUI

struct TemplatePickerView: View {
    var onStart: (_ templateId: String, _ precreateSets: Bool) -> Void

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplatePickerViewModel()
    @State private var precreateSets = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Pre-create target sets", isOn: $precreateSets)
                }

                Section("Templates") {
                    if viewModel.templates.isEmpty {
                        Text("No templates available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.templates) { template in
                            Button {
                                onStart(template.id, precreateSets)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .foregroundStyle(.primary)
                                    if let description = template.description, !description.isEmpty {
                                        Text(description)
                                            .font(.app(.caption))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .navigationTitle("Start from Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.load(templateRepository: container.templateRepository)
            }
            .alert("Template Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
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
