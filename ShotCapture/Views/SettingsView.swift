//
//  SettingsView.swift
//  ShotCapture
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppController.self) private var app
    @State private var isRecordingHotkey = false
    @State private var showGradientEditor = false
    @State private var accessibilityTrusted = PermissionService.isAccessibilityTrusted

    var body: some View {
        @Bindable var settings = app.settings

        TabView {
            Tab("General", systemImage: "gearshape") {
                Form {
                    Section("Capture") {
                        Picker("Default platform", selection: $settings.selectedPlatform) {
                            ForEach(SocialPlatform.allCases) { platform in
                                Text(platform.displayName).tag(platform)
                            }
                        }

                        LabeledContent("Output size") {
                            let size = settings.selectedPlatform.canvasSize
                            Text("\(Int(size.width))×\(Int(size.height))")
                                .foregroundStyle(.secondary)
                        }

                        Toggle("Device shadow", isOn: $settings.showDeviceShadow)
                        Toggle("Watermark", isOn: $settings.watermarkEnabled)
                        if settings.watermarkEnabled {
                            TextField("Watermark text", text: $settings.watermarkText)
                        }
                    }

                    Section("Simulator") {
                        Text("Uses the active Xcode command-line tools selected on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if app.bootedDevices.isEmpty {
                            Text("No booted simulators")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Preferred device", selection: $settings.preferredSimulatorUDID) {
                                Text("Automatic").tag(String?.none)
                                ForEach(app.bootedDevices) { device in
                                    Text("\(device.name) (\(device.runtime))").tag(Optional(device.udid))
                                }
                            }
                        }

                        Button("Refresh") {
                            Task { await app.refreshDevices() }
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
            }

            Tab("Keyboard", systemImage: "keyboard") {
                Form {
                    Section("Global shortcut") {
                        HStack {
                            Text("Capture shortcut")
                            Spacer()
                            Text(HotkeyService.displayString(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers))
                                .font(.body.monospaced())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }

                        if isRecordingHotkey {
                            Text("Press the new shortcut…")
                                .foregroundStyle(.secondary)
                                .onAppear { /* focus handled by key monitor below */ }
                        }

                        Button(isRecordingHotkey ? "Listening…" : "Record Shortcut") {
                            isRecordingHotkey.toggle()
                        }
                        .keyboardShortcut(.defaultAction)

                        Button("Reset to ⌘⇧S") {
                            settings.hotkeyKeyCode = 1
                            settings.hotkeyModifiers = NSEvent.ModifierFlags([.command, .shift]).rawValue
                            app.refreshHotkey()
                            isRecordingHotkey = false
                        }
                    }

                    Section("Accessibility") {
                        LabeledContent("Permission") {
                            Text(accessibilityTrusted ? "Granted" : "Required for global hotkey")
                                .foregroundStyle(accessibilityTrusted ? .green : .orange)
                        }

                        if !accessibilityTrusted {
                            Text("Menu bar capture works without Accessibility. Global hotkeys need it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Request Accessibility…") {
                                PermissionService.requestAccessibility(prompt: true)
                                accessibilityTrusted = PermissionService.isAccessibilityTrusted
                            }

                            Button("Open System Settings") {
                                PermissionService.openAccessibilitySettings()
                            }
                        }

                        Button("Recheck") {
                            accessibilityTrusted = PermissionService.isAccessibilityTrusted
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
                .background {
                    HotkeyRecorder(isRecording: $isRecordingHotkey) { keyCode, modifiers in
                        settings.hotkeyKeyCode = keyCode
                        settings.hotkeyModifiers = modifiers.rawValue
                        app.refreshHotkey()
                        isRecordingHotkey = false
                    }
                }
            }

            Tab("Backgrounds", systemImage: "paintpalette") {
                BackgroundsSettingsView(showGradientEditor: $showGradientEditor)
            }

            Tab("Permissions", systemImage: "lock.shield") {
                Form {
                    Section("Accessibility") {
                        LabeledContent("Permission") {
                            Text(accessibilityTrusted ? "Granted" : "Optional (global hotkey)")
                                .foregroundStyle(accessibilityTrusted ? .green : .secondary)
                        }

                        Button("Request Accessibility…") {
                            PermissionService.requestAccessibility(prompt: true)
                            accessibilityTrusted = PermissionService.isAccessibilityTrusted
                        }

                        Button("Open System Settings") {
                            PermissionService.openAccessibilitySettings()
                        }
                    }

                    Section("Capture requirements") {
                        Text(PermissionService.permissionSummary)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
                .formStyle(.grouped)
                .padding()
            }
        }
        .frame(width: 560, height: 480)
        .sheet(isPresented: $showGradientEditor) {
            GradientEditorView { style in
                app.settings.addCustomBackground(style)
                app.recompose()
                showGradientEditor = false
            } onCancel: {
                showGradientEditor = false
            }
        }
        .onAppear {
            accessibilityTrusted = PermissionService.isAccessibilityTrusted
            Task { await app.refreshDevices() }
        }
    }
}

private struct HotkeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onRecord = onRecord
        view.isRecording = isRecording
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onRecord = onRecord
    }

    final class RecorderView: NSView {
        var isRecording = false
        var onRecord: ((UInt16, NSEvent.ModifierFlags) -> Void)?
        private var monitor: Any?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !mods.isEmpty else { return }
            onRecord?(event.keyCode, mods)
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
