//
//  ShotCaptureApp.swift
//  ShotCapture
//
//  Created by Karmjit Singh on 11/7/2026.
//

import AppKit
import SwiftUI

@main
struct ShotCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings is the only SwiftUI scene. The menu bar item is AppKit NSStatusItem
        // (MenuBarExtra was not receiving clicks reliably as an LSUIElement agent).
        Settings {
            SettingsView()
                .environment(appDelegate.appController)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appController = AppController()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Remove the unused main-menu app chrome so we don't look like a normal app
        // without a visible window.
        NSApp.mainMenu = NSMenu()

        let status = StatusItemController(appController: appController)
        status.install()
        statusItemController = status

        // Expose preview opener used by hotkeys / controller fallbacks.
        appController.openPreviewWindowAction = { [weak status] in
            // First open docks beside Simulator; later opens keep place.
            status?.showPreviewWindow(reposition: false)
        }

        Task { @MainActor in
            await appController.refreshDevices()
            status.rebuildMenu()
            // ShotCapture now has a document-style primary workspace. Showing it
            // on launch also gives users a visible recovery path if macOS hides
            // or crowds the status item.
            status.showCampaignWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        appController.shutdown()
    }
}
