//
//  AppController.swift
//  ShotCapture
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class AppController {
    let settings = AppSettings()
    let captureService = SimulatorCaptureService()
    let hotkeyService = HotkeyService()
    let xcodeAccess = XcodeAccessService()

    var bootedDevices: [SimulatorDevice] = []
    var isCapturing = false
    var lastError: String?
    var rawScreenshot: NSImage?
    var composedImage: NSImage?
    var importedProductBezels: [ImportedProductBezel] = []
    var selectedProductBezelID: UUID?
    var statusMessage: String = "Ready"

    /// Stored from SwiftUI so we can open the Window scene from hotkeys.
    var openPreviewWindowAction: (() -> Void)?

    private var fallbackPreviewWindow: NSWindow?

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
            statusMessage = "Choose Xcode in Settings"
            return
        }

        do {
            bootedDevices = try await captureService.listBootedDevices(
                developerDirectory: developerDirectory
            )
            if bootedDevices.isEmpty {
                statusMessage = "No simulator booted"
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
        guard !isCapturing else { return }
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
            rawScreenshot = image
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
        guard !isCapturing else { return }
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
            rawScreenshot = image
            recompose()
            presentPreviewWindow(repositionIfNeeded: false)
            statusMessage = "Captured"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Capture failed"
            NSSound.beep()
        }
    }

    func recompose() {
        guard let rawScreenshot else { return }
        composedImage = CompositionService.compose(
            CompositionRequest(
                screenshot: rawScreenshot,
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
                importedBezelInset: settings.importedBezelInset,
                deviceDepthRatio: activeDeviceDepthRatio,
                deviceEdgeTint: activeDeviceEdgeTint,
                titleEnabled: settings.titleEnabled,
                titleText: settings.titleText,
                titleFontName: settings.titleFontName,
                titleFontSize: settings.titleFontSize,
                titleTransform: settings.titleTransform
            )
        )
    }

    var selectedProductBezel: ImportedProductBezel? {
        guard let selectedProductBezelID else { return importedProductBezels.first }
        return importedProductBezels.first(where: { $0.id == selectedProductBezelID })
    }

    private var activeProductBezelImage: NSImage? {
        switch settings.deviceFrameStyle {
        case .appleProductBezel:
            guard let rawScreenshot else { return nil }
            let resourceName = settings.productBezelDevice.resourceName(
                finish: settings.productBezelFinish,
                isLandscape: rawScreenshot.size.width > rawScreenshot.size.height
            )
            let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: "png",
                subdirectory: "ProductBezels"
            ) ?? Bundle.main.url(forResource: resourceName, withExtension: "png")
            return url.flatMap(NSImage.init(contentsOf:))
        case .importedProductBezel:
            return selectedProductBezel?.image
        case .none, .genericPhone:
            return nil
        }
    }

    private var activeProductBezelAperture: CGRect? {
        guard settings.deviceFrameStyle == .appleProductBezel,
              let rawScreenshot else { return nil }
        return settings.productBezelDevice.screenAperture(
            isLandscape: rawScreenshot.size.width > rawScreenshot.size.height
        )
    }

    private var activeDeviceDepthRatio: Double {
        if settings.deviceFrameStyle == .appleProductBezel {
            settings.productBezelDevice.thicknessToWidthRatio
        } else {
            0.11
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
        guard let image = NSImage(pasteboard: .general) else {
            lastError = "The clipboard does not contain an image."
            statusMessage = "No image on clipboard"
            NSSound.beep()
            return
        }
        useScreenshot(image, status: "Pasted image")
    }

    func importScreenshot() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an iPhone screenshot or another image to compose."

        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url) else { return }
        useScreenshot(image, status: "Imported \(url.lastPathComponent)")
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
        rawScreenshot = image
        settings.screenshotTransform = .screenshotDefault
        recompose()
        presentPreviewWindow(repositionIfNeeded: false)
        statusMessage = status
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
        guard let composedImage,
              let data = CompositionService.pngData(from: composedImage) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultFileName()
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

    func saveToDownloads() {
        guard let composedImage,
              let data = CompositionService.pngData(from: composedImage) else { return }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let url = downloads.appendingPathComponent(defaultFileName())
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
            $0.title == "Capture Preview" || $0.identifier?.rawValue == "capture-preview"
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
        window.title = "Capture Preview"
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

    private func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let platform = settings.selectedPlatform.rawValue
        return "ShotCapture-\(platform)-\(formatter.string(from: Date())).png"
    }
}

extension Notification.Name {
    static let shotCaptureOpenPreview = Notification.Name("ShotCaptureOpenPreview")
}
