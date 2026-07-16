//
//  SocialPlatform.swift
//  ShotCapture
//

import Foundation
import CoreGraphics

/// Social feed canvas sizes chosen so the framed screenshot displays fully
/// without platform crop. Specs follow 2026 platform guidance.
enum SocialPlatform: String, CaseIterable, Identifiable, Codable, Hashable {
    case xFeed
    case linkedInFeed
    case linkedInSquare
    case instagramPortrait
    case instagramSquare
    case instagramStory
    case facebookPortrait
    case tikTok
    case youTubeThumb
    case bluesky

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .xFeed: return "X (Twitter)"
        case .linkedInFeed: return "LinkedIn"
        case .linkedInSquare: return "LinkedIn Square"
        case .instagramPortrait: return "Instagram Feed"
        case .instagramSquare: return "Instagram Square"
        case .instagramStory: return "Instagram Story / Reels"
        case .facebookPortrait: return "Facebook Feed"
        case .tikTok: return "TikTok"
        case .youTubeThumb: return "YouTube Thumbnail"
        case .bluesky: return "Bluesky"
        }
    }

    var subtitle: String {
        switch self {
        case .xFeed: return "16:9 · 1600×900 — full image in feed"
        case .linkedInFeed: return "1.91:1 · 1200×627 — link / landscape post"
        case .linkedInSquare: return "1:1 · 1200×1200 — feed image"
        case .instagramPortrait: return "4:5 · 1080×1350 — max feed real estate"
        case .instagramSquare: return "1:1 · 1080×1080"
        case .instagramStory: return "9:16 · 1080×1920 — Stories & Reels"
        case .facebookPortrait: return "4:5 · 1080×1350"
        case .tikTok: return "9:16 · 1080×1920"
        case .youTubeThumb: return "16:9 · 1280×720"
        case .bluesky: return "1:1 · 1000×1000"
        }
    }

    /// Output pixel size for the composed share image.
    var canvasSize: CGSize {
        switch self {
        case .xFeed: return CGSize(width: 1600, height: 900)
        case .linkedInFeed: return CGSize(width: 1200, height: 627)
        case .linkedInSquare: return CGSize(width: 1200, height: 1200)
        case .instagramPortrait: return CGSize(width: 1080, height: 1350)
        case .instagramSquare: return CGSize(width: 1080, height: 1080)
        case .instagramStory: return CGSize(width: 1080, height: 1920)
        case .facebookPortrait: return CGSize(width: 1080, height: 1350)
        case .tikTok: return CGSize(width: 1080, height: 1920)
        case .youTubeThumb: return CGSize(width: 1280, height: 720)
        case .bluesky: return CGSize(width: 1000, height: 1000)
        }
    }

    var systemImage: String {
        switch self {
        case .xFeed: return "bubble.left"
        case .linkedInFeed, .linkedInSquare: return "briefcase"
        case .instagramPortrait, .instagramSquare, .instagramStory: return "camera"
        case .facebookPortrait: return "person.2"
        case .tikTok: return "music.note"
        case .youTubeThumb: return "play.rectangle"
        case .bluesky: return "cloud"
        }
    }
}
