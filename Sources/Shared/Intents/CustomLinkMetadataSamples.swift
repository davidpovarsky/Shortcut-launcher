import Foundation
import LinkPresentation
import SwiftUI
import UIKit

/// Fully local artwork supplied to LinkMetadata, not fetched from the website.
/// This experiments with whether Shortcuts Choose from List retains user-provided
/// titles, cover images and icons after the App Intents handoff.
@MainActor
enum CustomLinkMetadataSamples {
    struct Card {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let foreground: UIColor
        let background: UIColor
    }

    static func make() -> [LinkMetadata] {
        let entries = [
            Card(
                id: "settings",
                title: "הגדרות",
                subtitle: "התאמה אישית והעדפות",
                symbol: "gearshape.fill",
                foreground: UIColor(red: 0.15, green: 0.39, blue: 0.83, alpha: 1),
                background: UIColor(red: 0.88, green: 0.93, blue: 1.00, alpha: 1)
            ),
            Card(
                id: "files",
                title: "קבצים",
                subtitle: "צפייה וניהול קבצים",
                symbol: "folder.fill",
                foreground: UIColor(red: 0.78, green: 0.39, blue: 0.08, alpha: 1),
                background: UIColor(red: 1.00, green: 0.94, blue: 0.81, alpha: 1)
            ),
            Card(
                id: "favorites",
                title: "מועדפים",
                subtitle: "פריטים ששמרתי",
                symbol: "star.fill",
                foreground: UIColor(red: 0.52, green: 0.27, blue: 0.80, alpha: 1),
                background: UIColor(red: 0.94, green: 0.88, blue: 1.00, alpha: 1)
            )
        ]

        return entries.map { card in
            // A real valid URL, intentionally never fetched. The query string
            // distinguishes the three cards while preserving the same host.
            let url = URL(string: "https://www.apple.com/?davlauncher-card=\(card.id)")!
            var metadata = LinkMetadata(url: url)
            metadata.title = card.title
            metadata.setMedia(Image(uiImage: coverImage(for: card)), for: .image)
            metadata.setMedia(Image(uiImage: iconImage(for: card)), for: .icon)
            return metadata
        }
    }

    private static func coverImage(for card: Card) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: 900, height: 520)
        return UIGraphicsImageRenderer(size: bounds.size).image { _ in
            card.background.setFill()
            UIBezierPath(rect: bounds).fill()

            // One purposeful illustration: oversized SF Symbol in a soft tile.
            let tile = CGRect(x: 324, y: 48, width: 252, height: 252)
            card.foreground.withAlphaComponent(0.13).setFill()
            UIBezierPath(roundedRect: tile, cornerRadius: 65).fill()
            let symbol = UIImage(
                systemName: card.symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 150, weight: .medium)
            )
            symbol?.withTintColor(card.foreground, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 375, y: 99, width: 150, height: 150))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingTail
            (card.title as NSString).draw(
                in: CGRect(x: 60, y: 322, width: 780, height: 76),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 63),
                    .foregroundColor: card.foreground,
                    .paragraphStyle: paragraph
                ]
            )
            (card.subtitle as NSString).draw(
                in: CGRect(x: 50, y: 420, width: 800, height: 52),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 32),
                    .foregroundColor: card.foreground.withAlphaComponent(0.80),
                    .paragraphStyle: paragraph
                ]
            )
        }
    }

    private static func iconImage(for card: Card) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: size).image { _ in
            card.background.setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 28
            ).fill()
            let symbol = UIImage(
                systemName: card.symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 70, weight: .medium)
            )
            symbol?.withTintColor(card.foreground, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 30, y: 30, width: 68, height: 68))
        }
    }
}


extension CustomLinkMetadataSamples {
    /// Direct LinkMetadata route, using the artwork made in the existing lab.
    static func makeDirectComparison() -> [LinkMetadata] {
        make()
    }

    /// Convert manually constructed legacy metadata to App Intents LinkMetadata.
    /// This tests whether NSItemProvider image attachments survive the bridge.
    static func makeLegacyComparison() -> [LinkMetadata] {
        let entries = [
            Card(
                id: "settings", title: "הגדרות - LEGACY",
                subtitle: "תמונת כיסוי מקומית - LPLinkMetadata",
                symbol: "gearshape.fill",
                foreground: UIColor(red: 0.15, green: 0.39, blue: 0.83, alpha: 1),
                background: UIColor(red: 0.88, green: 0.93, blue: 1, alpha: 1)
            ),
            Card(
                id: "files", title: "קבצים - LEGACY",
                subtitle: "תמונת כיסוי מקומית - LPLinkMetadata",
                symbol: "folder.fill",
                foreground: UIColor(red: 0.78, green: 0.39, blue: 0.08, alpha: 1),
                background: UIColor(red: 1, green: 0.94, blue: 0.81, alpha: 1)
            ),
            Card(
                id: "favorites", title: "מועדפים - LEGACY",
                subtitle: "תמונת כיסוי מקומית - LPLinkMetadata",
                symbol: "star.fill",
                foreground: UIColor(red: 0.52, green: 0.27, blue: 0.80, alpha: 1),
                background: UIColor(red: 0.94, green: 0.88, blue: 1, alpha: 1)
            )
        ]
        return entries.compactMap { card -> LinkMetadata? in
            let url = URL(string: "https://www.apple.com/?davlauncher-legacy=\(card.id)")!
            let legacy = LPLinkMetadata()
            legacy.originalURL = url
            legacy.url = url
            legacy.title = card.title
            legacy.imageProvider = NSItemProvider(object: coverImage(for: card))
            legacy.iconProvider = NSItemProvider(object: iconImage(for: card))
            return LinkMetadata(legacy)
        }
    }
}
