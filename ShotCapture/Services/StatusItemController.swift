//
//  StatusItemController.swift
//  ShotCapture
//

import AppKit
import SwiftUI

/// AppKit status item — more reliable than SwiftUI `MenuBarExtra` on menu-bar agent apps.
@MainActor
final class StatusItemController: NSObject {
    private let appController: AppController
    private let campaignController: AppStoreCampaignController
    private var statusItem: NSStatusItem?
    private var previewWindow: NSWindow?
    private var campaignWindow: NSWindow?

    init(appController: AppController) {
        self.appController = appController
        self.campaignController = AppStoreCampaignController(appController: appController)
        super.init()
    }

    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ShotCapture")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "ShotCapture"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusItem = item
        rebuildMenu()

        // Keep menu labels fresh when devices / status change.
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildMenu()
            }
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let openCampaign = NSMenuItem(
            title: "App Store Campaigns",
            action: #selector(openCampaignClicked),
            keyEquivalent: "n"
        )
        openCampaign.keyEquivalentModifierMask = [.command, .shift]
        openCampaign.target = self
        menu.addItem(openCampaign)

        let openEditor = NSMenuItem(
            title: "Quick Editor",
            action: #selector(openEditorClicked),
            keyEquivalent: "n"
        )
        openEditor.keyEquivalentModifierMask = [.command]
        openEditor.target = self
        menu.addItem(openEditor)

        let capture = NSMenuItem(
            title: appController.isCapturing ? "Capturing…" : "Capture Simulator Still",
            action: #selector(captureClicked),
            keyEquivalent: "s"
        )
        capture.keyEquivalentModifierMask = [.command, .shift]
        capture.target = self
        capture.isEnabled = !appController.isCapturing &&
            !appController.recordingState.isActive &&
            !appController.videoExportState.isExporting
        menu.addItem(capture)

        let record = NSMenuItem(
            title: recordingMenuTitle,
            action: #selector(recordClicked),
            keyEquivalent: "r"
        )
        record.keyEquivalentModifierMask = [.command, .shift]
        record.target = self
        record.isEnabled = !appController.isCapturing &&
            !appController.videoExportState.isExporting &&
            appController.recordingState != .starting &&
            appController.recordingState != .finalizing
        menu.addItem(record)

        if appController.bootedDevices.isEmpty {
            let none = NSMenuItem(title: "No simulator booted", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            let simMenu = NSMenu()
            let automatic = NSMenuItem(title: "Automatic", action: #selector(selectSimulator(_:)), keyEquivalent: "")
            automatic.target = self
            automatic.representedObject = ""
            automatic.state = appController.settings.preferredSimulatorUDID == nil ? .on : .off
            simMenu.addItem(automatic)

            for device in appController.bootedDevices {
                let item = NSMenuItem(
                    title: "\(device.name) · \(device.runtime)",
                    action: #selector(selectSimulator(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = device.udid
                item.state = appController.settings.preferredSimulatorUDID == device.udid ? .on : .off
                simMenu.addItem(item)
            }

            let simRoot = NSMenuItem(title: "Simulator", action: nil, keyEquivalent: "")
            simRoot.submenu = simMenu
            menu.addItem(simRoot)
        }

        menu.addItem(.separator())

        let platformMenu = NSMenu()
        for platform in SocialPlatform.allCases {
            let item = NSMenuItem(title: platform.displayName, action: #selector(selectPlatform(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = platform.rawValue
            item.state = appController.settings.selectedPlatform == platform ? .on : .off
            platformMenu.addItem(item)
        }
        let platformRoot = NSMenuItem(title: "Platform", action: nil, keyEquivalent: "")
        platformRoot.submenu = platformMenu
        menu.addItem(platformRoot)

        let backgroundMenu = NSMenu()
        for style in appController.settings.allBackgrounds {
            let item = NSMenuItem(title: style.name, action: #selector(selectBackground(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.id.uuidString
            item.state = appController.settings.selectedBackgroundID == style.id ? .on : .off
            backgroundMenu.addItem(item)
        }
        let backgroundRoot = NSMenuItem(
            title: "Background · \(appController.settings.selectedBackground.name)",
            action: nil,
            keyEquivalent: ""
        )
        backgroundRoot.submenu = backgroundMenu
        menu.addItem(backgroundRoot)

        let watermark = NSMenuItem(title: "Watermark", action: #selector(toggleWatermark), keyEquivalent: "")
        watermark.target = self
        watermark.state = appController.settings.watermarkEnabled ? .on : .off
        menu.addItem(watermark)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh Simulators", action: #selector(refreshSimulators), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)

        let status = NSMenuItem(title: appController.statusMessage, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if let error = appController.lastError {
            let err = NSMenuItem(title: error, action: nil, keyEquivalent: "")
            err.isEnabled = false
            menu.addItem(err)
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit ShotCapture", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func openCampaignClicked() {
        showCampaignWindow()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        // Menu is assigned to statusItem.menu, so AppKit opens it automatically.
        rebuildMenu()
    }

    @objc private func openEditorClicked() {
        showPreviewWindow(reposition: false)
    }

    @objc private func captureClicked() {
        Task {
            await appController.captureAndShowPreview()
            rebuildMenu()
        }
    }

    @objc private func recordClicked() {
        Task {
            await appController.toggleSimulatorRecording()
            rebuildMenu()
        }
    }

    @objc private func selectSimulator(_ sender: NSMenuItem) {
        let value = sender.representedObject as? String ?? ""
        appController.settings.preferredSimulatorUDID = value.isEmpty ? nil : value
        rebuildMenu()
    }

    @objc private func selectPlatform(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let platform = SocialPlatform(rawValue: raw) else { return }
        appController.settings.selectedPlatform = platform
        appController.recompose()
        rebuildMenu()
    }

    @objc private func selectBackground(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw) else { return }
        appController.settings.selectedBackgroundID = id
        appController.recompose()
        rebuildMenu()
    }

    @objc private func toggleWatermark() {
        appController.settings.watermarkEnabled.toggle()
        appController.recompose()
        rebuildMenu()
    }

    @objc private func refreshSimulators() {
        Task {
            await appController.refreshDevices()
            rebuildMenu()
        }
    }

    @objc private func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // Fallback for older selector names
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if NSApp.windows.contains(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
                return
            }
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func showPreviewWindow(reposition: Bool = false) {
        appController.recompose()

        if let previewWindow {
            if reposition {
                appController.positionCompanion(previewWindow)
            }
            NSApp.activate()
            previewWindow.makeKeyAndOrderFront(nil)
            previewWindow.orderFrontRegardless()
            return
        }

        let root = CapturePreviewView()
            .environment(appController)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "ShotCapture Editor"
        window.identifier = NSUserInterfaceItemIdentifier("capture-preview")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 440, height: 760))
        window.minSize = NSSize(width: 380, height: 520)
        window.isReleasedWhenClosed = false
        window.delegate = self
        previewWindow = window

        if reposition {
            appController.positionCompanion(window)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func showCampaignWindow() {
        if let campaignWindow {
            NSApp.activate()
            campaignWindow.makeKeyAndOrderFront(nil)
            campaignWindow.orderFrontRegardless()
            return
        }

        let root = AppStoreCampaignView()
            .environment(campaignController)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "ShotCapture · App Store Campaigns"
        window.identifier = NSUserInterfaceItemIdentifier("app-store-campaign")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 1_320, height: 860))
        window.minSize = NSSize(width: 1_080, height: 720)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        campaignWindow = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private var recordingMenuTitle: String {
        switch appController.recordingState {
        case .idle: "Record Simulator Video"
        case .starting: "Starting Recording…"
        case .recording: "Stop Simulator Recording"
        case .finalizing: "Finalizing Recording…"
        }
    }
}

extension StatusItemController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Keep reference; window isReleasedWhenClosed = false so we can reopen.
    }
}
