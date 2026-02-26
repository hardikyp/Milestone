import SwiftUI
import GRDB

struct TemplatesView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = TemplatesViewModel()
    @State private var isCreatePresented = false
    @State private var pendingDeleteTemplate: Template?

    var body: some View {
        List {
            if viewModel.templates.isEmpty {
                Text("No templates yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.templates) { template in
                    NavigationLink {
                        TemplateDetailView(template: template) { deletedID in
                            viewModel.removeTemplate(id: deletedID)
                        }
                            .environmentObject(container)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.app(.headline))
                            if let description = template.description, !description.isEmpty {
                                Text(description)
                                    .font(.app(.caption))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            pendingDeleteTemplate = template
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(UIAssetColors.secondary.ignoresSafeArea())
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New from Session") {
                    isCreatePresented = true
                }
            }
        }
        .sheet(isPresented: $isCreatePresented) {
            CreateTemplateFromSessionView {
                Task {
                    await viewModel.load(templateRepository: container.templateRepository)
                }
            }
            .environmentObject(container)
        }
        .task {
            await viewModel.load(templateRepository: container.templateRepository)
        }
        .alert("Template Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .alert(
            "Delete Template",
            isPresented: Binding(
                get: { pendingDeleteTemplate != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteTemplate = nil
                    }
                }
            )
        ) {
            Button("Yes", role: .destructive) {
                guard let template = pendingDeleteTemplate else { return }
                pendingDeleteTemplate = nil
                Task {
                    await viewModel.deleteTemplate(
                        id: template.id,
                        templateRepository: container.templateRepository
                    )
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteTemplate = nil
            }
        } message: {
            Text("Are you sure you want to delete this template?")
        }
    }
}

@MainActor
final class TemplatesViewModel: ObservableObject {
    @Published var templates: [Template] = []
    @Published var errorMessage: String?

    func load(templateRepository: TemplateRepository) async {
        do {
            templates = try templateRepository.fetchTemplates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeTemplate(id: String) {
        templates.removeAll { $0.id == id }
    }

    func deleteTemplate(id: String, templateRepository: TemplateRepository) async {
        do {
            try templateRepository.deleteTemplate(templateId: id)
            removeTemplate(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TemplateDetailView: View {
    let template: Template
    let onDidDelete: (String) -> Void

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplateDetailViewModel()
    @State private var isDeleteConfirmationPresented = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text(template.name)
                    .font(.app(.headline))
                if let description = template.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Exercises") {
                if viewModel.rows.isEmpty {
                    Text("No exercises")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.rows) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(row.orderIndex). \(row.exerciseName)")
                            if let targetText = row.targetText {
                                Text(targetText)
                                    .font(.app(.caption))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Template")
                        Spacer()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(UIAssetColors.secondary.ignoresSafeArea())
        .navigationTitle("Template")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(templateId: template.id, dbQueue: container.dbQueue)
        }
        .alert("Template Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert(
            "Delete Template",
            isPresented: $isDeleteConfirmationPresented
        ) {
            Button("Yes", role: .destructive) {
                Task {
                    await deleteTemplate()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this template?")
        }
    }

    private func deleteTemplate() async {
        do {
            try container.templateRepository.deleteTemplate(templateId: template.id)
            onDidDelete(template.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class TemplateDetailViewModel: ObservableObject {
    struct DisplayRow: Identifiable {
        let id: String
        let orderIndex: Int
        let exerciseName: String
        let targetText: String?
    }

    @Published var rows: [DisplayRow] = []

    func load(templateId: String, dbQueue: DatabaseQueue) async {
        do {
            let rawRows = try dbQueue.read { db in
                return try GRDB.Row.fetchAll(
                    db,
                    sql: """
                    SELECT
                        te.id,
                        te.order_index,
                        e.name AS exercise_name,
                        te.target_sets,
                        te.target_reps,
                        te.target_weight_kg,
                        te.target_distance_m,
                        te.target_duration_sec
                    FROM template_exercises te
                    JOIN exercises e ON e.id = te.exercise_id
                    WHERE te.template_id = ?
                    ORDER BY te.order_index ASC
                    """,
                    arguments: [templateId]
                )
            }

            rows = rawRows.map { row in
                let targetSets: Int? = row["target_sets"]
                let targetReps: Int? = row["target_reps"]
                let targetWeight: Double? = row["target_weight_kg"]
                let targetDistance: Double? = row["target_distance_m"]
                let targetDuration: Int? = row["target_duration_sec"]

                var parts: [String] = []
                if let targetSets { parts.append("\(targetSets) sets") }
                if let targetReps { parts.append("\(targetReps) reps") }
                if let targetWeight { parts.append(String(format: "%.1f kg", targetWeight)) }
                if let targetDistance { parts.append(String(format: "%.0f m", targetDistance)) }
                if let targetDuration { parts.append("\(targetDuration)s") }

                return DisplayRow(
                    id: row["id"],
                    orderIndex: row["order_index"],
                    exerciseName: row["exercise_name"],
                    targetText: parts.isEmpty ? nil : parts.joined(separator: " • ")
                )
            }
        } catch {
            rows = []
        }
    }
}

struct CreateTemplateFromSessionView: View {
    var onCreated: () -> Void

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateTemplateFromSessionViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Template name", text: $viewModel.templateName)
                    TextField("Description (optional)", text: $viewModel.description)
                }

                Section("Source Session") {
                    if viewModel.sessions.isEmpty {
                        Text("No sessions available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Session", selection: $viewModel.selectedSessionId) {
                            ForEach(viewModel.sessions) { session in
                                Text(session.label).tag(Optional(session.id))
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.create(templateRepository: container.templateRepository)
                            if viewModel.errorMessage == nil {
                                onCreated()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .task {
                await viewModel.loadSessions(sessionRepository: container.sessionRepository)
            }
            .alert("Create Template Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

@MainActor
final class CreateTemplateFromSessionViewModel: ObservableObject {
    struct SessionOption: Identifiable {
        let id: String
        let label: String
    }

    @Published var templateName: String = ""
    @Published var description: String = ""
    @Published var selectedSessionId: String?
    @Published var sessions: [SessionOption] = []
    @Published var errorMessage: String?

    var canSave: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedSessionId != nil
    }

    func loadSessions(sessionRepository: SessionRepository) async {
        do {
            let fetched = try sessionRepository.fetchSessions(limit: 100, offset: 0)
            sessions = fetched.map { session in
                let title = session.name?.isEmpty == false ? session.name! : "Workout"
                return SessionOption(
                    id: session.id,
                    label: "\(title) • \(Self.dateFormatter.string(from: session.startDateTime))"
                )
            }
            if selectedSessionId == nil {
                selectedSessionId = sessions.first?.id
            }
            if templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                templateName = sessions.first?.label.components(separatedBy: " • ").first ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(templateRepository: TemplateRepository) async {
        do {
            guard let selectedSessionId else {
                return
            }

            _ = try templateRepository.createTemplateFromSession(
                sessionId: selectedSessionId,
                templateName: templateName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationStack {
        TemplatesView()
    }
}
