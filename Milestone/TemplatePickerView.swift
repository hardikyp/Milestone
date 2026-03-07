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
    @State private var openSwipeTemplateID: String?

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
                        .padding(.bottom, 8)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pre-create target sets")
                                    .uiAssetText(.h3)
                                    .foregroundStyle(UIAssetColors.textPrimary)

                                Text("Auto-fill sets from template targets")
                                    .uiAssetText(.subtitle)
                                    .foregroundStyle(UIAssetColors.textSecondary)
                            }

                            Spacer(minLength: 0)

                            UIAssetSettingsInlineToggle(isOn: $precreateSets)
                        }
                        .padding(.bottom, 4)
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
                                description: "Empty Template",
                                variant: .secondary
                            ) {
                                creationSheet = .fromScratch
                            }
                        }
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pick a Template")
                                .uiAssetText(.h3)
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
                                    TemplateSwipeRow(
                                        isOpen: openSwipeTemplateID == template.id,
                                        onOpen: { openSwipeTemplateID = template.id },
                                        onClose: {
                                            if openSwipeTemplateID == template.id {
                                                openSwipeTemplateID = nil
                                            }
                                        },
                                        onTapRow: {
                                            if openSwipeTemplateID != nil {
                                                openSwipeTemplateID = nil
                                            } else {
                                                onStart(template.id, precreateSets)
                                                dismiss()
                                            }
                                        },
                                        onDelete: {
                                            Task {
                                                await viewModel.deleteTemplate(
                                                    id: template.id,
                                                    templateRepository: container.templateRepository
                                                )
                                                if openSwipeTemplateID == template.id {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        openSwipeTemplateID = nil
                                                    }
                                                }
                                            }
                                        }
                                    ) {
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(template.name)
                                                    .uiAssetText(.paragraphSemibold)
                                                    .foregroundStyle(UIAssetColors.textPrimary)
                                                if let description = template.description, !description.isEmpty {
                                                    Text(description)
                                                        .uiAssetText(.subtitle)
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

    func deleteTemplate(id: String, templateRepository: TemplateRepository) async {
        do {
            try templateRepository.deleteTemplate(templateId: id)
            templates.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TemplateSwipeRow<Content: View>: View {
    let isOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onTapRow: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragTranslation: CGFloat = 0
    @State private var measuredRowHeight: CGFloat = UIAssetMetrics.rowCardHeight

    private let actionGap: CGFloat = 8
    private let destructiveColor = Color(red: 225 / 255, green: 0, blue: 0)
    private let settleAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.82)
    private var actionWidth: CGFloat { measuredRowHeight }
    private var revealWidth: CGFloat { actionWidth + actionGap }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                VStack(spacing: 6) {
                    Image(systemName: "trash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    Text("Delete")
                        .font(UIAssetTextStyle.footnote.font)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                        .fill(destructiveColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                        .stroke(destructiveColor.opacity(0.7), lineWidth: 0)
                )
                .shadow(color: UIAssetShadows.soft, radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .frame(width: actionWidth, height: measuredRowHeight)
            .offset(x: actionOffset)
            .opacity(swipeProgress)
            .allowsHitTesting(swipeProgress > 0.02)

            content()
                .contentShape(Rectangle())
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                updateMeasuredRowHeight(proxy.size.height)
                            }
                            .onChange(of: proxy.size.height) { _, newHeight in
                                updateMeasuredRowHeight(newHeight)
                            }
                    }
                )
                .onTapGesture {
                    onTapRow()
                }
                .offset(x: rowOffset)
                .highPriorityGesture(dragGesture)
        }
        .animation(settleAnimation, value: isOpen)
    }

    private var rowOffset: CGFloat {
        let baseOffset = isOpen ? -revealWidth : 0
        let proposedOffset = baseOffset + dragTranslation
        return min(0, max(-revealWidth, proposedOffset))
    }

    private var actionOffset: CGFloat {
        revealWidth + rowOffset
    }

    private var swipeProgress: CGFloat {
        min(1, max(0, -rowOffset / revealWidth))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let baseOffset = isOpen ? -revealWidth : 0
                let projected = baseOffset + value.predictedEndTranslation.width
                let shouldOpen = projected < -revealWidth * 0.45

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

    private func updateMeasuredRowHeight(_ newHeight: CGFloat) {
        let resolvedHeight = max(newHeight, 1)
        if abs(resolvedHeight - measuredRowHeight) > 0.5 {
            measuredRowHeight = resolvedHeight
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
                        .padding(.bottom, 4)

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
                                placeholder: "Notes for this template",
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
            .dismissKeyboardOnBackgroundTap()
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
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func create(templateRepository: TemplateRepository) async {
        do {
            _ = try templateRepository.createTemplate(
                name: templateName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
