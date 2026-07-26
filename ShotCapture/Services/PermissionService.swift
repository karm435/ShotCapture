//
//  PermissionService.swift
//  ShotCapture
//

import ApplicationServices
import AppKit
import Foundation

@MainActor
enum PermissionService {
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibility(prompt: Bool = true) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static var permissionSummary: String {
        """
        Simulator capture requirements:

        1. Xcode and its command-line tools.
        2. A booted iOS Simulator.
        3. Accessibility — optional; only for the global keyboard shortcut.

        The editor, media import, clipboard paste, and export work without Xcode or Simulator.
        Simulator stills and video use xcrun simctl and do not require Screen Recording access.
        Simulator video is silent; imported video audio is preserved.
        """
    }
}
