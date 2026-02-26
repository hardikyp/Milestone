import SwiftUI

struct CategoryPickerView: View {
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let categories = [
        "Push",
        "Pull",
        "Legs",
        "Core",
        "Cardio",
        "Custom/Mixed"
    ]

    var body: some View {
        NavigationStack {
            List(categories, id: \.self) { category in
                Button(category) {
                    onSelect(category)
                    dismiss()
                }
            }
            .scrollContentBackground(.hidden)
            .background(UIAssetColors.secondary.ignoresSafeArea())
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CategoryPickerView { _ in }
}
