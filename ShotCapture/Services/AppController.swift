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

    var bootedDevices: [SimulatorDevice] = []
    var isCapturing = false
    var lastError: String?
    var rawScreenshot: NSImage?
    var composedImage: NSImage?
    var statusMessage: String = "Ready"

    /// Stored from SwiftUI so we can open the Window scene from hotkeys.
    var openPreviewWindowAction: (() -> Void)?

    private var fallbackPreviewWindow: NSWindow?

    init() {
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
        do {
            bootedDevices = try await captureService.listBootedDevices()
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
        isCapturing = true
        lastError = nil
        statusMessage = "Capturing…"
        defer { isCapturing = false }

        do {
            await refreshDevices()
            let udid = resolvedUDID()
            let image = try await captureService.captureScreenshot(udid: udid)
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
        isCapturing = true
        lastError = nil
        statusMessage = "Capturing…"
        defer { isCapturing = false }

        do {
            await refreshDevices()
            let udid = resolvedUDID()
            let image = try await captureService.captureScreenshot(udid: udid)
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
                watermarkText: settings.watermarkText
            )
        )
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
            preferredSize: CGSize(width: 440, height: 760)
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
        window.setContentSize(NSSize(width: 440, height: 760))
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
