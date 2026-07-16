//
//  CapturePreviewView.swift
//  ShotCapture
//

import AppKit
import SwiftUI

struct CapturePreviewView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        @Bindable var settings = app.settings

        VStack(spacing: 0) {
            toolbar
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)

            Divider()

            previewArea
                .frame(minHeight: 180)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)

            Divider()

            controls
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)
        }
        .frame(minWidth: 420, idealWidth: 440, minHeight: 560)
        .background(.background)
        .onChange(of: settings.selectedPlatform) { _, _ in app.recompose() }
        .onChange(of: settings.selectedBackgroundID) { _, _ in app.recompose() }
        .onChange(of: settings.paddingPercent) { _, _ in app.recompose() }
        .onChange(of: settings.deviceCornerRadius) { _, _ in app.recompose() }
        .onChange(of: settings.showDeviceShadow) { _, _ in app.recompose() }
        .onChange(of: settings.watermarkEnabled) { _, _ in app.recompose() }
        .onChange(of: settings.watermarkText) { _, _ in app.recompose() }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Label(app.settings.selectedPlatform.displayName, systemImage: app.settings.selectedPlatform.systemImage)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                Task { await app.recaptureKeepingWindowPlace() }
            } label: {
                Label("Recapture", systemImage: "arrow.clockwise")
            }
            .disabled(app.isCapturing)
            .help("Capture again without moving this window")

            Button {
                app.copyComposedToPasteboard()
            } label: {
                Label("Copy", systemImage: "doc.on.clipboard")
            }
            .disabled(app.composedImage == nil)
            .keyboardShortcut("c", modifiers: [.command])

            Button {
                app.saveComposedImage()
            } label: {
                Label("Save…", systemImage: "square.and.arrow.down")
            }
            .disabled(app.composedImage == nil)
            .keyboardShortcut("s", modifiers: [.command])

            Button {
                app.saveToDownloads()
            } label: {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            .disabled(app.composedImage == nil)
            .labelStyle(.iconOnly)
            .help("Save to Downloads")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var previewArea: some View {
        GeometryReader { geo in
            ZStack {
                BackgroundCanvas(style: app.settings.selectedBackground)
                    .opacity(0.35)
                    .blur(radius: 24)
                    .frame(width: geo.size.width, height: geo.size.height)

                if let composed = app.composedImage {
                    Image(nsImage: composed)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: max(0, geo.size.width - 32),
                            maxHeight: max(0, geo.size.height - 32)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                        .animation(.easeOut(duration: 0.2), value: composed.size)
                } else if app.isCapturing {
                    ProgressView("Capturing simulator…")
                } else {
                    ContentUnavailableView(
                        "No Capture Yet",
                        systemImage: "iphone.gen3",
                        description: Text(
                            "Capture from the menu bar or press \(HotkeyService.displayString(keyCode: app.settings.hotkeyKeyCode, modifiers: app.settings.hotkeyModifiers))."
                        )
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
    }

    private var controls: some View {
        @Bindable var settings = app.settings

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("Platform", selection: $settings.selectedPlatform) {
                    ForEach(SocialPlatform.allCases) { platform in
                        Text(platform.displayName).tag(platform)
                    }
                }
                .labelsHidden()
                .fixedSize()

                Text(settings.selectedPlatform.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(settings.allBackgrounds) { style in
                        BackgroundThumb(
                            style: style,
                            isSelected: settings.selectedBackgroundID == style.id
                        ) {
                            settings.selectedBackgroundID = style.id
                        }
                    }
                }
            }
            .frame(height: 44)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Padding")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.paddingPercent, in: 0.04...0.22)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Corners")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.deviceCornerRadius, in: 0...80)
                }
            }

            HStack(spacing: 12) {
                Toggle("Shadow", isOn: $settings.showDeviceShadow)
                Toggle("Watermark", isOn: $settings.watermarkEnabled)
                if settings.watermarkEnabled {
                    TextField("Watermark", text: $settings.watermarkText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct BackgroundThumb: View {
    let style: BackgroundStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BackgroundCanvas(style: style)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.white.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .help(style.name)
    }
}
