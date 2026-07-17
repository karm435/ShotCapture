//
//  CapturePreviewView.swift
//  ShotCapture
//

import AppKit
import SwiftUI

struct CapturePreviewView: View {
    @Environment(AppController.self) private var app
    @State private var selectedElement: EditorElement = .screenshot
    @State private var screenshotDragStart: CanvasElementTransform?
    @State private var titleDragStart: CanvasElementTransform?
    @State private var gestureScaleStart: Double?
    @State private var gestureRotationStart: Double?

    var body: some View {
        let compositionState = CompositionState(
            settings: app.settings,
            selectedProductBezelID: app.selectedProductBezelID
        )

        return VStack(spacing: 0) {
            toolbar
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)

            Divider()

            previewArea
                .frame(minHeight: 300)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            controls
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)
        }
        .frame(minWidth: 680, idealWidth: 780, minHeight: 700, idealHeight: 820)
        .background(.background)
        .onChange(of: compositionState) { _, _ in app.recompose() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Label(app.settings.selectedPlatform.displayName, systemImage: app.settings.selectedPlatform.systemImage)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                app.importScreenshot()
            } label: {
                Label("Import…", systemImage: "photo.badge.plus")
            }

            Button {
                app.pasteScreenshot()
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: [.command])

            Button {
                Task { await app.recaptureKeepingWindowPlace() }
            } label: {
                Label("Recapture", systemImage: "arrow.clockwise")
            }
            .disabled(app.isCapturing)

            Button {
                app.copyComposedToPasteboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
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
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var previewArea: some View {
        GeometryReader { geometry in
            ZStack {
                BackgroundCanvas(style: app.settings.selectedBackground)
                    .opacity(0.35)
                    .blur(radius: 24)

                if let composed = app.composedImage {
                    let displaySize = fittedSize(
                        content: composed.size,
                        available: CGSize(
                            width: max(0, geometry.size.width - 32),
                            height: max(0, geometry.size.height - 32)
                        )
                    )
                    editorCanvas(composed: composed, displaySize: displaySize)
                } else if app.isCapturing {
                    ProgressView("Capturing simulator…")
                } else {
                    ContentUnavailableView {
                        Label("Add an iPhone Screenshot", systemImage: "iphone.gen3")
                    } description: {
                        Text("Capture a booted Simulator, import an image, or paste from the clipboard.")
                    } actions: {
                        HStack {
                            Button("Import Image…") { app.importScreenshot() }
                            Button("Paste Image") { app.pasteScreenshot() }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
    }

    private func editorCanvas(composed: NSImage, displaySize: CGSize) -> some View {
        ZStack {
            Image(nsImage: composed)
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 20, y: 8)

            if app.settings.titleEnabled, !app.settings.titleText.isEmpty {
                titleHitTarget(displaySize: displaySize, canvasSize: composed.size)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .contentShape(Rectangle())
        .onTapGesture { selectedElement = .screenshot }
        .gesture(screenshotDragGesture(displaySize: displaySize))
        .simultaneousGesture(magnifyGesture)
        .simultaneousGesture(rotationGesture)
        .twoFingerTiltGesture(
            isEnabled: selectedElement == .screenshot,
            onDelta: applyTwoFingerTilt
        )
        .accessibilityLabel("Screenshot composition canvas")
        .accessibilityHint("Drag to move, pinch to resize, twist to rotate around Z, or pan with two fingers to tilt in 3D.")
    }

    private func titleHitTarget(displaySize: CGSize, canvasSize: CGSize) -> some View {
        let transform = app.settings.titleTransform
        let previewScale = displaySize.width / canvasSize.width
        let fontSize = max(10, app.settings.titleFontSize * transform.scale * previewScale)

        return Text(app.settings.titleText)
            .font(.custom(app.settings.titleFontName, size: fontSize))
            .foregroundStyle(.clear)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(8)
            .contentShape(Rectangle())
            .overlay {
                if selectedElement == .title {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            .rotationEffect(.degrees(transform.rotationDegrees))
            .position(
                x: displaySize.width / 2 + displaySize.width * transform.offsetX,
                y: displaySize.height / 2 + displaySize.height * transform.offsetY
            )
            .highPriorityGesture(titleDragGesture(displaySize: displaySize))
            .highPriorityGesture(TapGesture().onEnded { selectedElement = .title })
            .accessibilityLabel("Title")
            .accessibilityHint("Drag to reposition the title")
    }

    private func screenshotDragGesture(displaySize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard selectedElement == .screenshot else { return }
                let start = screenshotDragStart ?? app.settings.screenshotTransform
                screenshotDragStart = start
                var transform = start
                transform.offsetX = start.offsetX + value.translation.width / displaySize.width
                transform.offsetY = start.offsetY + value.translation.height / displaySize.height
                app.settings.screenshotTransform = transform
            }
            .onEnded { _ in screenshotDragStart = nil }
    }

    private func titleDragGesture(displaySize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                selectedElement = .title
                let start = titleDragStart ?? app.settings.titleTransform
                titleDragStart = start
                var transform = start
                transform.offsetX = start.offsetX + value.translation.width / displaySize.width
                transform.offsetY = start.offsetY + value.translation.height / displaySize.height
                app.settings.titleTransform = transform
            }
            .onEnded { _ in titleDragStart = nil }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let current = transform(for: selectedElement)
                let start = gestureScaleStart ?? current.scale
                gestureScaleStart = start
                updateTransform(for: selectedElement) { transform in
                    transform.scale = min(max(start * value.magnification, 0.25), 3)
                }
            }
            .onEnded { _ in gestureScaleStart = nil }
    }

    private var rotationGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                let current = transform(for: selectedElement)
                let start = gestureRotationStart ?? current.rotationDegrees
                gestureRotationStart = start
                updateTransform(for: selectedElement) { transform in
                    transform.rotationDegrees = min(max(start + value.rotation.degrees, -45), 45)
                }
            }
            .onEnded { _ in gestureRotationStart = nil }
    }

    private func applyTwoFingerTilt(_ delta: CGSize) {
        guard selectedElement == .screenshot else { return }
        let sensitivity = 0.14
        var transform = app.settings.screenshotTransform
        transform.tiltXDegrees = min(max(
            transform.tiltXDegrees - delta.height * sensitivity,
            -45
        ), 45)
        transform.tiltYDegrees = min(max(
            transform.tiltYDegrees + delta.width * sensitivity,
            -45
        ), 45)
        app.settings.screenshotTransform = transform
    }

    private var controls: some View {
        @Bindable var settings = app.settings

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Picker("Platform", selection: $settings.selectedPlatform) {
                        ForEach(SocialPlatform.allCases) { platform in
                            Text(platform.displayName).tag(platform)
                        }
                    }
                    .fixedSize()

                    Picker("Edit", selection: $selectedElement) {
                        ForEach(EditorElement.allCases) { element in
                            Text(element.displayName).tag(element)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)

                    Spacer()

                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        app.resetCanvas()
                    }
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
                    LabeledSlider(
                        title: "Scale",
                        value: activeScaleBinding,
                        range: 0.25...3
                    )
                    LabeledSlider(
                        title: "Rotate Z",
                        value: activeRotationBinding,
                        range: -45...45,
                        suffix: "°"
                    )

                    LabeledSlider(
                        title: "Padding",
                        value: $settings.paddingPercent,
                        range: 0.04...0.22
                    )
                }

                if selectedElement == .screenshot {
                    HStack(spacing: 16) {
                        LabeledSlider(
                            title: "Tilt X",
                            value: screenshotTiltXBinding,
                            range: -45...45,
                            suffix: "°"
                        )
                        LabeledSlider(
                            title: "Tilt Y",
                            value: screenshotTiltYBinding,
                            range: -45...45,
                            suffix: "°"
                        )
                        LabeledSlider(
                            title: "Depth",
                            value: screenshotDepthBinding,
                            range: 0...2,
                            suffix: "×"
                        )
                        .help("1× uses the selected iPhone's physical depth-to-width ratio")
                        Spacer()
                    }
                }

                frameControls
                titleControls

                HStack(spacing: 12) {
                    Toggle("Shadow", isOn: $settings.showDeviceShadow)
                    Toggle("Watermark", isOn: $settings.watermarkEnabled)
                    if settings.watermarkEnabled {
                        TextField("Watermark", text: $settings.watermarkText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 180)
                    }
                    Spacer()
                    Text(app.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: 370)
        .background(.bar)
    }

    private var frameControls: some View {
        @Bindable var settings = app.settings

        return HStack(spacing: 12) {
            Picker("Device frame", selection: $settings.deviceFrameStyle) {
                ForEach(DeviceFrameStyle.availableCases) { style in
                    Text(style.displayName).tag(style)
                        .disabled(style == .importedProductBezel && app.importedProductBezels.isEmpty)
                }
            }
            .fixedSize()

            if settings.deviceFrameStyle == .appleProductBezel {
                Picker("Device", selection: $settings.productBezelDevice) {
                    ForEach(ProductBezelDevice.allCases) { device in
                        Text(device.displayName).tag(device)
                    }
                }
                .frame(maxWidth: 180)

                Picker("Finish", selection: $settings.productBezelFinish) {
                    ForEach(settings.productBezelDevice.finishes, id: \.self) { finish in
                        Text(finish).tag(finish)
                    }
                }
                .frame(maxWidth: 180)
            } else if settings.deviceFrameStyle == .importedProductBezel {
                Picker("Bezel", selection: Binding(
                    get: { app.selectedProductBezelID },
                    set: { app.selectedProductBezelID = $0 }
                )) {
                    ForEach(app.importedProductBezels) { bezel in
                        Text(bezel.name).tag(Optional(bezel.id))
                    }
                }
                .frame(maxWidth: 220)

                LabeledSlider(
                    title: "Screen inset",
                    value: $settings.importedBezelInset,
                    range: 0...0.14
                )
            }

            Spacer()

            Button("Import Bezels…") { app.importProductBezels() }
            Button("Apple Resources", systemImage: "arrow.up.right.square") {
                app.openAppleBezelResources()
            }
            .help("Download product bezels from Apple and accept Apple's license before importing")
        }
    }

    private var titleControls: some View {
        @Bindable var settings = app.settings

        return HStack(spacing: 12) {
            Toggle("Title", isOn: $settings.titleEnabled)

            if settings.titleEnabled {
                TextField("Title text", text: $settings.titleText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...2)
                    .frame(maxWidth: 280)

                Picker("Font", selection: $settings.titleFontName) {
                    ForEach(SystemFontCatalog.installed) { font in
                        Text(font.displayName)
                            .font(.custom(font.postScriptName, size: 13))
                            .tag(font.postScriptName)
                    }
                }
                .frame(maxWidth: 220)

                LabeledSlider(
                    title: "Size",
                    value: $settings.titleFontSize,
                    range: 28...160
                )
            }
        }
    }

    private var activeScaleBinding: Binding<Double> {
        Binding(
            get: { transform(for: selectedElement).scale },
            set: { newValue in
                updateTransform(for: selectedElement) { $0.scale = newValue }
            }
        )
    }

    private var activeRotationBinding: Binding<Double> {
        Binding(
            get: { transform(for: selectedElement).rotationDegrees },
            set: { newValue in
                updateTransform(for: selectedElement) { $0.rotationDegrees = newValue }
            }
        )
    }

    private var screenshotTiltXBinding: Binding<Double> {
        Binding(
            get: { app.settings.screenshotTransform.tiltXDegrees },
            set: { newValue in
                updateTransform(for: .screenshot) { $0.tiltXDegrees = newValue }
            }
        )
    }

    private var screenshotTiltYBinding: Binding<Double> {
        Binding(
            get: { app.settings.screenshotTransform.tiltYDegrees },
            set: { newValue in
                updateTransform(for: .screenshot) { $0.tiltYDegrees = newValue }
            }
        )
    }

    private var screenshotDepthBinding: Binding<Double> {
        Binding(
            get: { app.settings.screenshotTransform.depthScale },
            set: { newValue in
                updateTransform(for: .screenshot) { $0.depthScale = newValue }
            }
        )
    }

    private func transform(for element: EditorElement) -> CanvasElementTransform {
        switch element {
        case .screenshot: app.settings.screenshotTransform
        case .title: app.settings.titleTransform
        }
    }

    private func updateTransform(
        for element: EditorElement,
        mutation: (inout CanvasElementTransform) -> Void
    ) {
        switch element {
        case .screenshot:
            var transform = app.settings.screenshotTransform
            mutation(&transform)
            app.settings.screenshotTransform = transform
        case .title:
            var transform = app.settings.titleTransform
            mutation(&transform)
            app.settings.titleTransform = transform
        }
    }

    private func fittedSize(content: CGSize, available: CGSize) -> CGSize {
        guard content.width > 0, content.height > 0, available.width > 0, available.height > 0 else {
            return .zero
        }
        let scale = min(available.width / content.width, available.height / content.height)
        return CGSize(width: content.width * scale, height: content.height * scale)
    }
}

private struct CompositionState: Equatable {
    let selectedPlatform: SocialPlatform
    let selectedBackgroundID: UUID
    let paddingPercent: Double
    let deviceCornerRadius: Double
    let showDeviceShadow: Bool
    let screenshotTransform: CanvasElementTransform
    let deviceFrameStyle: DeviceFrameStyle
    let productBezelDevice: ProductBezelDevice
    let productBezelFinish: String
    let importedBezelInset: Double
    let titleEnabled: Bool
    let titleText: String
    let titleFontName: String
    let titleFontSize: Double
    let titleTransform: CanvasElementTransform
    let watermarkEnabled: Bool
    let watermarkText: String
    let selectedProductBezelID: UUID?

    init(settings: AppSettings, selectedProductBezelID: UUID?) {
        selectedPlatform = settings.selectedPlatform
        selectedBackgroundID = settings.selectedBackgroundID
        paddingPercent = settings.paddingPercent
        deviceCornerRadius = settings.deviceCornerRadius
        showDeviceShadow = settings.showDeviceShadow
        screenshotTransform = settings.screenshotTransform
        deviceFrameStyle = settings.deviceFrameStyle
        productBezelDevice = settings.productBezelDevice
        productBezelFinish = settings.productBezelFinish
        importedBezelInset = settings.importedBezelInset
        titleEnabled = settings.titleEnabled
        titleText = settings.titleText
        titleFontName = settings.titleFontName
        titleFontSize = settings.titleFontSize
        titleTransform = settings.titleTransform
        watermarkEnabled = settings.watermarkEnabled
        watermarkText = settings.watermarkText
        self.selectedProductBezelID = selectedProductBezelID
    }
}

private enum EditorElement: String, CaseIterable, Identifiable {
    case screenshot
    case title

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .screenshot: "Screenshot"
        case .title: "Title"
        }
    }
}

private struct SystemFontOption: Identifiable {
    let postScriptName: String
    let displayName: String
    var id: String { postScriptName }
}

private enum SystemFontCatalog {
    static let installed: [SystemFontOption] = NSFontManager.shared.availableFonts
        .map { name in
            SystemFontOption(
                postScriptName: name,
                displayName: NSFont(name: name, size: 13)?.displayName ?? name
            )
        }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var suffix = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(title)
                Text(formattedValue)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            Slider(value: $value, in: range)
        }
        .frame(minWidth: 110, maxWidth: 180)
    }

    private var formattedValue: String {
        if suffix.isEmpty {
            return value.formatted(.number.precision(.fractionLength(2)))
        }
        if suffix == "×" {
            return value.formatted(.number.precision(.fractionLength(1))) + suffix
        }
        return "\(Int(value.rounded()))\(suffix)"
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
