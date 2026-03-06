import SwiftUI
import UIKit
import CoreText

enum AppTypography {
    static let fontFamilyName = "Inter"
    private static let bundleFontFileName = "Inter-VariableFont_opsz,wght"

    static func configure() {
        registerInterIfNeeded()

        let titleFont = uiFont(forTextStyle: .headline, weight: .bold)
        let largeTitleFont = uiFont(forTextStyle: .largeTitle, weight: .heavy)

        UINavigationBar.appearance().titleTextAttributes = [.font: titleFont]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitleFont]
    }

    static func uiFont(forTextStyle style: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let pointSize = UIFont.preferredFont(forTextStyle: style).pointSize

        if let inter = UIFont(name: fontFamilyName, size: pointSize) {
            let descriptor = inter.fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight]
            ])
            let weighted = UIFont(descriptor: descriptor, size: pointSize)
            return UIFontMetrics(forTextStyle: style).scaledFont(for: weighted)
        }

        return UIFont.systemFont(ofSize: pointSize, weight: weight)
    }

    static func uiFont(
        pointSize: CGFloat,
        relativeTo style: UIFont.TextStyle = .body,
        weight: UIFont.Weight = .regular
    ) -> UIFont {
        if let inter = UIFont(name: fontFamilyName, size: pointSize) {
            let descriptor = inter.fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight]
            ])
            let weighted = UIFont(descriptor: descriptor, size: pointSize)
            return UIFontMetrics(forTextStyle: style).scaledFont(for: weighted)
        }

        return UIFont.systemFont(ofSize: pointSize, weight: weight)
    }

    static func baseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .body: return 17
        case .callout: return 16
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }

    static func font(for style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let resolvedWeight = weight ?? defaultFontWeight(for: style)
        let uiStyle = uiTextStyle(for: style)
        let uiWeight = uiFontWeight(for: resolvedWeight)
        return Font(uiFont(forTextStyle: uiStyle, weight: uiWeight))
    }

    static func font(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        let uiStyle = uiTextStyle(for: style)
        let uiWeight = uiFontWeight(for: weight)
        return Font(uiFont(pointSize: size, relativeTo: uiStyle, weight: uiWeight))
    }

    private static func uiTextStyle(for style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }

    private static func uiFontWeight(for weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func defaultFontWeight(for style: Font.TextStyle) -> Font.Weight {
        switch style {
        case .largeTitle:
            return .heavy
        case .title, .title2, .title3:
            return .bold
        case .headline:
            return .semibold
        default:
            return .regular
        }
    }

    private static func registerInterIfNeeded() {
        guard UIFont(name: fontFamilyName, size: 14) == nil else { return }

        if let url = Bundle.main.url(forResource: bundleFontFileName, withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            return
        }

        #if DEBUG
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fonts")
            .appendingPathComponent("\(bundleFontFileName).ttf")
        if FileManager.default.fileExists(atPath: sourcePath.path) {
            CTFontManagerRegisterFontsForURL(sourcePath as CFURL, .process, nil)
        }
        #endif
    }
}

extension Font {
    static func app(_ style: Font.TextStyle) -> Font {
        AppTypography.font(for: style)
    }

    static func app(_ style: Font.TextStyle, weight: Font.Weight) -> Font {
        AppTypography.font(for: style, weight: weight)
    }
}
