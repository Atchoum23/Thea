import SwiftUI

extension Font {
    
    // MARK: - Helper to Convert Weight String
    
    private static func weight(from string: String) -> Font.Weight {
        switch string.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
    
    // MARK: - Configurable Fonts (MainActor required)
    
    @MainActor
    static var theaDisplay: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(
            size: config.displaySize,
            weight: weight(from: config.displayWeight),
            design: config.useRoundedDesign ? .rounded : .default
        )
    }
    
    @MainActor
    static var theaTitle1: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(
            size: config.title1Size,
            weight: weight(from: config.title1Weight),
            design: config.useRoundedDesign ? .rounded : .default
        )
    }
    
    @MainActor
    static var theaTitle2: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(
            size: config.title2Size,
            weight: weight(from: config.title2Weight),
            design: config.useRoundedDesign ? .rounded : .default
        )
    }
    
    @MainActor
    static var theaTitle3: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(
            size: config.title3Size,
            weight: weight(from: config.title3Weight),
            design: .default
        )
    }
    
    @MainActor
    static var theaHeadline: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(
            size: config.headlineSize,
            weight: weight(from: config.headlineWeight)
        )
    }
    
    @MainActor
    static var theaBody: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(
            size: config.bodySize,
            weight: weight(from: config.bodyWeight)
        )
    }
    
    @MainActor
    static var theaCallout: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(size: config.calloutSize, weight: .regular)
    }
    
    @MainActor
    static var theaSubhead: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(size: config.subheadSize, weight: .regular)
    }
    
    @MainActor
    static var theaFootnote: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(size: config.footnoteSize, weight: .regular)
    }
    
    @MainActor
    static var theaCaption1: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(size: config.caption1Size, weight: .regular)
    }
    
    @MainActor
    static var theaCaption2: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(size: config.caption2Size, weight: .regular)
    }
    
    @MainActor
    static var theaCode: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(size: config.codeSize, weight: .regular, design: .monospaced)
    }
    
    @MainActor
    static var theaCodeInline: Font {
        let config = AppConfiguration.shared.themeConfig
        return Font.system(size: config.codeInlineSize, weight: .regular, design: .monospaced)
    }
    
    // MARK: - Static Defaults (for non-MainActor contexts)
    
    static let theaDisplayDefault = Font.system(size: 34, weight: .bold, design: .rounded)
    static let theaTitle1Default = Font.system(size: 28, weight: .bold, design: .rounded)
    static let theaTitle2Default = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let theaTitle3Default = Font.system(size: 20, weight: .semibold)
    static let theaHeadlineDefault = Font.system(size: 17, weight: .semibold)
    static let theaBodyDefault = Font.system(size: 17, weight: .regular)
    static let theaCalloutDefault = Font.system(size: 16, weight: .regular)
    static let theaSubheadDefault = Font.system(size: 15, weight: .regular)
    static let theaFootnoteDefault = Font.system(size: 13, weight: .regular)
    static let theaCaption1Default = Font.system(size: 12, weight: .regular)
    static let theaCaption2Default = Font.system(size: 11, weight: .regular)
    static let theaCodeDefault = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let theaCodeInlineDefault = Font.system(size: 16, weight: .regular, design: .monospaced)
}
