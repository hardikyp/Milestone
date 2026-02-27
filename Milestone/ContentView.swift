import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    private let menuReservedHeight: CGFloat = 86

    var body: some View {
        ZStack(alignment: .bottom) {
            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, menuReservedHeight)

            MinimalBottomMenu(selectedTab: $container.selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(UIAssetColors.secondary.ignoresSafeArea())
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch container.selectedTab {
        case .home:
            DashboardView()
        case .history:
            HistoryView()
        case .exercises:
            ExercisesView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(
            AppContainer(databaseManager: try! DatabaseManager())
        )
}

private struct MinimalBottomMenu: View {
    @Binding var selectedTab: AppTab
    private let cornerRadius: CGFloat = 0
    private let iconFrameHeight: CGFloat = 24

    private struct MenuItem: Identifiable {
        let id: AppTab
        let title: String
        let systemImage: String
    }

    private let items: [MenuItem] = [
        MenuItem(id: .home, title: "Home", systemImage: "house"),
        MenuItem(id: .history, title: "History", systemImage: "clock.arrow.circlepath"),
        MenuItem(id: .exercises, title: "Exercises", systemImage: "figure.strengthtraining.traditional.circle"),
        MenuItem(id: .settings, title: "Settings", systemImage: "gear")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = selectedTab == item.id

                Button {
                    selectedTab = item.id
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.systemImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: iconFrameHeight)
                            .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                            .fontWeight(isSelected ? .semibold : .regular)
                        Text(item.title)
                            .font(.app(.caption))
                            .fontWeight(isSelected ? .semibold : .regular)
                    }
                    .foregroundStyle(isSelected ? Color(red: 0.17, green: 0.38, blue: 0.09) : Color.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .contentShape(Rectangle())
                }
                .frame(height: 70)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}
