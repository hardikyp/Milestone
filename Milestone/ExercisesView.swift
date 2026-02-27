import SwiftUI
import WebKit

struct ExercisesView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = ExercisesViewModel()
    @State private var isCreateExercisePresented = false
    @State private var pendingDeleteExercise: Exercise?
    @State private var selectedCategoryTab = "All"
    @State private var navigationPath: [String] = []
    @State private var openSwipeExerciseID: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                VStack(spacing: 12) {
                    header

                    UIAssetTabFilter(
                        tabs: categoryTabs,
                        selectedTab: $selectedCategoryTab
                    )
                    .padding(.horizontal, 16)

                    List(filteredExercises) { exercise in
                        ExerciseSwipeRow(
                            canDelete: exercise.source != .seeded,
                            isOpen: openSwipeExerciseID == exercise.id,
                            onOpen: { openSwipeExerciseID = exercise.id },
                            onClose: {
                                if openSwipeExerciseID == exercise.id {
                                    openSwipeExerciseID = nil
                                }
                            },
                            onTapRow: {
                                if openSwipeExerciseID != nil {
                                    openSwipeExerciseID = nil
                                } else {
                                    navigationPath.append(exercise.id)
                                }
                            },
                            onDelete: { pendingDeleteExercise = exercise }
                        ) {
                            exerciseRow(exercise)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(UIAssetColors.secondary)
                }
                .background(UIAssetColors.secondary.ignoresSafeArea())
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
                .navigationDestination(for: String.self) { exerciseID in
                    if let exercise = viewModel.exercises.first(where: { $0.id == exerciseID }) {
                        ExerciseDetailView(exercise: exercise) { updated in
                            viewModel.replaceExercise(updated)
                        } onDidDelete: { deletedID in
                            viewModel.removeExercise(id: deletedID)
                        }
                    } else {
                        Text("Exercise not found")
                            .uiAssetText(.paragraph)
                            .foregroundStyle(UIAssetColors.textSecondary)
                    }
                }

                if let message = viewModel.errorMessage {
                    dialogBackdrop {
                        UIAssetAlertDialog(
                            title: "Exercise Error",
                            message: message,
                            cancelTitle: "Close",
                            destructiveTitle: "OK"
                        ) {
                            viewModel.errorMessage = nil
                        } onDestructive: {
                            viewModel.errorMessage = nil
                        }
                        .padding(.horizontal, 16)
                    }
                } else if let exercise = pendingDeleteExercise {
                    dialogBackdrop {
                        UIAssetAlertDialog(
                            title: "Delete Exercise",
                            message: "Delete \(exercise.name)? This action cannot be undone.",
                            cancelTitle: "Cancel",
                            destructiveTitle: "Delete"
                        ) {
                            pendingDeleteExercise = nil
                        } onDestructive: {
                            let exerciseID = exercise.id
                            pendingDeleteExercise = nil
                            Task {
                                await viewModel.deleteExercise(
                                    id: exerciseID,
                                    repository: container.exerciseRepository
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Exercises")
                .uiAssetText(.h2)
                .foregroundStyle(UIAssetColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                isCreateExercisePresented = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(UIAssetFloatingActionButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var categoryTabs: [String] {
        ["All"] + ExerciseCategory.allCases.map(\.displayName)
    }

    private var selectedCategoryFilter: ExerciseCategory? {
        guard selectedCategoryTab != "All" else { return nil }
        return ExerciseCategory.allCases.first { $0.displayName == selectedCategoryTab }
    }

    private var filteredExercises: [Exercise] {
        guard let selectedCategoryFilter else {
            return viewModel.exercises
        }
        return viewModel.exercises.filter { $0.category == selectedCategoryFilter }
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.listSymbolName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(UIAssetColors.accent)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(exercise.name)
                        .uiAssetText(.subtitle)
                        .foregroundStyle(UIAssetColors.textPrimary)
                    if exercise.source == .user {
                        UIAssetBadge(text: "User", variant: .accent)
                    }
                }

                Text("\(exercise.category?.displayName ?? "Uncategorized") • \(exercise.type.displayName)")
                    .uiAssetText(.caption)
                    .foregroundStyle(UIAssetColors.textSecondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UIAssetColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .uiAssetCardSurface(fill: UIAssetColors.primary)
    }

    private func dialogBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.24))
                .ignoresSafeArea()

            content()
        }
        .transition(.opacity)
    }
}

private struct ExerciseSwipeRow<Content: View>: View {
    let canDelete: Bool
    let isOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onTapRow: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragTranslation: CGFloat = 0

    private let actionRevealWidth: CGFloat = 84
    private let rowHeight: CGFloat = 58
    private let destructiveColor = Color(red: 225/255, green: 0, blue: 0)
    private let settleAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.82)

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDelete {
                Button(action: onDelete) {
                    UIAssetRowSlideActionButton(
                        systemName: "trash",
                        title: "Delete",
                        iconColor: .white,
                        backgroundColor: destructiveColor,
                        borderColor: destructiveColor.opacity(0.7),
                        height: rowHeight
                    )
                }
                .buttonStyle(BouncyPlainButtonStyle())
                .frame(width: actionRevealWidth, height: rowHeight)
                .offset(x: actionOffset)
                .opacity(swipeProgress)
                .allowsHitTesting(swipeProgress > 0.02)
            }

            content()
            .contentShape(Rectangle())
            .onTapGesture {
                onTapRow()
            }
            .offset(x: rowOffset)
            .highPriorityGesture(canDelete ? dragGesture : nil)
        }
        .animation(settleAnimation, value: isOpen)
    }

    private var rowOffset: CGFloat {
        let baseOffset = (canDelete && isOpen) ? -actionRevealWidth : 0
        let proposedOffset = baseOffset + dragTranslation
        return min(0, max(-actionRevealWidth, proposedOffset))
    }

    private var actionOffset: CGFloat {
        // Keep the action attached to the swipe progress so it slides in with the row.
        actionRevealWidth + rowOffset
    }

    private var swipeProgress: CGFloat {
        min(1, max(0, -rowOffset / actionRevealWidth))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let baseOffset = (canDelete && isOpen) ? -actionRevealWidth : 0
                let projected = baseOffset + value.predictedEndTranslation.width
                let shouldOpen = projected < -actionRevealWidth * 0.45

                withAnimation(settleAnimation) {
                    dragTranslation = 0
                    if shouldOpen {
                        onOpen()
                    } else {
                        onClose()
                    }
                }
            }
    }
}

private struct BouncyPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
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
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(UIAssetFloatingActionButtonStyle())

                        Text(exercise.name)
                            .uiAssetText(.h2)
                            .foregroundStyle(UIAssetColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Edit") {
                            isEditPresented = true
                        }
                        .buttonStyle(UIAssetTextActionButtonStyle())
                    }

                    mediaSection

                    VStack(alignment: .leading, spacing: 10) {
                        if let targetArea = exercise.targetArea,
                           !targetArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Target area: \(targetArea)")
                                .uiAssetText(.subtitle)
                                .foregroundStyle(UIAssetColors.textSecondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                UIAssetBadge(
                                    text: "Category: \(exercise.category?.displayName ?? "Uncategorized")",
                                    variant: .neutral
                                )
                                UIAssetBadge(
                                    text: "Type: \(exercise.type.displayName)",
                                    variant: .accent
                                )
                                if exercise.source == .user {
                                    UIAssetBadge(text: "User", variant: .accent)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .uiAssetCardSurface(fill: UIAssetColors.primary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("How To Do")
                            .uiAssetText(.h4)
                            .foregroundStyle(UIAssetColors.textPrimary)

                        if instructionLines.isEmpty {
                            Text("No instructions available yet.")
                                .uiAssetText(.paragraph)
                                .foregroundStyle(UIAssetColors.textSecondary)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(instructionLines.enumerated()), id: \.offset) { _, line in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .uiAssetText(.paragraph)
                                            .foregroundStyle(UIAssetColors.accent)
                                        Text(line)
                                            .uiAssetText(.paragraph)
                                            .foregroundStyle(UIAssetColors.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .uiAssetCardSurface(fill: UIAssetColors.primary)

                    if exercise.source != .seeded {
                        Button("Delete Exercise") {
                            isDeleteConfirmationPresented = true
                        }
                        .buttonStyle(UIAssetButtonStyle(variant: .destructive))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(UIAssetColors.secondary.ignoresSafeArea())
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

            if let errorMessage {
                dialogBackdrop {
                    UIAssetAlertDialog(
                        title: "Exercise Error",
                        message: errorMessage,
                        cancelTitle: "Close",
                        destructiveTitle: "OK"
                    ) {
                        self.errorMessage = nil
                    } onDestructive: {
                        self.errorMessage = nil
                    }
                    .padding(.horizontal, 16)
                }
            } else if isDeleteConfirmationPresented {
                dialogBackdrop {
                    UIAssetAlertDialog(
                        title: "Delete Exercise",
                        message: "Are you sure you want to delete this exercise?",
                        cancelTitle: "Cancel",
                        destructiveTitle: "Delete"
                    ) {
                        isDeleteConfirmationPresented = false
                    } onDestructive: {
                        isDeleteConfirmationPresented = false
                        Task {
                            await deleteExercise()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        if let mediaURI = exercise.mediaURI,
           let url = Self.resolvedMediaURL(from: mediaURI) {
            GIFWebView(url: url)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                        .stroke(UIAssetColors.border, lineWidth: 1)
                )
                .background(UIAssetColors.primary)
        } else {
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                .fill(UIAssetColors.accentSecondary)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    Text("No GIF available")
                        .uiAssetText(.subtitle)
                        .foregroundStyle(UIAssetColors.textSecondary)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                        .stroke(UIAssetColors.border, lineWidth: 1)
                )
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

    private func dialogBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.24))
                .ignoresSafeArea()

            content()
        }
        .transition(.opacity)
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
