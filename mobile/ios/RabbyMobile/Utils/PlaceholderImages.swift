//
//  PlaceholderImages.swift
//  RabbyMobile
//
//  Provides SF Symbol fallbacks and programmatic placeholder images
//  for use when actual image assets are not yet available in the
//  asset catalog. Each helper returns a SwiftUI Image or View that
//  can be dropped in as a direct replacement once real assets land.
//

import SwiftUI

// MARK: - Asset Catalog Names (namespaced)

/// Centralised image-name constants that match the asset catalog
/// entries in Images.xcassets. Using these constants avoids typos
/// and makes it easy to grep for usages when swapping placeholders
/// for real artwork.
enum AssetImage {

    // Brand
    static let rabbyLogo            = "Brand/rabby_logo"

    // Empty states
    static let emptyStateTokens     = "EmptyStates/empty_state_tokens"
    static let emptyStateNFT        = "EmptyStates/empty_state_nft"
    static let emptyStateHistory    = "EmptyStates/empty_state_history"
    static let emptyStateSearch     = "EmptyStates/empty_state_search"

    // Tab / action icons
    static let iconSwap             = "Icons/icon_swap"
    static let iconBridge           = "Icons/icon_bridge"
    static let iconSend             = "Icons/icon_send"
    static let iconReceive          = "Icons/icon_receive"

    // Navigation icons
    static let iconSettings         = "Icons/icon_settings"
    static let iconScan             = "Icons/icon_scan"
    static let iconWallet           = "Icons/icon_wallet"

    // Launch
    static let launchBackground     = "Launch/launch_background"
}

// MARK: - SF Symbol Fallbacks

/// Maps every asset-catalog name to an appropriate SF Symbol so the
/// UI is usable before designers deliver the final PNGs / PDFs.
enum PlaceholderSymbol {

    /// Returns the best-matching SF Symbol name for a given asset.
    static func sfSymbolName(for assetName: String) -> String {
        switch assetName {
        // Brand
        case AssetImage.rabbyLogo:
            return "hare.fill"

        // Empty states
        case AssetImage.emptyStateTokens:
            return "circle.dotted"
        case AssetImage.emptyStateNFT:
            return "photo.on.rectangle.angled"
        case AssetImage.emptyStateHistory:
            return "clock"
        case AssetImage.emptyStateSearch:
            return "magnifyingglass"

        // Tab / action icons
        case AssetImage.iconSwap:
            return "arrow.triangle.2.circlepath"
        case AssetImage.iconBridge:
            return "arrow.left.arrow.right"
        case AssetImage.iconSend:
            return "arrow.up.circle"
        case AssetImage.iconReceive:
            return "arrow.down.circle"

        // Navigation icons
        case AssetImage.iconSettings:
            return "gearshape"
        case AssetImage.iconScan:
            return "qrcode.viewfinder"
        case AssetImage.iconWallet:
            return "wallet.pass"

        // Launch
        case AssetImage.launchBackground:
            return "rectangle.fill"

        default:
            return "questionmark.square.dashed"
        }
    }
}

// MARK: - Rabby Brand Colors

/// Core brand colours for programmatic placeholders and gradients.
enum RabbyColor {
    static let primary      = Color(red: 0.49, green: 0.47, blue: 1.0)   // #7D78FF
    static let secondary    = Color(red: 0.53, green: 0.84, blue: 0.49)  // #88D67D
    static let background   = Color(red: 0.07, green: 0.07, blue: 0.11)  // #12121C
    static let surface      = Color(red: 0.11, green: 0.11, blue: 0.16)  // #1C1C29
    static let textPrimary  = Color.white
    static let textSecondary = Color(white: 0.6)
}

// MARK: - PlaceholderImage View

/// A SwiftUI view that first attempts to load the real asset from the
/// catalog; if the asset is missing (returns nil from UIImage) it
/// falls back to the matching SF Symbol rendered at the requested size.
///
/// Usage:
///
///     PlaceholderImage(AssetImage.iconSwap, size: 24)
///
struct PlaceholderImage: View {
    let assetName: String
    let size: CGFloat
    let tintColor: Color

    init(_ assetName: String, size: CGFloat = 24, tintColor: Color = RabbyColor.primary) {
        self.assetName = assetName
        self.size = size
        self.tintColor = tintColor
    }

    private var hasRealAsset: Bool {
        UIImage(named: assetName) != nil
    }

    var body: some View {
        Group {
            if hasRealAsset {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: PlaceholderSymbol.sfSymbolName(for: assetName))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(tintColor)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - EmptyStateView

/// A reusable empty-state placeholder that shows a large icon,
/// a title, and an optional subtitle. Automatically uses the real
/// asset when available, otherwise falls back to SF Symbols.
///
/// Usage:
///
///     EmptyStateView(
///         assetName: AssetImage.emptyStateTokens,
///         title: "No tokens yet",
///         subtitle: "Add tokens to see them here."
///     )
///
struct EmptyStateView: View {
    let assetName: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            PlaceholderImage(assetName, size: 80, tintColor: RabbyColor.textSecondary)
                .opacity(0.6)

            Text(title)
                .font(.headline)
                .foregroundColor(RabbyColor.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(RabbyColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - LaunchPlaceholderView

/// A full-screen launch / splash placeholder with a gradient
/// background and the Rabby logo in the center.
struct LaunchPlaceholderView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RabbyColor.background, RabbyColor.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                PlaceholderImage(AssetImage.rabbyLogo, size: 96, tintColor: RabbyColor.primary)
                Text("Rabby Wallet")
                    .font(.title2.bold())
                    .foregroundColor(RabbyColor.textPrimary)
            }
        }
    }
}

// MARK: - Programmatic Placeholder Generation

/// Generates a solid-colour UIImage at the requested point size.
/// Useful for contexts that require a UIImage rather than a SwiftUI
/// Image (e.g. UIKit interop, notifications).
enum PlaceholderImageGenerator {

    /// Creates a 1-colour square UIImage.
    static func solidColor(
        _ color: UIColor = UIColor(red: 0.49, green: 0.47, blue: 1.0, alpha: 1.0),
        size: CGSize = CGSize(width: 64, height: 64)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Creates a circular UIImage with the given background colour
    /// and a centred single-character label (e.g. a token symbol).
    static func circleWithInitial(
        _ initial: String,
        backgroundColor: UIColor = UIColor(red: 0.49, green: 0.47, blue: 1.0, alpha: 1.0),
        textColor: UIColor = .white,
        size: CGFloat = 64
    ) -> UIImage {
        let cgSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: cgSize)
        return renderer.image { context in
            // Circle
            backgroundColor.setFill()
            let rect = CGRect(origin: .zero, size: cgSize)
            context.cgContext.fillEllipse(in: rect)

            // Letter
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.4, weight: .semibold),
                .foregroundColor: textColor,
                .paragraphStyle: paragraph
            ]

            let string = String(initial.prefix(1)).uppercased()
            let textSize = (string as NSString).size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size - textSize.width) / 2,
                y: (size - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (string as NSString).draw(in: textRect, withAttributes: attrs)
        }
    }

    /// Creates a gradient UIImage suitable for backgrounds.
    static func gradient(
        colors: [UIColor] = [
            UIColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1.0),
            UIColor(red: 0.11, green: 0.11, blue: 0.16, alpha: 1.0)
        ],
        size: CGSize = CGSize(width: 375, height: 812)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgColors = colors.map { $0.cgColor }
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors as CFArray,
                locations: nil
            ) else { return }

            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }
}

// MARK: - Convenience Extensions

extension Image {
    /// Loads an asset-catalog image by name, falling back to an
    /// SF Symbol if the asset has not been added yet.
    static func assetOrPlaceholder(_ name: String) -> Image {
        if UIImage(named: name) != nil {
            return Image(name)
        }
        return Image(systemName: PlaceholderSymbol.sfSymbolName(for: name))
    }
}
