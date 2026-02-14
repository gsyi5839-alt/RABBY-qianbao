import SwiftUI

extension Font {
    // Rabby brand font mapping (using system fonts as replacement)
    static func rabbyTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func rabbyHeadline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
    static func rabbyBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }
    static func rabbyCaption(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }
    static func rabbyMono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    // Preset sizes
    static let rabbyLargeTitle = rabbyTitle(28)
    static let rabbyTitle1 = rabbyTitle(22)
    static let rabbyTitle2 = rabbyTitle(18)
    static let rabbyBody1 = rabbyBody(16)
    static let rabbyBody2 = rabbyBody(14)
    static let rabbyCaption1 = rabbyCaption(12)
    static let rabbyCaption2 = rabbyCaption(10)

    // Monospaced fonts for address/hash display
    static let rabbyAddress = rabbyMono(14)
    static let rabbyHash = rabbyMono(12)
}

// UIFont extension (UIKit compatibility)
extension UIFont {
    static func rabbyFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size, weight: weight)
    }
}
