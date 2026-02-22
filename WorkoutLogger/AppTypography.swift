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
        .custom(
            AppTypography.fontFamilyName,
            size: AppTypography.baseSize(for: style),
            relativeTo: style
        )
        .weight(defaultWeight(for: style))
    }

    private static func defaultWeight(for style: Font.TextStyle) -> Font.Weight {
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
}
