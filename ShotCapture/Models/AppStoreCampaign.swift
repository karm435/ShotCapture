//
//  AppStoreCampaign.swift
//  ShotCapture
//

import CoreGraphics
import Foundation

nonisolated enum AppStoreDisplayTarget: String, CaseIterable, Codable, Identifiable, Sendable {
    case iPhone69Portrait
    case iPhone69Landscape
    case iPad13Portrait
    case iPad13Landscape

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iPhone69Portrait: "iPhone 6.9″ Portrait"
        case .iPhone69Landscape: "iPhone 6.9″ Landscape"
        case .iPad13Portrait: "iPad 13″ Portrait"
        case .iPad13Landscape: "iPad 13″ Landscape"
        }
    }

    var shortName: String {
        switch self {
        case .iPhone69Portrait: "iPhone Portrait"
        case .iPhone69Landscape: "iPhone Landscape"
        case .iPad13Portrait: "iPad Portrait"
        case .iPad13Landscape: "iPad Landscape"
        }
    }

    var exportFolderName: String {
        switch self {
        case .iPhone69Portrait: "iphone-6.9-portrait"
        case .iPhone69Landscape: "iphone-6.9-landscape"
        case .iPad13Portrait: "ipad-13-portrait"
        case .iPad13Landscape: "ipad-13-landscape"
        }
    }

    var screenshotSize: CGSize {
        switch self {
        case .iPhone69Portrait: CGSize(width: 1320, height: 2868)
        case .iPhone69Landscape: CGSize(width: 2868, height: 1320)
        case .iPad13Portrait: CGSize(width: 2064, height: 2752)
        case .iPad13Landscape: CGSize(width: 2752, height: 2064)
        }
    }

    var previewSize: CGSize {
        switch self {
        case .iPhone69Portrait: CGSize(width: 886, height: 1920)
        case .iPhone69Landscape: CGSize(width: 1920, height: 886)
        case .iPad13Portrait: CGSize(width: 1200, height: 1600)
        case .iPad13Landscape: CGSize(width: 1600, height: 1200)
        }
    }

    var isLandscape: Bool {
        switch self {
        case .iPhone69Landscape, .iPad13Landscape: true
        case .iPhone69Portrait, .iPad13Portrait: false
        }
    }

    var isIPad: Bool {
        switch self {
        case .iPad13Portrait, .iPad13Landscape: true
        case .iPhone69Portrait, .iPhone69Landscape: false
        }
    }

    var defaultDevice: ProductBezelDevice {
        isIPad ? .iPadPro13M5 : .iPhone17ProMax
    }
}

nonisolated enum AppStoreScreenshotLayout: String, CaseIterable, Codable, Identifiable, Sendable {
    case feature
    case centered
    case fullBleed
    case editorial

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .feature: "Feature"
        case .centered: "Centered"
        case .fullBleed: "Full Bleed"
        case .editorial: "Editorial"
        }
    }

    var symbolName: String {
        switch self {
        case .feature: "rectangle.topthird.inset.filled"
        case .centered: "rectangle.center.inset.filled"
        case .fullBleed: "rectangle.fill"
        case .editorial: "text.below.photo"
        }
    }
}

nonisolated struct AppStoreTargetContent: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var target: AppStoreDisplayTarget
    var mediaFileName: String?
    var screenshotTransform: CanvasElementTransform
    var deviceFrameStyle: DeviceFrameStyle
    var productBezelDevice: ProductBezelDevice
    var productBezelFinish: String
    var paddingPercent: Double
    var deviceCornerRadius: Double
    var showDeviceShadow: Bool

    init(
        id: UUID = UUID(),
        target: AppStoreDisplayTarget,
        mediaFileName: String? = nil
    ) {
        self.id = id
        self.target = target
        self.mediaFileName = mediaFileName
        self.screenshotTransform = .screenshotDefault
        self.deviceFrameStyle = .appleProductBezel
        self.productBezelDevice = target.defaultDevice
        self.productBezelFinish = target.defaultDevice.defaultFinish
        self.paddingPercent = target.isLandscape ? 0.12 : 0.08
        self.deviceCornerRadius = target.isIPad ? 42 : 64
        self.showDeviceShadow = true
    }
}

nonisolated struct AppStoreScreenshotPanel: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var headline: String
    var subtitle: String
    var layout: AppStoreScreenshotLayout
    var background: BackgroundStyle
    var titleFontName: String
    var titleFontSize: Double
    var titleColorHex: String
    var titleTransform: CanvasElementTransform
    var subtitleFontName: String
    var subtitleFontSize: Double
    var subtitleColorHex: String
    var subtitleTransform: CanvasElementTransform
    var targetContents: [AppStoreTargetContent]

    init(
        id: UUID = UUID(),
        name: String,
        headline: String = "Show your best feature",
        subtitle: String = "A short, benefit-led supporting line",
        layout: AppStoreScreenshotLayout = .feature,
        background: BackgroundStyle = BackgroundStyle.presets[0],
        targets: [AppStoreDisplayTarget]
    ) {
        self.id = id
        self.name = name
        self.headline = headline
        self.subtitle = subtitle
        self.layout = layout
        self.background = background
        self.titleFontName = "SFProDisplay-Bold"
        self.titleFontSize = 116
        self.titleColorHex = "#FFFFFF"
        self.titleTransform = CanvasElementTransform(
            offsetX: 0,
            offsetY: -0.39,
            scale: 1,
            rotationDegrees: 0
        )
        self.subtitleFontName = "SFProDisplay-Medium"
        self.subtitleFontSize = 54
        self.subtitleColorHex = "#FFFFFF"
        self.subtitleTransform = CanvasElementTransform(
            offsetX: 0,
            offsetY: -0.29,
            scale: 1,
            rotationDegrees: 0
        )
        self.targetContents = targets.map { AppStoreTargetContent(target: $0) }
        applyLayout(layout)
    }

    mutating func content(for target: AppStoreDisplayTarget) -> AppStoreTargetContent {
        if let content = targetContents.first(where: { $0.target == target }) {
            return content
        }
        let content = AppStoreTargetContent(target: target)
        targetContents.append(content)
        return content
    }

    mutating func updateContent(
        for target: AppStoreDisplayTarget,
        _ update: (inout AppStoreTargetContent) -> Void
    ) {
        if let index = targetContents.firstIndex(where: { $0.target == target }) {
            update(&targetContents[index])
        } else {
            var content = AppStoreTargetContent(target: target)
            update(&content)
            targetContents.append(content)
        }
    }

    mutating func applyLayout(_ newLayout: AppStoreScreenshotLayout) {
        layout = newLayout
        switch newLayout {
        case .feature:
            titleTransform = CanvasElementTransform(
                offsetX: 0,
                offsetY: -0.39,
                scale: 1,
                rotationDegrees: 0
            )
            subtitleTransform = CanvasElementTransform(
                offsetX: 0,
                offsetY: -0.29,
                scale: 1,
                rotationDegrees: 0
            )
            for index in targetContents.indices {
                targetContents[index].deviceFrameStyle = .appleProductBezel
                targetContents[index].paddingPercent = targetContents[index].target.isLandscape
                    ? 0.12
                    : 0.08
                targetContents[index].screenshotTransform = CanvasElementTransform(
                    offsetX: 0,
                    offsetY: 0.15,
                    scale: targetContents[index].target.isLandscape ? 0.72 : 0.82,
                    rotationDegrees: 0
                )
            }
        case .centered:
            titleTransform.offsetY = -0.40
            subtitleTransform.offsetY = 0.39
            for index in targetContents.indices {
                targetContents[index].deviceFrameStyle = .appleProductBezel
                targetContents[index].paddingPercent = targetContents[index].target.isLandscape
                    ? 0.12
                    : 0.08
                targetContents[index].screenshotTransform = CanvasElementTransform(
                    offsetX: 0,
                    offsetY: 0,
                    scale: 0.76,
                    rotationDegrees: 0
                )
            }
        case .fullBleed:
            titleTransform.offsetY = -0.38
            subtitleTransform.offsetY = 0.40
            for index in targetContents.indices {
                targetContents[index].screenshotTransform = CanvasElementTransform(
                    offsetX: 0,
                    offsetY: 0,
                    scale: 1.12,
                    rotationDegrees: 0
                )
                targetContents[index].deviceFrameStyle = .none
                targetContents[index].paddingPercent = 0
            }
        case .editorial:
            titleTransform = CanvasElementTransform(
                offsetX: -0.14,
                offsetY: -0.34,
                scale: 0.82,
                rotationDegrees: 0
            )
            subtitleTransform = CanvasElementTransform(
                offsetX: -0.14,
                offsetY: -0.21,
                scale: 0.9,
                rotationDegrees: 0
            )
            for index in targetContents.indices {
                targetContents[index].deviceFrameStyle = .appleProductBezel
                targetContents[index].paddingPercent = targetContents[index].target.isLandscape
                    ? 0.12
                    : 0.08
                targetContents[index].screenshotTransform = CanvasElementTransform(
                    offsetX: 0.22,
                    offsetY: 0.14,
                    scale: 0.72,
                    rotationDegrees: -6,
                    tiltYDegrees: -8
                )
            }
        }
    }
}

nonisolated struct AppStorePreviewItem: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var target: AppStoreDisplayTarget
    var mediaFileName: String
    var sourceDuration: Double
    var trimStart: Double
    var trimEnd: Double
    var hasAudio: Bool

    init(
        id: UUID = UUID(),
        name: String,
        target: AppStoreDisplayTarget,
        mediaFileName: String,
        sourceDuration: Double,
        hasAudio: Bool
    ) {
        self.id = id
        self.name = name
        self.target = target
        self.mediaFileName = mediaFileName
        self.sourceDuration = sourceDuration
        self.trimStart = 0
        self.trimEnd = min(sourceDuration, 30)
        self.hasAudio = hasAudio
    }

    var trimmedDuration: Double {
        max(0, trimEnd - trimStart)
    }
}

nonisolated struct AppStoreCampaign: Codable, Identifiable, Equatable, Sendable {
    static let schemaVersion = 1
    static let maximumScreenshots = 10
    static let maximumPreviewsPerTarget = 3

    var id: UUID
    var schemaVersion: Int
    var name: String
    var locale: String
    var enabledTargets: [AppStoreDisplayTarget]
    var panels: [AppStoreScreenshotPanel]
    var previews: [AppStorePreviewItem]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "New App Store Campaign",
        locale: String = "en-US",
        enabledTargets: [AppStoreDisplayTarget] = [
            .iPhone69Portrait,
            .iPad13Portrait,
        ],
        panels: [AppStoreScreenshotPanel]? = nil,
        previews: [AppStorePreviewItem] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = Self.schemaVersion
        self.name = name
        self.locale = locale
        self.enabledTargets = enabledTargets
        self.panels = panels ?? [
            AppStoreScreenshotPanel(
                name: "Screenshot 1",
                targets: AppStoreDisplayTarget.allCases
            ),
        ]
        self.previews = previews
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
