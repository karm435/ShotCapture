//
//  AppStoreScreenshotExportService.swift
//  ShotCapture
//

import AppKit
import Foundation

nonisolated enum AppStorePreflightSeverity: String, Sendable {
    case warning
    case error
}

nonisolated struct AppStorePreflightIssue: Identifiable, Sendable {
    let id = UUID()
    let severity: AppStorePreflightSeverity
    let message: String
    let panelID: UUID?
    let target: AppStoreDisplayTarget?
}

nonisolated struct AppStoreScreenshotExportResult: Sendable {
    let rootURL: URL
    let exportedFiles: [URL]
}

nonisolated enum AppStoreScreenshotExportError: LocalizedError {
    case missingMedia(String, AppStoreDisplayTarget)
    case unreadableMedia(String)
    case renderingFailed
    case preflightFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingMedia(let panel, let target):
            "“\(panel)” has no media for \(target.shortName)."
        case .unreadableMedia(let name):
            "The image asset “\(name)” could not be read."
        case .renderingFailed:
            "ShotCapture could not create an opaque App Store PNG."
        case .preflightFailed(let count):
            "Export stopped because preflight found \(count) blocking issue\(count == 1 ? "" : "s")."
        }
    }
}

@MainActor
final class AppStoreScreenshotExportService {
    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSURL, NSImage>()

    init() {
        imageCache.countLimit = 24
        imageCache.totalCostLimit = 256 * 1_024 * 1_024
    }

    func preflight(
        campaign: AppStoreCampaign,
        packageURL: URL
    ) -> [AppStorePreflightIssue] {
        var issues: [AppStorePreflightIssue] = []

        if campaign.enabledTargets.isEmpty {
            issues.append(AppStorePreflightIssue(
                severity: .error,
                message: "Enable at least one iPhone or iPad display target.",
                panelID: nil,
                target: nil
            ))
        }
        if campaign.panels.isEmpty {
            issues.append(AppStorePreflightIssue(
                severity: .error,
                message: "Add at least one screenshot.",
                panelID: nil,
                target: nil
            ))
        }
        if campaign.panels.count > AppStoreCampaign.maximumScreenshots {
            issues.append(AppStorePreflightIssue(
                severity: .error,
                message: "App Store Connect accepts no more than 10 screenshots per display target.",
                panelID: nil,
                target: nil
            ))
        }

        for panel in campaign.panels {
            if panel.headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(AppStorePreflightIssue(
                    severity: .warning,
                    message: "“\(panel.name)” has no headline.",
                    panelID: panel.id,
                    target: nil
                ))
            }

            for target in campaign.enabledTargets {
                guard let content = panel.targetContents.first(where: { $0.target == target }),
                      let mediaFileName = content.mediaFileName else {
                    issues.append(AppStorePreflightIssue(
                        severity: .error,
                        message: "“\(panel.name)” needs media for \(target.shortName).",
                        panelID: panel.id,
                        target: target
                    ))
                    continue
                }
                let mediaURL = packageURL
                    .appending(path: "Assets", directoryHint: .isDirectory)
                    .appending(path: mediaFileName)
                guard let image = cachedImage(at: mediaURL) else {
                    issues.append(AppStorePreflightIssue(
                        severity: .error,
                        message: "“\(panel.name)” references an unreadable image for \(target.shortName).",
                        panelID: panel.id,
                        target: target
                    ))
                    continue
                }
                let mediaLandscape = image.size.width > image.size.height
                if mediaLandscape != target.isLandscape {
                    issues.append(AppStorePreflightIssue(
                        severity: .warning,
                        message: "“\(panel.name)” uses \(mediaLandscape ? "landscape" : "portrait") media on \(target.shortName).",
                        panelID: panel.id,
                        target: target
                    ))
                }
            }
        }

        for target in campaign.enabledTargets {
            let count = campaign.previews.filter { $0.target == target }.count
            if count > AppStoreCampaign.maximumPreviewsPerTarget {
                issues.append(AppStorePreflightIssue(
                    severity: .error,
                    message: "\(target.shortName) has more than 3 App Previews.",
                    panelID: nil,
                    target: target
                ))
            }
        }

        for preview in campaign.previews where campaign.enabledTargets.contains(preview.target) {
            let sourceURL = packageURL
                .appending(path: "Assets", directoryHint: .isDirectory)
                .appending(path: preview.mediaFileName)
            if !fileManager.fileExists(atPath: sourceURL.path()) {
                issues.append(AppStorePreflightIssue(
                    severity: .error,
                    message: "App Preview “\(preview.name)” references a missing movie.",
                    panelID: nil,
                    target: preview.target
                ))
            }
            if preview.trimmedDuration < 15 || preview.trimmedDuration > 30 {
                issues.append(AppStorePreflightIssue(
                    severity: .error,
                    message: "App Preview “\(preview.name)” must be trimmed to 15–30 seconds.",
                    panelID: nil,
                    target: preview.target
                ))
            }
        }

        return issues
    }

    func render(
        panel: AppStoreScreenshotPanel,
        target: AppStoreDisplayTarget,
        packageURL: URL
    ) throws -> NSImage {
        try render(
            panel: panel,
            target: target,
            packageURL: packageURL,
            canvasSize: target.screenshotSize,
            contentScale: 1
        )
    }

    func renderPreview(
        panel: AppStoreScreenshotPanel,
        target: AppStoreDisplayTarget,
        packageURL: URL,
        maximumDimension: CGFloat
    ) throws -> NSImage {
        let exportSize = target.screenshotSize
        let longestEdge = max(exportSize.width, exportSize.height)
        let contentScale = min(1, maximumDimension / longestEdge)
        return try render(
            panel: panel,
            target: target,
            packageURL: packageURL,
            canvasSize: CGSize(
                width: (exportSize.width * contentScale).rounded(),
                height: (exportSize.height * contentScale).rounded()
            ),
            contentScale: contentScale
        )
    }

    func renderPreviewLayers(
        panel: AppStoreScreenshotPanel,
        target: AppStoreDisplayTarget,
        packageURL: URL,
        maximumDimension: CGFloat
    ) throws -> AppStoreScreenshotPreviewLayers {
        let exportSize = target.screenshotSize
        let longestEdge = max(exportSize.width, exportSize.height)
        let contentScale = min(1, maximumDimension / longestEdge)
        let canvasSize = CGSize(
            width: (exportSize.width * contentScale).rounded(),
            height: (exportSize.height * contentScale).rounded()
        )
        let request = try compositionRequest(
            panel: panel,
            target: target,
            packageURL: packageURL,
            canvasSize: canvasSize,
            contentScale: contentScale
        )
        guard let device = CompositionService.untransformedDeviceLayer(request) else {
            throw AppStoreScreenshotExportError.renderingFailed
        }
        return AppStoreScreenshotPreviewLayers(
            backdrop: CompositionService.composeBackdrop(request),
            device: device,
            canvasSize: canvasSize,
            showsDeviceShadow: request.showDeviceShadow
        )
    }

    private func render(
        panel: AppStoreScreenshotPanel,
        target: AppStoreDisplayTarget,
        packageURL: URL,
        canvasSize: CGSize,
        contentScale: CGFloat
    ) throws -> NSImage {
        let request = try compositionRequest(
            panel: panel,
            target: target,
            packageURL: packageURL,
            canvasSize: canvasSize,
            contentScale: contentScale
        )
        return CompositionService.compose(request)
    }

    private func compositionRequest(
        panel: AppStoreScreenshotPanel,
        target: AppStoreDisplayTarget,
        packageURL: URL,
        canvasSize: CGSize,
        contentScale: CGFloat
    ) throws -> CompositionRequest {
        guard let content = panel.targetContents.first(where: { $0.target == target }),
              let mediaFileName = content.mediaFileName else {
            throw AppStoreScreenshotExportError.missingMedia(panel.name, target)
        }
        let mediaURL = packageURL
            .appending(path: "Assets", directoryHint: .isDirectory)
            .appending(path: mediaFileName)
        guard let source = cachedImage(at: mediaURL) else {
            throw AppStoreScreenshotExportError.unreadableMedia(mediaFileName)
        }

        let bezelURL = content.productBezelDevice.resourceURL(
            finish: content.productBezelFinish,
            isLandscape: target.isLandscape
        )
        let bezel = bezelURL.flatMap(cachedImage(at:))
        let requestedStyle: DeviceFrameStyle
        if content.deviceFrameStyle == .appleProductBezel, bezel == nil {
            requestedStyle = .genericPhone
        } else {
            requestedStyle = content.deviceFrameStyle
        }

        let request = CompositionRequest(
            screenshot: source,
            canvasSize: canvasSize,
            background: panel.background,
            paddingPercent: content.paddingPercent,
            deviceCornerRadius: content.deviceCornerRadius,
            showDeviceShadow: content.showDeviceShadow,
            watermarkEnabled: false,
            watermarkText: "",
            screenshotTransform: content.screenshotTransform,
            deviceFrameStyle: requestedStyle,
            productBezel: bezel,
            productBezelAperture: content.productBezelDevice.screenAperture(
                isLandscape: target.isLandscape
            ),
            productBezelScreenCornerRadiusRatio: content.productBezelDevice.screenCornerRadiusRatio,
            deviceDepthRatio: content.productBezelDevice.thicknessToWidthRatio,
            deviceEdgeTint: content.productBezelDevice.edgeTint(
                finish: content.productBezelFinish
            ),
            titleEnabled: !panel.headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            titleText: panel.headline,
            titleFontName: panel.titleFontName,
            titleFontSize: panel.titleFontSize * contentScale,
            titleTransform: panel.titleTransform,
            titleColor: NSColor(hex: panel.titleColorHex) ?? .white,
            titleMaxWidthPercent: panel.layout == .editorial ? 0.56 : 0.88,
            subtitleEnabled: !panel.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            subtitleText: panel.subtitle,
            subtitleFontName: panel.subtitleFontName,
            subtitleFontSize: panel.subtitleFontSize * contentScale,
            subtitleTransform: panel.subtitleTransform,
            subtitleColor: NSColor(hex: panel.subtitleColorHex) ?? .white,
            subtitleMaxWidthPercent: panel.layout == .editorial ? 0.54 : 0.82
        )
        return request
    }

    private func cachedImage(at url: URL) -> NSImage? {
        let key = url.standardizedFileURL as NSURL
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        let estimatedCost = max(
            1,
            Int(image.size.width * image.size.height * 4)
        )
        imageCache.setObject(image, forKey: key, cost: estimatedCost)
        return image
    }

    func export(
        campaign: AppStoreCampaign,
        packageURL: URL,
        destinationDirectory: URL,
        progress: @escaping @MainActor (Double, String) -> Void
    ) async throws -> AppStoreScreenshotExportResult {
        let issues = preflight(campaign: campaign, packageURL: packageURL)
        let blockingCount = issues.filter { $0.severity == .error }.count
        guard blockingCount == 0 else {
            throw AppStoreScreenshotExportError.preflightFailed(blockingCount)
        }

        let rootURL = uniqueExportDirectory(
            in: destinationDirectory,
            campaignName: campaign.name
        )
        let screenshotRoot = rootURL
            .appending(path: campaign.locale, directoryHint: .isDirectory)
            .appending(path: "Screenshots", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: screenshotRoot,
            withIntermediateDirectories: true
        )

        let total = max(1, campaign.panels.count * campaign.enabledTargets.count)
        var completed = 0
        var exportedFiles: [URL] = []

        for target in campaign.enabledTargets {
            try Task.checkCancellation()
            let targetDirectory = screenshotRoot.appending(
                path: target.exportFolderName,
                directoryHint: .isDirectory
            )
            try fileManager.createDirectory(
                at: targetDirectory,
                withIntermediateDirectories: true
            )

            for (index, panel) in campaign.panels.enumerated() {
                try Task.checkCancellation()
                progress(
                    Double(completed) / Double(total),
                    "Rendering \(target.shortName) · \(index + 1) of \(campaign.panels.count)"
                )
                let image = try render(
                    panel: panel,
                    target: target,
                    packageURL: packageURL
                )
                guard let data = CompositionService.opaquePNGData(
                    from: image,
                    pixelSize: target.screenshotSize
                ) else {
                    throw AppStoreScreenshotExportError.renderingFailed
                }
                let fileName = String(
                    format: "%02d-%@.png",
                    index + 1,
                    sanitizedFileName(panel.name)
                )
                let fileURL = targetDirectory.appending(path: fileName)
                try data.write(to: fileURL, options: .atomic)
                exportedFiles.append(fileURL)
                completed += 1
            }
        }

        progress(1, "Exported \(exportedFiles.count) screenshots")
        return AppStoreScreenshotExportResult(
            rootURL: rootURL,
            exportedFiles: exportedFiles
        )
    }

    private func uniqueExportDirectory(
        in parent: URL,
        campaignName: String
    ) -> URL {
        let baseName = "\(sanitizedFileName(campaignName))-app-store-assets"
        var candidate = parent.appending(path: baseName, directoryHint: .isDirectory)
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path()) {
            candidate = parent.appending(
                path: "\(baseName)-\(suffix)",
                directoryHint: .isDirectory
            )
            suffix += 1
        }
        return candidate
    }

    private func sanitizedFileName(_ value: String) -> String {
        let words = value.lowercased().split { !$0.isLetter && !$0.isNumber }
        return words.isEmpty ? "screenshot" : words.joined(separator: "-")
    }
}
