import SwiftUI

struct CategoryPickerView: View {
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private struct CategoryOption: Identifiable {
        let id: String
        let name: String
        let systemImage: String
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let categories: [CategoryOption] = [
        .init(id: "push", name: "Push", systemImage: "figure.archery"),
        .init(id: "pull", name: "Pull", systemImage: "figure.indoor.rowing"),
        .init(id: "legs", name: "Legs", systemImage: "figure.strengthtraining.functional"),
        .init(id: "core", name: "Core", systemImage: "figure.core.training"),
        .init(id: "cardio", name: "Cardio", systemImage: "bolt.heart"),
        .init(id: "customMixed", name: "Custom/Mixed", systemImage: "square.grid.2x2.fill")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Text("Select Category")
                            .uiAssetText(.h2)
                            .foregroundStyle(UIAssetColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(UIAssetTextActionButtonStyle())
                    }
                    .padding(.bottom, 8)

                    Text("Choose a workout split")
                        .uiAssetText(.footnote)
                        .foregroundStyle(UIAssetColors.textSecondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(categories) { category in
                            UIAssetTiledButton(
                                systemImage: category.systemImage,
                                label: category.name,
                                description: "Workout",
                                variant: .secondary,
                                customBackgroundColor: UIAssetColors.primary,
                                customIconColor: UIAssetColors.accent,
                                customLabelColor: UIAssetColors.textPrimary,
                                customDescriptionColor: UIAssetColors.textSecondary
                            ) {
                                onSelect(category.name)
                                dismiss()
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
        }
    }
}

#Preview {
    CategoryPickerView { _ in }
}
