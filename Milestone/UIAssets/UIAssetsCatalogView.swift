import SwiftUI
import UIKit

enum UIAssetColors {
    static let primary = Color.white
    static let secondary = Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)
    static let accent = Color(red: 6 / 255, green: 57 / 255, blue: 47 / 255)
    static let accentSecondary = Color(red: 224 / 255, green: 234 / 255, blue: 231 / 255)

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let background = secondary
    static let surface = primary
    static let border = Color.black.opacity(0.08)
}

enum UIAssetMetrics {
    // Update this value to change rounded corners across UI assets.
    static let cornerRadius: CGFloat = 16
    static let rowCardHeight: CGFloat = 76
}

enum UIAssetInlineDropdownExpansionDirection {
    case up
    case down
}

enum UIAssetInlineDropdownPanelAlignment {
    case leading
    case trailing
}

struct UIAssetInlineDropdownOverlayItem {
    let id: String
    let triggerFrame: CGRect
    let options: [String]
    let selected: Binding<String>
    let isExpanded: Binding<Bool>
    let panelWidth: CGFloat
    let textStyle: UIAssetTextStyle
    let expansionDirection: UIAssetInlineDropdownExpansionDirection
    let panelAlignment: UIAssetInlineDropdownPanelAlignment
}

private struct UIAssetInlineDropdownOverlayKey: EnvironmentKey {
    static var defaultValue: Binding<UIAssetInlineDropdownOverlayItem?>?
}

extension EnvironmentValues {
    var uiAssetInlineDropdownOverlay: Binding<UIAssetInlineDropdownOverlayItem?>? {
        get { self[UIAssetInlineDropdownOverlayKey.self] }
        set { self[UIAssetInlineDropdownOverlayKey.self] = newValue }
    }
}

private let uiAssetInlineDropdownHostCoordinateSpace = "uiAsset.inlineDropdownHost"

struct UIAssetInlineDropdownHost<Content: View>: View {
    @State private var overlayItem: UIAssetInlineDropdownOverlayItem?
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                content
                    .environment(\.uiAssetInlineDropdownOverlay, $overlayItem)
                    .coordinateSpace(name: uiAssetInlineDropdownHostCoordinateSpace)

                if let overlayItem {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            overlayItem.isExpanded.wrappedValue = false
                        }

                    panel(for: overlayItem)
                        .frame(width: overlayItem.panelWidth, alignment: .leading)
                        .position(
                            x: panelCenterX(for: overlayItem, containerWidth: proxy.size.width),
                            y: panelCenterY(for: overlayItem, containerHeight: proxy.size.height)
                        )
                }
            }
        }
    }

    private func panel(for item: UIAssetInlineDropdownOverlayItem) -> some View {
        VStack(spacing: 0) {
            ForEach(item.options, id: \.self) { option in
                Button {
                    item.selected.wrappedValue = option
                    item.isExpanded.wrappedValue = false
                } label: {
                    HStack(spacing: 8) {
                        Text(option)
                            .uiAssetText(item.textStyle)
                            .foregroundStyle(UIAssetColors.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 0)
                        if option == item.selected.wrappedValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(UIAssetColors.accent)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if option != item.options.last {
                    Divider()
                }
            }
        }
        .background(Color.white)
        .clipShape(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                .stroke(UIAssetColors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
    }

    private func panelHeight(for item: UIAssetInlineDropdownOverlayItem) -> CGFloat {
        CGFloat(item.options.count * 40) + CGFloat(max(0, item.options.count - 1))
    }

    private func panelCenterX(for item: UIAssetInlineDropdownOverlayItem, containerWidth: CGFloat) -> CGFloat {
        let halfPanel = item.panelWidth / 2
        let rawCenter: CGFloat

        switch item.panelAlignment {
        case .leading:
            rawCenter = item.triggerFrame.minX + halfPanel
        case .trailing:
            rawCenter = item.triggerFrame.maxX - halfPanel
        }

        return min(max(rawCenter, halfPanel + 8), containerWidth - halfPanel - 8)
    }

    private func panelCenterY(for item: UIAssetInlineDropdownOverlayItem, containerHeight: CGFloat) -> CGFloat {
        let halfPanel = panelHeight(for: item) / 2
        let rawCenter: CGFloat

        switch item.expansionDirection {
        case .down:
            rawCenter = item.triggerFrame.maxY + halfPanel + 4
        case .up:
            rawCenter = item.triggerFrame.minY - halfPanel - 4
        }

        return min(max(rawCenter, halfPanel + 8), containerHeight - halfPanel - 8)
    }
}

enum UIAssetTextStyle: String, CaseIterable, Identifiable {
    case h1 = "H1 Heading"
    case h2 = "H2 Heading"
    case h3 = "H3 Heading"
    case h4 = "H4 Heading"
    case h5 = "H5 Heading"
    case h6 = "H6 Heading"
    case paragraph = "Paragraph"
    case subtitle = "Subtitle"
    case footnote = "Footnote"
    case caption = "Caption"

    var id: String { rawValue }

    var font: Font {
        switch self {
        case .h1:
            return .app(.largeTitle).weight(.heavy)
        case .h2:
            return .app(.title).weight(.bold)
        case .h3:
            return .app(.title2).weight(.bold)
        case .h4:
            return .app(.title3).weight(.bold)
        case .h5:
            return .app(.headline).weight(.semibold)
        case .h6:
            return .app(.subheadline).weight(.semibold)
        case .paragraph:
            return .app(.body)
        case .subtitle:
            return .app(.subheadline)
        case .footnote:
            return .app(.footnote)
        case .caption:
            return .app(.caption)
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .h1, .h2, .h3:
            return 2
        case .paragraph:
            return 3
        default:
            return 1
        }
    }
}

extension View {
    func uiAssetText(_ style: UIAssetTextStyle) -> some View {
        self.font(style.font).lineSpacing(style.lineSpacing)
    }

    func uiAssetCardSurface(fill: Color) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .stroke(UIAssetColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

enum UIAssetButtonVariant: String, CaseIterable, Identifiable {
    case primary
    case secondary
    case destructive

    var id: String { rawValue }
}

private enum UIAssetButtonPalette {
    static let deepRed = Color(red: 225/255, green: 0, blue: 0)
}

struct UIAssetButtonStyle: ButtonStyle {
    let variant: UIAssetButtonVariant
    var symbolOnly = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.headline))
            .foregroundStyle(foregroundColor)
            .frame(minWidth: symbolOnly ? 44 : nil)
            .frame(maxWidth: symbolOnly ? 44 : .infinity)
            .frame(height: 44)
            .padding(.horizontal, symbolOnly ? 0 : 14)
            .background(backgroundShape(configuration: configuration))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return symbolOnly ? .black : UIAssetColors.accent
        case .destructive:
            return symbolOnly ? .white : UIAssetButtonPalette.deepRed
        }
    }

    @ViewBuilder
    private func backgroundShape(configuration: Configuration) -> some View {
        let fillOpacity = configuration.isPressed ? 0.9 : 1

        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                .fill(UIAssetColors.accent.opacity(fillOpacity))
        case .secondary:
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                .fill(UIAssetColors.accentSecondary.opacity(1))
                .overlay(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                        .stroke(UIAssetColors.accent.opacity(0.25), lineWidth: 1)
                )
        case .destructive:
            if symbolOnly {
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .fill(UIAssetButtonPalette.deepRed.opacity(fillOpacity))
            } else {
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .fill(UIAssetButtonPalette.deepRed.opacity(0.2 * fillOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .stroke(UIAssetButtonPalette.deepRed.opacity(0.5), lineWidth: 1)
                    )
            }
        }
    }
}

struct UIAssetSlidingToggle: View {
    let title: String
    @Binding var isOn: Bool
    private let trackWidth: CGFloat = 56
    private let trackHeight: CGFloat = 34
    private let knobSize: CGFloat = 30
    private let offTrackColor = Color(red: 0.88, green: 0.88, blue: 0.89)

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.1)) {
                    isOn.toggle()
                }
            } label: {
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(isOn ? UIAssetColors.accent : offTrackColor)
                        .frame(width: trackWidth, height: trackHeight)

                    Circle()
                        .fill(Color.white)
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                        .offset(x: isOn ? trackWidth - knobSize - 2 : 2)
                }
            }
            .buttonStyle(.plain)

            Text(title)
                .uiAssetText(.h4)
                .foregroundStyle(UIAssetColors.textPrimary)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
    }
}

struct UIAssetRadioCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    private let unselectedRadioColor = Color(red: 0.72, green: 0.72, blue: 0.74)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? UIAssetColors.accent : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? UIAssetColors.accent : unselectedRadioColor, lineWidth: 2)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .uiAssetText(.subtitle)
                        .foregroundStyle(UIAssetColors.textPrimary)
                    Text(subtitle)
                        .uiAssetText(.footnote)
                        .foregroundStyle(UIAssetColors.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(minHeight: UIAssetMetrics.rowCardHeight)
            .uiAssetCardSurface(fill: isSelected ? UIAssetColors.accentSecondary : UIAssetColors.surface)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct UIAssetCheckboxCard: View {
    let title: String
    let isChecked: Bool
    let onTap: () -> Void

    private let uncheckedColor = Color(red: 0.72, green: 0.72, blue: 0.74)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isChecked ? UIAssetColors.accent : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(isChecked ? UIAssetColors.accent : uncheckedColor, lineWidth: 2)
                        )

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(title)
                    .uiAssetText(.paragraph)
                    .foregroundStyle(UIAssetColors.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(minHeight: UIAssetMetrics.rowCardHeight)
            .uiAssetCardSurface(fill: isChecked ? UIAssetColors.accentSecondary : UIAssetColors.surface)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isChecked)
    }
}

struct UIAssetRowSlideActionButton: View {
    let systemName: String
    let title: String
    let iconColor: Color
    let backgroundColor: Color
    let borderColor: Color
    var height: CGFloat = UIAssetMetrics.rowCardHeight

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(iconColor)

            Text(title)
                .font(.app(.caption))
                .foregroundStyle(iconColor)
        }
        .frame(width: 56, height: height)
        .background(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

enum UIAssetBadgeVariant {
    case accent
    case neutral
}

enum UIAssetTiledButtonVariant {
    case primary
    case secondary
}

struct UIAssetTiledButton: View {
    let systemImage: String
    let title: String
    let variant: UIAssetTiledButtonVariant
    let onTap: () -> Void

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return UIAssetColors.accent
        case .secondary:
            return UIAssetColors.accentSecondary
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return UIAssetColors.accent
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .symbolRenderingMode(.monochrome)

                Text(title)
                    .uiAssetText(.paragraph)
                    .foregroundStyle(foregroundColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                    .stroke(
                        variant == .secondary ? UIAssetColors.accent.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .aspectRatio(5 / 4, contentMode: .fit)
    }
}

struct UIAssetBadge: View {
    let text: String
    let variant: UIAssetBadgeVariant

    private var dotColor: Color {
        switch variant {
        case .accent:
            return UIAssetColors.accent
        case .neutral:
            return UIAssetColors.accent.opacity(0.8)
        }
    }

    private var textColor: Color {
        switch variant {
        case .accent:
            return UIAssetColors.accent
        case .neutral:
            return UIAssetColors.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .accent:
            return UIAssetColors.accentSecondary.opacity(0.35)
        case .neutral:
            return UIAssetColors.surface
        }
    }

    private var borderColor: Color {
        switch variant {
        case .accent:
            return UIAssetColors.accentSecondary
        case .neutral:
            return UIAssetColors.border.opacity(1.6)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            Text(text)
                .uiAssetText(.caption)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 10)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.75, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.75, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

struct UIAssetFloatingActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(UIAssetColors.accent)
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(
                .interpolatingSpring(stiffness: 320, damping: 14),
                value: configuration.isPressed
            )
    }
}

struct UIAssetTextActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .uiAssetText(.subtitle)
            .foregroundStyle(.white)
            .frame(height: 36)
            .padding(.horizontal, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(UIAssetColors.accent)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(
                .interpolatingSpring(stiffness: 320, damping: 16),
                value: configuration.isPressed
            )
    }
}

struct UIAssetAlertDialog: View {
    let title: String
    let message: String
    let cancelTitle: String
    let destructiveTitle: String
    let onCancel: () -> Void
    let onDestructive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .uiAssetText(.h3)
                .foregroundStyle(UIAssetColors.textPrimary)

            Text(message)
                .uiAssetText(.paragraph)
                .foregroundStyle(UIAssetColors.textSecondary)

            HStack(spacing: 14) {
                Button(cancelTitle, action: onCancel)
                    .buttonStyle(UIAssetButtonStyle(variant: .secondary))
                    .frame(maxWidth: .infinity)

                Button(destructiveTitle, action: onDestructive)
                    .buttonStyle(UIAssetButtonStyle(variant: .destructive))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .uiAssetCardSurface(fill: UIAssetColors.primary)
    }
}

private struct UIAssetAlertDialogOverlayPreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                .fill(UIAssetColors.surface)
                .frame(height: 240)
                .overlay(
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Background Content")
                            .uiAssetText(.h4)
                        Text("This content is blurred and dimmed while the alert is active.")
                            .uiAssetText(.paragraph)
                    }
                    .foregroundStyle(UIAssetColors.textPrimary)
                    .padding(16),
                    alignment: .topLeading
                )
                .blur(radius: 3)

            Rectangle()
                .fill(Color.black.opacity(0.24))
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous))

            UIAssetAlertDialog(
                title: "Are you absolutely sure?",
                message: "This action cannot be undone. This will permanently delete your data.",
                cancelTitle: "Cancel",
                destructiveTitle: "Delete"
            ) {
            } onDestructive: {
            }
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
    }
}

struct UIAssetTabFilter: View {
    let tabs: [String]
    @Binding var selectedTab: String
    @Namespace private var underlineNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = selectedTab == tab

                Button {
                    withAnimation(.interpolatingSpring(stiffness: 260, damping: 22)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.app(.subheadline))
                            .foregroundStyle(isSelected ? UIAssetColors.accent : UIAssetColors.textSecondary)
                            .frame(maxWidth: .infinity)

                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(UIAssetColors.border)
                                .frame(height: 1)

                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(UIAssetColors.accent)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "tabFilterUnderline", in: underlineNamespace)
                            }
                        }
                        .frame(height: 3)
                    }
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct UIAssetTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .uiAssetText(.caption)
                .foregroundStyle(UIAssetColors.textSecondary)

            TextField(placeholder, text: $text)
                .font(.app(.body))
                .keyboardType(keyboardType)
                .padding(.horizontal, 12)
                .frame(height: 44)
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
}

struct UIAssetSelectOption: Identifiable, Hashable {
    let id: String
    let name: String
    let handle: String

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

struct UIAssetSelectField: View {
    let title: String
    let hint: String
    let placeholder: String
    let options: [UIAssetSelectOption]
    @Binding var selected: UIAssetSelectOption?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hint)
                .uiAssetText(.footnote)
                .foregroundStyle(UIAssetColors.textSecondary)

            Text(title)
                .uiAssetText(.caption)
                .foregroundStyle(UIAssetColors.textPrimary)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    if let selected {
                        avatar(for: selected)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.name)
                                .uiAssetText(.subtitle)
                                .foregroundStyle(UIAssetColors.textPrimary)
                            Text("@\(selected.handle)")
                                .uiAssetText(.footnote)
                                .foregroundStyle(UIAssetColors.textSecondary)
                        }
                    } else {
                        Text(placeholder)
                            .uiAssetText(.subtitle)
                            .foregroundStyle(UIAssetColors.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UIAssetColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                        .fill(UIAssetColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                        .stroke(isExpanded ? UIAssetColors.accent.opacity(0.45) : UIAssetColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) {
                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(options) { option in
                            Button {
                                selected = option
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    isExpanded = false
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    avatar(for: option)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.name)
                                            .uiAssetText(.subtitle)
                                            .foregroundStyle(UIAssetColors.textPrimary)
                                        Text("@\(option.handle)")
                                            .uiAssetText(.footnote)
                                            .foregroundStyle(UIAssetColors.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                    if selected?.id == option.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(UIAssetColors.accent)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if option.id != options.last?.id {
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .fill(UIAssetColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .stroke(UIAssetColors.border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .offset(y: 50)
                    .zIndex(200)
                }
            }
        }
        .zIndex(isExpanded ? 200 : 0)
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    private func avatar(for option: UIAssetSelectOption) -> some View {
        Circle()
            .fill(UIAssetColors.accentSecondary)
            .frame(width: 24, height: 24)
            .overlay(
                Text(option.initials)
                    .font(.app(.caption).weight(.semibold))
                    .foregroundStyle(UIAssetColors.accent)
            )
    }
}

struct UIAssetSettingsInlineToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82, blendDuration: 0.1)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? UIAssetColors.accent : Color(red: 0.88, green: 0.88, blue: 0.89))
                    .frame(width: 46, height: 28)

                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
                    .offset(x: isOn ? 20 : 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct UIAssetSettingsInlineDropdown: View {
    typealias ExpansionDirection = UIAssetInlineDropdownExpansionDirection
    typealias PanelAlignment = UIAssetInlineDropdownPanelAlignment

    let options: [String]
    @Binding var selected: String
    var id: String? = nil
    var activeDropdownID: Binding<String?>? = nil
    var expansionDirection: ExpansionDirection = .down
    var panelAlignment: PanelAlignment = .trailing
    var panelWidth: CGFloat = 86
    var textStyle: UIAssetTextStyle = .subtitle
    @Environment(\.uiAssetInlineDropdownOverlay) private var portalOverlay
    @State private var isExpandedLocal = false
    @State private var triggerFrame: CGRect = .zero
    @State private var localID = UUID().uuidString
    private let opaqueSurface = Color(red: 1, green: 1, blue: 1, opacity: 1)

    var body: some View {
        trigger
            .background(
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .named(uiAssetInlineDropdownHostCoordinateSpace))
                    Color.clear
                        .onAppear {
                            updateTriggerFrame(frame)
                        }
                        .onChange(of: frame) { _, newValue in
                            updateTriggerFrame(newValue)
                        }
                }
            )
            .overlay(alignment: overlayAlignment) {
                if isExpanded && !usesPortal {
                    panel
                        .offset(y: expansionDirection == .down ? 38 : -38)
                        .zIndex(200)
                        .allowsHitTesting(true)
                }
            }
            .zIndex(isExpanded ? 10_000 : 0)
            .animation(.easeInOut(duration: 0.18), value: isExpanded)
            .onChange(of: isExpanded) { _, newValue in
                syncPortalExpansion(newValue)
            }
            .onChange(of: triggerFrame) { _, _ in
                refreshPortalIfNeeded()
            }
            .onChange(of: options) { _, _ in
                refreshPortalIfNeeded()
            }
            .onChange(of: selected) { _, _ in
                refreshPortalIfNeeded()
            }
    }

    private var trigger: some View {
        HStack(spacing: 6) {
            Text(selected)
                .uiAssetText(textStyle)
                .foregroundStyle(UIAssetColors.textPrimary)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(UIAssetColors.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(opaqueSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                .stroke(isExpanded ? UIAssetColors.accent.opacity(0.45) : UIAssetColors.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous))
        .onTapGesture {
            toggle()
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    selected = option
                    close()
                } label: {
                    HStack(spacing: 8) {
                        Text(option)
                            .uiAssetText(textStyle)
                            .foregroundStyle(UIAssetColors.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 0)
                        if option == selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(UIAssetColors.accent)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                }
                .buttonStyle(.plain)

                if option != options.last {
                    Divider()
                }
            }
        }
        .frame(width: panelWidth, alignment: .leading)
        .background(opaqueSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                .stroke(UIAssetColors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var isExpanded: Bool {
        guard let activeDropdownID, let id else {
            return isExpandedLocal
        }
        return activeDropdownID.wrappedValue == id
    }

    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { isExpanded },
            set: { setExpanded($0) }
        )
    }

    private func toggle() {
        setExpanded(!isExpanded)
    }

    private func close() {
        setExpanded(false)
    }

    private func setExpanded(_ expanded: Bool) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if var activeDropdownID, let id {
                if expanded {
                    activeDropdownID.wrappedValue = id
                } else if activeDropdownID.wrappedValue == id {
                    activeDropdownID.wrappedValue = nil
                }
            } else {
                isExpandedLocal = expanded
            }
        }
    }

    private var resolvedID: String {
        id ?? localID
    }

    private var usesPortal: Bool {
        portalOverlay != nil
    }

    private func updateTriggerFrame(_ newFrame: CGRect) {
        triggerFrame = newFrame
    }

    private func syncPortalExpansion(_ expanded: Bool) {
        guard usesPortal else { return }
        if expanded {
            refreshPortalIfNeeded()
        } else {
            dismissPortalIfNeeded()
        }
    }

    private func refreshPortalIfNeeded() {
        guard usesPortal, isExpanded else { return }
        guard let portalOverlay else { return }

        portalOverlay.wrappedValue = UIAssetInlineDropdownOverlayItem(
            id: resolvedID,
            triggerFrame: triggerFrame,
            options: options,
            selected: $selected,
            isExpanded: isExpandedBinding,
            panelWidth: panelWidth,
            textStyle: textStyle,
            expansionDirection: expansionDirection,
            panelAlignment: panelAlignment
        )
    }

    private func dismissPortalIfNeeded() {
        guard let portalOverlay else { return }
        if portalOverlay.wrappedValue?.id == resolvedID {
            portalOverlay.wrappedValue = nil
        }
    }

    private var overlayAlignment: Alignment {
        switch (panelAlignment, expansionDirection) {
        case (.leading, .down):
            return .topLeading
        case (.leading, .up):
            return .bottomLeading
        case (.trailing, .down):
            return .topTrailing
        case (.trailing, .up):
            return .bottomTrailing
        }
    }
}

struct UIAssetSettingsRow<Accessory: View>: View {
    let symbol: String
    let title: String
    let showsDivider: Bool
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20.4, weight: .semibold))
                    .foregroundStyle(UIAssetColors.accent)
                    .frame(width: 24, height: 24)

                Text(title)
                    .uiAssetText(.subtitle)
                    .foregroundStyle(UIAssetColors.textPrimary)

                Spacer(minLength: 0)

                accessory()
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

            if showsDivider {
                Divider()
            }
        }
    }
}

struct UIAssetSettingsCategoryCard<Content: View>: View {
    let category: String
    var bottomPadding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .uiAssetText(.caption)
                .foregroundStyle(UIAssetColors.textSecondary)

            VStack(spacing: 0) {
                content()
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, bottomPadding)
        .uiAssetCardSurface(fill: UIAssetColors.primary)
    }
}

struct UIAssetsCatalogView: View {
    private enum ProfileField: Hashable {
        case first
        case last
    }

    @State private var isToggleOn = true
    @State private var searchText = ""
    @State private var notes = ""
    @State private var selectedTeamMember: UIAssetSelectOption?
    @State private var selectedRadioCard = "optionA"
    @State private var isCheckboxChecked = false
    @State private var selectedTabCategory = "Category 1"
    @State private var settingsReminderOn = true
    @State private var settingsWeightUnit = "kg"
    @State private var firstNameInput = ""
    @State private var lastNameInput = ""
    @FocusState private var focusedProfileField: ProfileField?
    private let teamMemberOptions: [UIAssetSelectOption] = [
        UIAssetSelectOption(id: "olivia", name: "Olivia Rhye", handle: "olivia"),
        UIAssetSelectOption(id: "phoenix", name: "Phoenix Baker", handle: "phoenix"),
        UIAssetSelectOption(id: "lana", name: "Lana Steiner", handle: "lana")
    ]

    var body: some View {
        UIAssetInlineDropdownHost {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("UI Assets")
                        .uiAssetText(.h2)

                    colorSection
                    typographySection
                    buttonSection
                    tiledButtonSection
                    badgeSection
                    actionButtonSection
                    cardSection
                    settingsSection
                    userProfileSection
                    alertDialogSection
                    controlSection
                }
                .padding(16)
            }
        }
        .background(UIAssetColors.background.ignoresSafeArea())
        .navigationTitle("UI Assets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Colors")
                .uiAssetText(.h4)

            HStack(spacing: 12) {
                colorChip(name: "Primary", color: UIAssetColors.primary)
                colorChip(name: "Secondary", color: UIAssetColors.secondary)
                colorChip(name: "Accent", color: UIAssetColors.accent)
                colorChip(name: "Accent Light", color: UIAssetColors.accentSecondary)
            }

            Text("Corner Radius: \(Int(UIAssetMetrics.cornerRadius))pt (edit in UIAssetMetrics.cornerRadius)")
                .uiAssetText(.footnote)
                .foregroundStyle(UIAssetColors.textSecondary)
        }
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Typography")
                .uiAssetText(.h4)

            ForEach(UIAssetTextStyle.allCases) { style in
                Text(style.rawValue)
                    .uiAssetText(style)
                    .foregroundStyle(UIAssetColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var buttonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buttons")
                .uiAssetText(.h4)

            Button("Primary Button") {}
                .buttonStyle(UIAssetButtonStyle(variant: .primary))

            Button("Secondary Button") {}
                .buttonStyle(UIAssetButtonStyle(variant: .secondary))

            Button("Delete Action") {}
                .buttonStyle(UIAssetButtonStyle(variant: .destructive))

            Text("Row Slide Actions")
                .uiAssetText(.h5)
                .foregroundStyle(UIAssetColors.textPrimary)

            HStack(spacing: 12) {
                Button {
                } label: {
                    UIAssetRowSlideActionButton(
                        systemName: "trash",
                        title: "Delete",
                        iconColor: .white,
                        backgroundColor: UIAssetButtonPalette.deepRed,
                        borderColor: UIAssetButtonPalette.deepRed.opacity(0.7)
                    )
                }
                .buttonStyle(.plain)

                Button {
                } label: {
                    UIAssetRowSlideActionButton(
                        systemName: "stop.fill",
                        title: "Stop",
                        iconColor: UIAssetColors.accent,
                        backgroundColor: UIAssetColors.accentSecondary,
                        borderColor: UIAssetColors.accent.opacity(0.3)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tiledButtonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tiled Buttons")
                .uiAssetText(.h4)

            HStack(spacing: 12) {
                UIAssetTiledButton(
                    systemImage: "trash.fill",
                    title: "Delete",
                    variant: .primary
                ) {
                }
                .frame(maxWidth: .infinity)

                UIAssetTiledButton(
                    systemImage: "stop.fill",
                    title: "Stop",
                    variant: .secondary
                ) {
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .uiAssetText(.h4)

            HStack(spacing: 18) {
                UIAssetBadge(text: "Label", variant: .accent)
                UIAssetBadge(text: "Label", variant: .neutral)
            }
        }
    }

    private var cardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card")
                .uiAssetText(.h4)

            VStack(alignment: .leading, spacing: 8) {
                Text("H3 Placeholder Heading")
                    .uiAssetText(.h3)
                    .foregroundStyle(UIAssetColors.textPrimary)
                Text("Placeholder paragraph text for the card body. This area can hold supporting context, summary content, or other descriptive information.")
                    .uiAssetText(.paragraph)
                    .foregroundStyle(UIAssetColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .uiAssetCardSurface(fill: UIAssetColors.primary)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings Section")
                .uiAssetText(.h4)

            UIAssetSettingsCategoryCard(category: "Preferences") {
                UIAssetSettingsRow(symbol: "person.crop.circle", title: "Profile", showsDivider: true) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UIAssetColors.textSecondary)
                }

                UIAssetSettingsRow(symbol: "bell.badge", title: "Reminders", showsDivider: true) {
                    UIAssetSettingsInlineToggle(isOn: $settingsReminderOn)
                }

                UIAssetSettingsRow(symbol: "scalemass", title: "Weight Unit", showsDivider: false) {
                    UIAssetSettingsInlineDropdown(
                        options: ["kg", "lb"],
                        selected: $settingsWeightUnit
                    )
                }
            }
        }
    }

    private var userProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("User Profile Info")
                .uiAssetText(.h4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Name")
                    .uiAssetText(.caption)
                    .foregroundStyle(UIAssetColors.textSecondary)

                HStack(spacing: 10) {
                    profileNameInput(
                        placeholder: "First",
                        text: $firstNameInput,
                        field: .first
                    )
                    profileNameInput(
                        placeholder: "Last",
                        text: $lastNameInput,
                        field: .last
                    )
                }
            }
            .padding(16)
            .uiAssetCardSurface(fill: UIAssetColors.primary)

            VStack(alignment: .leading, spacing: 16) {
                Text("Profile Picture")
                    .uiAssetText(.caption)
                    .foregroundStyle(UIAssetColors.textSecondary)

                VStack(spacing: 12) {
                    Circle()
                        .fill(UIAssetColors.accentSecondary.opacity(0.5))
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 38, weight: .regular))
                                .foregroundStyle(UIAssetColors.accent)
                        )

                    Button("Choose image") {
                    }
                    .buttonStyle(UIAssetButtonStyle(variant: .secondary))
                    .frame(maxWidth: 180)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .uiAssetCardSurface(fill: UIAssetColors.primary)
        }
    }

    private func profileNameInput(
        placeholder: String,
        text: Binding<String>,
        field: ProfileField
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.app(.body))
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                    .fill(UIAssetColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius * 0.6, style: .continuous)
                    .stroke(
                        focusedProfileField == field
                        ? UIAssetColors.accent.opacity(0.7)
                        : UIAssetColors.border.opacity(1.6),
                        lineWidth: 1
                    )
            )
            .focused($focusedProfileField, equals: field)
    }

    private var alertDialogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alert Dialog")
                .uiAssetText(.h4)

            UIAssetAlertDialogOverlayPreview()
        }
    }

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .uiAssetText(.h4)

            UIAssetSlidingToggle(title: "Remember me", isOn: $isToggleOn)

            UIAssetTextField(title: "Input", placeholder: "Exercise name", text: $searchText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .uiAssetText(.caption)
                    .foregroundStyle(UIAssetColors.textSecondary)
                TextEditor(text: $notes)
                    .font(.app(.body))
                    .frame(minHeight: 92)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .fill(UIAssetColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                            .stroke(UIAssetColors.border, lineWidth: 1)
                    )
            }

            Text("Dropdown")
                .uiAssetText(.h5)
                .foregroundStyle(UIAssetColors.textPrimary)

            UIAssetSelectField(
                title: "Team member*",
                hint: "This is a hint text to help user.",
                placeholder: "Select team member",
                options: teamMemberOptions,
                selected: $selectedTeamMember
            )

            Text("Tab Filter")
                .uiAssetText(.h5)
                .foregroundStyle(UIAssetColors.textPrimary)

            UIAssetTabFilter(
                tabs: ["Category 1", "Category 2", "Category 3"],
                selectedTab: $selectedTabCategory
            )

            Text("Radio Button")
                .uiAssetText(.h5)
                .foregroundStyle(UIAssetColors.textPrimary)

            UIAssetRadioCard(
                title: "Standard Plan",
                subtitle: "Balanced training split",
                isSelected: selectedRadioCard == "optionA"
            ) {
                selectedRadioCard = "optionA"
            }

            UIAssetRadioCard(
                title: "Performance Plan",
                subtitle: "Higher intensity focus",
                isSelected: selectedRadioCard == "optionB"
            ) {
                selectedRadioCard = "optionB"
            }

            Text("Checkbox")
                .uiAssetText(.h5)
                .foregroundStyle(UIAssetColors.textPrimary)

            UIAssetCheckboxCard(
                title: "Mark done",
                isChecked: isCheckboxChecked
            ) {
                isCheckboxChecked.toggle()
            }
        }
    }

    private var actionButtonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Action Buttons")
                .uiAssetText(.h4)

            HStack(spacing: 14) {
                Button {
                } label: {
                    actionButtonIcon("chevron.left")
                }
                .buttonStyle(UIAssetFloatingActionButtonStyle())

                Button {
                } label: {
                    actionButtonIcon("trash")
                }
                .buttonStyle(UIAssetFloatingActionButtonStyle())

                Button {
                } label: {
                    actionButtonIcon("plus")
                }
                .buttonStyle(UIAssetFloatingActionButtonStyle())
            }
            .frame(width: 336, height: 36, alignment: .leading)

            HStack(spacing: 12) {
                Button("Back") {
                }
                .buttonStyle(UIAssetTextActionButtonStyle())

                Button("Add Exercise") {
                }
                .buttonStyle(UIAssetTextActionButtonStyle())
            }
            .frame(height: 36, alignment: .leading)
        }
    }

    private func actionButtonIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
    }

    private func colorChip(name: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: UIAssetMetrics.cornerRadius, style: .continuous)
                .fill(color)
                .frame(height: 60)
            Text(name)
                .uiAssetText(.footnote)
                .foregroundStyle(UIAssetColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        UIAssetsCatalogView()
    }
}
