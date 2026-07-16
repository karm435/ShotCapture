//
//  MenuBarView.swift
//  ShotCapture
//

import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var app: AppController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var settings = app.settings

        Button {
            Task { await app.captureAndShowPreview() }
        } label: {
            Text(app.isCapturing ? "Capturing…" : "Capture Simulator")
        }
        .keyboardShortcut("s", modifiers: [.command, .shift])
        .disabled(app.isCapturing)

        if app.bootedDevices.isEmpty {
            Text("No simulator booted")
        } else {
            Picker("Simulator", selection: Binding(
                get: { settings.preferredSimulatorUDID ?? "" },
                set: { settings.preferredSimulatorUDID = $0.isEmpty ? nil : $0 }
            )) {
                Text("Automatic").tag("")
                ForEach(app.bootedDevices) { device in
                    Text("\(device.name) · \(device.runtime)").tag(device.udid)
                }
            }
        }

        Divider()

        Picker("Platform", selection: $settings.selectedPlatform) {
            ForEach(SocialPlatform.allCases) { platform in
                Text(platform.displayName).tag(platform)
            }
        }

        Menu("Background · \(settings.selectedBackground.name)") {
            ForEach(BackgroundStyle.presets) { style in
                Button(style.name) {
                    settings.selectedBackgroundID = style.id
                    app.recompose()
                }
            }

            if !settings.customBackgrounds.isEmpty {
                Divider()
                ForEach(settings.customBackgrounds) { style in
                    Button(style.name) {
                        settings.selectedBackgroundID = style.id
                        app.recompose()
                    }
                }
            }
        }

        Toggle("Watermark", isOn: $settings.watermarkEnabled)

        Divider()

        Button("Open Preview Window") {
            app.presentPreviewWindow()
        }
        .disabled(app.composedImage == nil && app.rawScreenshot == nil)

        Button("Refresh Simulators") {
            Task { await app.refreshDevices() }
        }

        Text(app.statusMessage)

        Divider()

        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: [.command])

        Button("Quit ShotCapture") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }
}
