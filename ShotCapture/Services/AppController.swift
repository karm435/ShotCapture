//
//  AppController.swift
//  ShotCapture
//

import AppKit
import AVFoundation
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class AppController {
    let settings = AppSettings()
    let captureService = SimulatorCaptureService()
    let recordingService = SimulatorRecordingService()
    let videoImportService = VideoImportService()
    let videoExportService = VideoExportService()
    let hotkeyService = HotkeyService()
    let xcodeAccess = XcodeAccessService()

    var bootedDevices: [SimulatorDevice] = []
    var isCapturing = false
    var isLoadingVideo = false
    var lastError: String?
    var editorMedia: EditorMedia?
    var composedImage: NSImage?
    var videoPlayer: AVPlayer?
    var isVideoPlaying = false
    var videoCurrentTime = 0.0
    var videoDuration = 0.0
    var videoTrimStart = 0.0
    var videoTrimEnd = 0.0
    var recordingState: SimulatorRecordingState = .idle
    var videoExportState: VideoExportState = .idle
    var importedProductBezels: [ImportedProductBezel] = []
    var selectedProductBezelID: UUID?
    var statusMessage: String = "Ready"

    /// Stored from SwiftUI so we can open the Window scene from hotkeys.
    var openPreviewWindowAction: (() -> Void)?

    private var fallbackPreviewWindow: NSWindow?
    private var videoTimeObserver: Any?
    private var securityScopedVideoURL: URL?
    private var videoExportCancellationRequested = false

    var rawScreenshot: NSImage? {
        guard case .image(let image) = editorMedia else { return nil }
        return image
    }

    var currentVideo: EditorVideo? {
        guard case .video(let video) = editorMedia else { return nil }
        return video
    }

    var hasEditableMedia: Bool {
        editorMedia != nil
    }

    var isEditingVideo: Bool {
        currentVideo != nil
    }

    var videoHasAudio: Bool {
        currentVideo?.hasAudio == true
    }

    init() {
        if settings.deviceFrameStyle == .importedProductBezel {
            settings.deviceFrameStyle = .appleProductBezel
        }
        refreshHotkey()
    }

    func refreshHotkey() {
        hotkeyService.update(
            keyCode: settings.hotkeyKeyCode,
            modifiers: settings.hotkeyModifiers
        ) { [weak self] in
            Task { @MainActor in
                await self?.captureAndShowPreview()
            }
        }
    }

    func refreshDevices() async {
        guard xcodeAccess.hasAccess,
              let developerDirectory = xcodeAccess.developerDirectoryURL else {
            bootedDevices = []
            statusMessage = "Editor ready · Choose Xcode for Simulator"
            return
        }

        do {
            bootedDevices = try await captureService.listBootedDevices(
                developerDirectory: developerDirectory
            )
            if bootedDevices.isEmpty {
                statusMessage = "Editor ready · No simulator booted"
            } else if bootedDevices.count == 1 {
                statusMessage = "Ready · \(bootedDevices[0].name)"
            } else {
                statusMessage = "Ready · \(bootedDevices.count) simulators"
            }
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Simulator unavailable"
        }
    }

    func captureAndShowPreview() async {
        guard !isCapturing,
              !recordingState.isActive,
              !videoExportState.isExporting else { return }
        guard let developerDirectory = requireDeveloperDirectory() else { return }
        isCapturing = true
        lastError = nil
        statusMessage = "Capturing…"
        defer { isCapturing = false }

        do {
            await refreshDevices()
            let udid = resolvedUDID()
            let image = try await captureService.captureScreenshot(
                udid: udid,
                developerDirectory: developerDirectory
            )
            replaceEditorMedia(with: .image(image))
            recompose()
            // Only dock beside Simulator the first time; keep user's placement after that.
            presentPreviewWindow(repositionIfNeeded: existingPreviewWindow() == nil)
            statusMessage = "Captured"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Capture failed"
            NSSound.beep()
        }
    }

    /// Recapture for an already-open preview — never moves the window.
    func recaptureKeepingWindowPlace() async {
        guard !isCapturing,
              !recordingState.isActive,
              !videoExportState.isExporting else { return }
        guard let developerDirectory = requireDeveloperDirectory() else { return }
        isCapturing = true
        lastError = nil
        statusMessage = "Capturing…"
        defer { isCapturing = false }

        do {
            await refreshDevices()
            let udid = resolvedUDID()
            let image = try await captureService.captureScreenshot(
                udid: udid,
                developerDirectory: developerDirectory
            )
            replaceEditorMedia(with: .image(image))
            recompose()
            presentPreviewWindow(repositionIfNeeded: false)
            statusMessage = "Captured"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Capture failed"
            NSSound.beep()
        }
    }

    func toggleSimulatorRecording() async {
        if recordingState == .recording {
            await stopSimulatorRecording()
        } else if recordingState == .idle {
            await startSimulatorRecording()
        }
    }

    func startSimulatorRecording() async {
        guard recordingState == .idle,
              !isCapturing,
              !videoExportState.isExporting else { return }
        guard let developerDirectory = requireDeveloperDirectory() else { return }
        recordingState = .starting
        lastError = nil
        statusMessage = "Starting recording…"

        do {
            await refreshDevices()
            guard let udid = resolvedUDID() else {
                throw SimulatorCaptureError.noBootedSimulator
            }
            _ = try await recordingService.startRecording(
                udid: udid,
                developerDirectory: developerDirectory
            )
            recordingState = .recording
            statusMessage = "Recording Simulator"
        } catch {
            recordingState = .idle
            lastError = error.localizedDescription
            statusMessage = "Recording failed"
            NSSound.beep()
        }
    }

    func stopSimulatorRecording() async {
        guard recordingState == .recording else { return }
        recordingState = .finalizing
        statusMessage = "Finalizing recording…"

        do {
            let url = try await recordingService.stopRecording()
            recordingState = .idle
            await useVideo(at: url, deletesFileWhenReplaced: true)
        } catch {
            recordingState = .idle
            lastError = error.localizedDescription
            statusMessage = "Recording failed"
            NSSound.beep()
        }
    }

    func cancelSimulatorRecording() {
        guard recordingState.isActive else { return }
        Task { await recordingService.cancelRecording() }
        recordingState = .idle
        statusMessage = "Recording cancelled"
    }

    func recompose() {
        switch editorMedia {
        case .image(let image):
            composedImage = CompositionService.compose(compositionRequest(for: image))
        case .video(let video):
            composedImage = nil
            guard let item = videoPlayer?.currentItem else { return }
            item.videoComposition = makeVideoComposition(for: video)
            item.seekingWaitsForVideoCompositionRendering = true
        case nil:
            composedImage = nil
        }
    }

    private func compositionRequest(for sourceImage: NSImage) -> CompositionRequest {
        CompositionRequest(
            screenshot: sourceImage,
            platform: settings.selectedPlatform,
            background: settings.selectedBackground,
            paddingPercent: settings.paddingPercent,
            deviceCornerRadius: settings.deviceCornerRadius,
            showDeviceShadow: settings.showDeviceShadow,
            watermarkEnabled: settings.watermarkEnabled,
            watermarkText: settings.watermarkText,
            screenshotTransform: settings.screenshotTransform,
            deviceFrameStyle: settings.deviceFrameStyle,
            productBezel: activeProductBezelImage,
            productBezelAperture: activeProductBezelAperture,
            productBezelScreenCornerRadiusRatio: activeProductBezelScreenCornerRadiusRatio,
            importedBezelInset: settings.importedBezelInset,
            deviceDepthRatio: activeDeviceDepthRatio,
            deviceEdgeTint: activeDeviceEdgeTint,
            titleEnabled: settings.titleEnabled,
            titleText: settings.titleText,
            titleFontName: settings.titleFontName,
            titleFontSize: settings.titleFontSize,
            titleTransform: settings.titleTransform
        )
    }

    private func makeVideoComposition(for video: EditorVideo) -> AVVideoComposition {
        let placeholder = NSImage(size: video.displaySize)
        return VideoCompositionService.makeComposition(
            for: video,
            request: compositionRequest(for: placeholder)
        )
    }

    var selectedProductBezel: ImportedProductBezel? {
        guard let selectedProductBezelID else { return importedProductBezels.first }
        return importedProductBezels.first(where: { $0.id == selectedProductBezelID })
    }

    private var activeProductBezelImage: NSImage? {
        switch settings.deviceFrameStyle {
        case .appleProductBezel:
            guard let size = activeMediaSize else { return nil }
            let url = settings.productBezelDevice.resourceURL(
                finish: settings.productBezelFinish,
                isLandscape: size.width > size.height
            )
            return url.flatMap(NSImage.init(contentsOf:))
        case .importedProductBezel:
            return selectedProductBezel?.image
        case .none, .genericPhone:
            return nil
        }
    }

    private var activeProductBezelAperture: CGRect? {
        guard settings.deviceFrameStyle == .appleProductBezel,
              let size = activeMediaSize else { return nil }
        return settings.productBezelDevice.screenAperture(
            isLandscape: size.width > size.height
        )
    }

    private var activeMediaSize: CGSize? {
        switch editorMedia {
        case .image(let image): image.size
        case .video(let video): video.displaySize
        case nil: nil
        }
    }

    private var activeDeviceDepthRatio: Double {
        if settings.deviceFrameStyle == .appleProductBezel {
            settings.productBezelDevice.thicknessToWidthRatio
        } else {
            0.11
        }
    }

    private var activeProductBezelScreenCornerRadiusRatio: Double {
        if settings.deviceFrameStyle == .appleProductBezel {
            settings.productBezelDevice.screenCornerRadiusRatio
        } else {
            0.105
        }
    }

    private var activeDeviceEdgeTint: NSColor {
        if settings.deviceFrameStyle == .appleProductBezel {
            settings.productBezelDevice.edgeTint(finish: settings.productBezelFinish)
        } else {
            NSColor(calibratedWhite: 0.16, alpha: 1)
        }
    }

    func pasteScreenshot() {
        let pasteboard = NSPasteboard.general
        if let fileURLString = pasteboard.string(forType: .fileURL),
           let fileURL = URL(string: fileURLString),
           isVideoFile(fileURL) {
            Task { await useVideo(at: fileURL, deletesFileWhenReplaced: false) }
            return
        }

        guard let image = NSImage(pasteboard: pasteboard) else {
            lastError = "The clipboard does not contain an image or video file."
            statusMessage = "No media on clipboard"
            NSSound.beep()
            return
        }
        useScreenshot(image, status: "Pasted image")
    }

    func importScreenshot() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an image or video to compose."

        guard panel.runModal() == .OK,
              let url = panel.url else { return }
        if isVideoFile(url) {
            Task { await useVideo(at: url, deletesFileWhenReplaced: false) }
        } else if let image = NSImage(contentsOf: url) {
            useScreenshot(image, status: "Imported \(url.lastPathComponent)")
        }
    }

    func importProductBezels() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose transparent product bezel images you downloaded from Apple."

        guard panel.runModal() == .OK else { return }
        let imported = panel.urls.compactMap { url -> ImportedProductBezel? in
            guard let image = NSImage(contentsOf: url) else { return nil }
            return ImportedProductBezel(
                name: url.deletingPathExtension().lastPathComponent,
                image: image
            )
        }
        guard !imported.isEmpty else {
            lastError = "No supported bezel images were selected."
            NSSound.beep()
            return
        }

        importedProductBezels.append(contentsOf: imported)
        selectedProductBezelID = imported.first?.id
        settings.deviceFrameStyle = .importedProductBezel
        recompose()
        statusMessage = "Imported \(imported.count) bezel\(imported.count == 1 ? "" : "s")"
    }

    func openAppleBezelResources() {
        guard let url = URL(string: "https://developer.apple.com/design/resources/#product-bezels") else { return }
        NSWorkspace.shared.open(url)
    }

    func resetCanvas() {
        settings.resetCanvasTransforms()
        recompose()
        statusMessage = "Canvas reset"
    }

    private func useScreenshot(_ image: NSImage, status: String) {
        replaceEditorMedia(with: .image(image))
        settings.screenshotTransform = .screenshotDefault
        recompose()
        presentPreviewWindow(repositionIfNeeded: false)
        statusMessage = status
    }

    private func useVideo(
        at url: URL,
        deletesFileWhenReplaced: Bool
    ) async {
        guard !videoExportState.isExporting else { return }
        isLoadingVideo = true
        lastError = nil
        statusMessage = "Loading video…"
        let gainedSecurityScope = !deletesFileWhenReplaced && url.startAccessingSecurityScopedResource()
        defer { isLoadingVideo = false }

        do {
            let video = try await videoImportService.loadVideo(
                at: url,
                deletesFileWhenReplaced: deletesFileWhenReplaced
            )
            replaceEditorMedia(with: .video(video))
            securityScopedVideoURL = gainedSecurityScope ? url : nil
            videoDuration = video.durationSeconds
            videoTrimStart = 0
            videoTrimEnd = video.durationSeconds
            videoCurrentTime = 0
            settings.screenshotTransform = .screenshotDefault
            configurePlayer(for: video)
            recompose()
            presentPreviewWindow(repositionIfNeeded: false)
            statusMessage = "Loaded \(video.displayName)"
        } catch {
            if gainedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            if deletesFileWhenReplaced {
                try? FileManager.default.removeItem(at: url)
            }
            lastError = error.localizedDescription
            statusMessage = "Video import failed"
            NSSound.beep()
        }
    }

    private func isVideoFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey])
        return values?.contentType?.conforms(to: .movie) == true
    }

    private func replaceEditorMedia(with media: EditorMedia) {
        pauseVideo()
        removeVideoTimeObserver()
        if let securityScopedVideoURL {
            securityScopedVideoURL.stopAccessingSecurityScopedResource()
            self.securityScopedVideoURL = nil
        }
        if let currentVideo, currentVideo.deletesFileWhenReplaced {
            try? FileManager.default.removeItem(at: currentVideo.url)
        }
        videoPlayer = nil
        editorMedia = media
    }

    private func configurePlayer(for video: EditorVideo) {
        let item = AVPlayerItem(asset: AVURLAsset(url: video.url))
        let player = AVPlayer(playerItem: item)
        videoPlayer = player
        installVideoTimeObserver(on: player)
    }

    func toggleVideoPlayback() {
        guard let player = videoPlayer else { return }
        if isVideoPlaying {
            pauseVideo()
            return
        }
        if videoCurrentTime >= videoTrimEnd - 0.02 {
            seekVideo(to: videoTrimStart)
        }
        player.play()
        isVideoPlaying = true
    }

    func pauseVideo() {
        videoPlayer?.pause()
        isVideoPlaying = false
    }

    func seekVideo(to seconds: Double) {
        guard let player = videoPlayer else { return }
        let target = min(max(seconds, videoTrimStart), videoTrimEnd)
        videoCurrentTime = target
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func normalizeVideoTrim() {
        guard videoDuration > 0 else { return }
        let minimumDuration = min(0.05, videoDuration)
        let start = min(max(videoTrimStart, 0), max(0, videoDuration - minimumDuration))
        let end = min(max(videoTrimEnd, start + minimumDuration), videoDuration)
        if videoTrimStart != start { videoTrimStart = start }
        if videoTrimEnd != end { videoTrimEnd = end }
        if videoCurrentTime < start || videoCurrentTime > end {
            seekVideo(to: start)
        }
    }

    private func installVideoTimeObserver(on player: AVPlayer) {
        removeVideoTimeObserver()
        videoTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = time.seconds
                guard seconds.isFinite else { return }
                if seconds >= self.videoTrimEnd - 0.01, self.isVideoPlaying {
                    self.pauseVideo()
                    self.videoCurrentTime = self.videoTrimEnd
                } else {
                    self.videoCurrentTime = min(
                        max(seconds, self.videoTrimStart),
                        self.videoTrimEnd
                    )
                }
            }
        }
    }

    private func removeVideoTimeObserver() {
        if let videoTimeObserver, let videoPlayer {
            videoPlayer.removeTimeObserver(videoTimeObserver)
        }
        videoTimeObserver = nil
    }

    func presentPreviewWindow(repositionIfNeeded: Bool = true) {
        if let window = existingPreviewWindow() {
            if repositionIfNeeded {
                positionCompanion(window)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        openPreviewWindowAction?()
        NotificationCenter.default.post(name: .shotCaptureOpenPreview, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            if let window = self.existingPreviewWindow() {
                if repositionIfNeeded {
                    self.positionCompanion(window)
                }
                window.makeKeyAndOrderFront(nil)
                NSApp.activate()
            } else {
                self.openFallbackPreviewWindow(reposition: repositionIfNeeded)
            }
        }
    }

    func copyComposedToPasteboard() {
        guard let composedImage,
              let data = CompositionService.pngData(from: composedImage) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
        statusMessage = "Copied PNG"
    }

    func saveComposedImage() {
        if isEditingVideo {
            saveComposedVideo()
            return
        }
        guard let composedImage,
              let data = CompositionService.pngData(from: composedImage) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultFileName(extension: "png")
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                statusMessage = "Saved"
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func saveComposedVideo() {
        guard currentVideo != nil,
              !videoExportState.isExporting,
              recordingState == .idle else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = defaultFileName(extension: "mp4")
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await exportVideo(to: url, revealWhenFinished: true) }
    }

    private func exportVideo(to url: URL, revealWhenFinished: Bool) async {
        guard let video = currentVideo else { return }
        pauseVideo()
        videoExportCancellationRequested = false
        videoExportState = .exporting(progress: 0)
        lastError = nil
        statusMessage = "Exporting video…"

        let start = CMTime(seconds: videoTrimStart, preferredTimescale: 600)
        let end = CMTime(seconds: videoTrimEnd, preferredTimescale: 600)
        let range = CMTimeRange(start: start, end: end)
        let composition = makeVideoComposition(for: video)

        do {
            try await videoExportService.export(
                video: video,
                composition: composition,
                trimRange: range,
                to: url
            ) { [weak self] progress in
                self?.videoExportState = .exporting(progress: progress)
                self?.statusMessage = "Exporting \(Int((progress * 100).rounded()))%"
            }
            videoExportState = .idle
            statusMessage = "Saved video"
            if revealWhenFinished {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            if videoExportCancellationRequested || error is CancellationError {
                videoExportState = .idle
                statusMessage = "Export cancelled"
            } else {
                videoExportState = .failed(message: error.localizedDescription)
                lastError = error.localizedDescription
                statusMessage = "Export failed"
                NSSound.beep()
            }
        }
        videoExportCancellationRequested = false
    }

    func cancelVideoExport() {
        videoExportCancellationRequested = true
        videoExportService.cancel()
        statusMessage = "Cancelling export…"
    }

    func shutdown() {
        pauseVideo()
        removeVideoTimeObserver()
        videoExportService.cancel()
        if recordingState.isActive {
            Task { await recordingService.cancelRecording() }
        }
        if let securityScopedVideoURL {
            securityScopedVideoURL.stopAccessingSecurityScopedResource()
            self.securityScopedVideoURL = nil
        }
        if let currentVideo, currentVideo.deletesFileWhenReplaced {
            try? FileManager.default.removeItem(at: currentVideo.url)
        }
    }

    func saveToDownloads() {
        if isEditingVideo {
            guard !videoExportState.isExporting,
                  recordingState == .idle else { return }
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
            let url = downloads.appendingPathComponent(defaultFileName(extension: "mp4"))
            Task { await exportVideo(to: url, revealWhenFinished: true) }
            return
        }
        guard let composedImage,
              let data = CompositionService.pngData(from: composedImage) else { return }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let url = downloads.appendingPathComponent(defaultFileName(extension: "png"))
        do {
            try data.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            statusMessage = "Saved to Downloads"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func positionCompanion(_ window: NSWindow) {
        let frame = SimulatorWindowLocator.companionWindowFrame(
            preferredSize: CGSize(width: 780, height: 820)
        )
        window.setFrame(frame, display: true, animate: true)
    }

    private func resolvedUDID() -> String? {
        if let preferred = settings.preferredSimulatorUDID,
           bootedDevices.contains(where: { $0.udid == preferred }) {
            return preferred
        }
        return bootedDevices.first?.udid
    }

    private func requireDeveloperDirectory() -> URL? {
        if xcodeAccess.hasAccess,
           let developerDirectory = xcodeAccess.developerDirectoryURL {
            return developerDirectory
        }

        guard xcodeAccess.chooseXcode(),
              let developerDirectory = xcodeAccess.developerDirectoryURL else {
            lastError = xcodeAccess.lastError ?? "Choose Xcode before capturing a Simulator screenshot."
            statusMessage = "Xcode access required"
            return nil
        }
        return developerDirectory
    }

    private func existingPreviewWindow() -> NSWindow? {
        NSApplication.shared.windows.first(where: {
            $0.title == "ShotCapture Editor" ||
                $0.title == "Capture Preview" ||
                $0.identifier?.rawValue == "capture-preview"
        })
    }

    private func openFallbackPreviewWindow(reposition: Bool = true) {
        if let fallbackPreviewWindow {
            if reposition {
                positionCompanion(fallbackPreviewWindow)
            }
            fallbackPreviewWindow.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let root = CapturePreviewView()
            .environment(self)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "ShotCapture Editor"
        window.identifier = NSUserInterfaceItemIdentifier("capture-preview")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 780, height: 820))
        window.isReleasedWhenClosed = false
        fallbackPreviewWindow = window
        if reposition {
            positionCompanion(window)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func defaultFileName(extension fileExtension: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let platform = settings.selectedPlatform.rawValue
        return "ShotCapture-\(platform)-\(formatter.string(from: Date())).\(fileExtension)"
    }
}

extension Notification.Name {
    static let shotCaptureOpenPreview = Notification.Name("ShotCaptureOpenPreview")
}
