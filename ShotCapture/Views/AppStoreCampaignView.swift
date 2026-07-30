//
//  AppStoreCampaignView.swift
//  ShotCapture
//

import AppKit
import AVFoundation
import AVKit
import SwiftUI

struct AppStoreCampaignView: View {
    @Environment(AppStoreCampaignController.self) private var controller
    @State private var showsPreflight = false

    var body: some View {
        VStack(spacing: 0) {
            projectToolbar
            Divider()

            switch controller.selectedSection {
            case .screenshots:
                screenshotWorkspace
            case .previews:
                previewWorkspace
            }

            Divider()
            statusBar
        }
        .frame(minWidth: 1_080, idealWidth: 1_320, minHeight: 720, idealHeight: 860)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("app-store-campaign-workspace")
    }

    private var projectToolbar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(controller.projectTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text("App Store Campaign · \(controller.campaign.locale)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 230, alignment: .leading)

            Divider()
                .frame(height: 24)

            Button {
                Task { await controller.makeNewCampaign() }
            } label: {
                Label("New", systemImage: "doc.badge.plus")
            }

            Button(action: controller.openCampaign) {
                Label("Open", systemImage: "folder")
            }

            Button(action: controller.saveCampaignAs) {
                Label("Save As", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Spacer(minLength: 12)

            Picker(
                "Workspace",
                selection: sectionBinding
            ) {
                ForEach(AppStoreWorkspaceSection.allCases) { section in
                    Label(section.displayName, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)

            Spacer(minLength: 12)

            if controller.isWorking {
                ProgressView(value: controller.progress)
                    .frame(width: 88)
                    .accessibilityLabel("Export progress")
                Button("Cancel", action: controller.cancelCurrentWork)
            }

            Button {
                if controller.selectedSection == .screenshots {
                    controller.exportScreenshots()
                } else {
                    controller.exportPreviews()
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(controller.isWorking)
            .accessibilityIdentifier("campaign-export-button")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var screenshotWorkspace: some View {
        HSplitView {
            screenshotSidebar
                .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)

            screenshotCanvas
                .frame(minWidth: 520)

            screenshotInspector
                .frame(minWidth: 280, idealWidth: 310, maxWidth: 360)
        }
    }

    private var screenshotSidebar: some View {
        VStack(spacing: 0) {
            targetPicker
                .padding(12)
            Divider()

            List(selection: panelSelectionBinding) {
                ForEach(Array(controller.campaign.panels.enumerated()), id: \.element.id) { index, panel in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .leading)
                            Text(panel.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            if panel.targetContents.first(where: {
                                $0.target == controller.selectedTarget
                            })?.mediaFileName != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .accessibilityLabel("Media added")
                            }
                        }
                        Text(panel.headline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 5)
                    .tag(panel.id)
                }
            }
            .accessibilityIdentifier("campaign-screenshot-list")

            Divider()
            HStack(spacing: 12) {
                Button(action: controller.addPanel) {
                    Label("Add", systemImage: "plus")
                }
                .disabled(!controller.canAddPanel)

                Button(action: controller.duplicateSelectedPanel) {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .disabled(controller.selectedPanel == nil || !controller.canAddPanel)

                Spacer()

                Button {
                    controller.moveSelectedPanel(by: -1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(controller.selectedPanelIndex == 0)
                .help("Move earlier")

                Button {
                    controller.moveSelectedPanel(by: 1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .disabled(
                    controller.selectedPanelIndex == nil ||
                        controller.selectedPanelIndex == controller.campaign.panels.count - 1
                )
                .help("Move later")

                Button(role: .destructive, action: controller.deleteSelectedPanel) {
                    Image(systemName: "trash")
                }
                .disabled(controller.campaign.panels.count <= 1)
                .help("Delete screenshot")
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var targetPicker: some View {
        Menu {
            ForEach(AppStoreDisplayTarget.allCases) { target in
                Button {
                    controller.selectTarget(target)
                } label: {
                    if controller.selectedTarget == target {
                        Label(target.displayName, systemImage: "checkmark")
                    } else {
                        Text(target.displayName)
                    }
                }
            }
            Divider()
            ForEach(AppStoreDisplayTarget.allCases) { target in
                Toggle(
                    "Export \(target.shortName)",
                    isOn: targetEnabledBinding(target)
                )
            }
        } label: {
            HStack {
                Image(systemName: controller.selectedTarget.isIPad ? "ipad" : "iphone")
                VStack(alignment: .leading, spacing: 1) {
                    Text(controller.selectedTarget.shortName)
                        .font(.subheadline.weight(.semibold))
                    let size = controller.selectedTarget.screenshotSize
                    Text("\(Int(size.width)) × \(Int(size.height)) px")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier("campaign-target-picker")
    }

    private var screenshotCanvas: some View {
        CampaignScreenshotCanvasView()
    }

    private var screenshotInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                campaignSection

                if controller.selectedPanel != nil {
                    storySection
                    layoutSection
                    backgroundSection
                    deviceSection
                    placementSection
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var campaignSection: some View {
        GroupBox("Campaign") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Campaign name", text: campaignNameBinding)
                    .accessibilityLabel("Campaign name")
                LabeledContent("Locale") {
                    TextField("en-US", text: localeBinding)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }
            .padding(.top, 4)
        }
    }

    private var storySection: some View {
        GroupBox("Story") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Panel name", text: panelBinding(\.name))
                TextField(
                    "Headline",
                    text: panelBinding(\.headline),
                    axis: .vertical
                )
                .lineLimit(2...3)
                TextField(
                    "Supporting line",
                    text: panelBinding(\.subtitle),
                    axis: .vertical
                )
                .lineLimit(2...3)

                LabeledContent("Headline size") {
                    TextField(
                        "Size",
                        value: panelBinding(\.titleFontSize),
                        format: .number.precision(.fractionLength(0))
                    )
                    .frame(width: 66)
                }
                LabeledContent("Subtitle size") {
                    TextField(
                        "Size",
                        value: panelBinding(\.subtitleFontSize),
                        format: .number.precision(.fractionLength(0))
                    )
                    .frame(width: 66)
                }
            }
            .padding(.top, 4)
        }
    }

    private var layoutSection: some View {
        GroupBox("Layout") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(AppStoreScreenshotLayout.allCases) { layout in
                    Button {
                        controller.updateSelectedPanel { $0.applyLayout(layout) }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: layout.symbolName)
                                .font(.title3)
                            Text(layout.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            controller.selectedPanel?.layout == layout
                                ? Color.accentColor.opacity(0.16)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                controller.selectedPanel?.layout == layout
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.22)
                            )
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var backgroundSection: some View {
        GroupBox("Background") {
            Menu {
                ForEach(BackgroundStyle.presets) { background in
                    Button {
                        controller.updateSelectedPanel { $0.background = background }
                    } label: {
                        if controller.selectedPanel?.background.id == background.id {
                            Label(background.name, systemImage: "checkmark")
                        } else {
                            Text(background.name)
                        }
                    }
                }
            } label: {
                HStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(backgroundPreviewStyle)
                        .frame(width: 32, height: 24)
                    Text(controller.selectedPanel?.background.name ?? "Background")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .padding(.top, 4)
        }
    }

    private var deviceSection: some View {
        GroupBox("Device") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Frame", selection: contentBinding(\.deviceFrameStyle)) {
                    Text("None").tag(DeviceFrameStyle.none)
                    Text("Generic").tag(DeviceFrameStyle.genericPhone)
                    if ProductBezelDevice.bundledResourcesAvailable {
                        Text("Apple Bezel").tag(DeviceFrameStyle.appleProductBezel)
                    }
                }

                if controller.selectedContent?.deviceFrameStyle == .appleProductBezel {
                    Picker("Model", selection: contentBinding(\.productBezelDevice)) {
                        ForEach(availableDevices) { device in
                            Text(device.displayName).tag(device)
                        }
                    }
                    .onChange(of: controller.selectedContent?.productBezelDevice) { _, device in
                        guard let device else { return }
                        controller.updateSelectedContent {
                            if !device.finishes.contains($0.productBezelFinish) {
                                $0.productBezelFinish = device.defaultFinish
                            }
                        }
                    }

                    if let device = controller.selectedContent?.productBezelDevice {
                        Picker("Finish", selection: contentBinding(\.productBezelFinish)) {
                            ForEach(device.finishes, id: \.self) { finish in
                                Text(finish).tag(finish)
                            }
                        }
                    }
                }

                Toggle("Device shadow", isOn: contentBinding(\.showDeviceShadow))
            }
            .padding(.top, 4)
        }
    }

    private var placementSection: some View {
        Group {
            if let panelID = controller.selectedPanelID,
               let transform = controller.selectedContent?.screenshotTransform {
                let target = controller.selectedTarget
                CampaignPlacementControlsView(
                    transform: transform,
                    onPreview: { newTransform in
                        controller.previewScreenshotTransform(
                            newTransform,
                            panelID: panelID,
                            target: target
                        )
                    },
                    onCommit: { newTransform in
                        controller.commitScreenshotTransform(
                            newTransform,
                            panelID: panelID,
                            target: target
                        )
                    }
                )
            }
        }
    }

    private var previewWorkspace: some View {
        HSplitView {
            previewSidebar
                .frame(minWidth: 240, idealWidth: 270, maxWidth: 320)
            previewCanvas
                .frame(minWidth: 520)
            previewInspector
                .frame(minWidth: 280, idealWidth: 310, maxWidth: 360)
        }
    }

    private var previewSidebar: some View {
        VStack(spacing: 0) {
            targetPicker
                .padding(12)
            Divider()

            List(selection: previewSelectionBinding) {
                ForEach(controller.campaign.previews.filter {
                    $0.target == controller.selectedTarget
                }) { preview in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .foregroundStyle(.secondary)
                            Text(preview.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            Text(preview.trimmedDuration.formatted(
                                .number.precision(.fractionLength(1))
                            ) + " sec")
                            Label(
                                preview.hasAudio ? "Source audio" : "Adds stereo silence",
                                systemImage: preview.hasAudio ? "speaker.wave.2" : "speaker.slash"
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                    .tag(preview.id)
                }
            }
            .overlay {
                if controller.campaign.previews.allSatisfy({
                    $0.target != controller.selectedTarget
                }) {
                    ContentUnavailableView(
                        "No App Previews",
                        systemImage: "play.rectangle",
                        description: Text("Import or record up to three previews for this target.")
                    )
                }
            }

            Divider()
            HStack {
                Button(action: controller.importPreview) {
                    Label("Import", systemImage: "plus")
                }
                Button(action: controller.togglePreviewRecording) {
                    Label(
                        controller.isRecording ? "Stop" : "Record",
                        systemImage: controller.isRecording ? "stop.circle.fill" : "record.circle"
                    )
                }
                .foregroundStyle(controller.isRecording ? .red : .primary)
                Spacer()
                Button(role: .destructive, action: controller.deleteSelectedPreview) {
                    Image(systemName: "trash")
                }
                .disabled(controller.selectedPreview == nil)
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var previewCanvas: some View {
        VStack(spacing: 0) {
            HStack {
                Label(
                    "App Preview · \(controller.selectedTarget.shortName)",
                    systemImage: "play.rectangle"
                )
                .font(.subheadline.weight(.semibold))
                Spacer()
                let size = controller.selectedTarget.previewSize
                Text("\(Int(size.width)) × \(Int(size.height)) · H.264 · ≤30 fps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            GeometryReader { geometry in
                ZStack {
                    Color.black.opacity(0.88)
                    if let preview = controller.selectedPreview,
                       let url = controller.assetURL(for: preview) {
                        CampaignVideoPlayerView(url: url)
                            .aspectRatio(
                                controller.selectedTarget.previewSize.width /
                                    controller.selectedTarget.previewSize.height,
                                contentMode: .fit
                            )
                            .padding(32)
                    } else {
                        ContentUnavailableView {
                            Label("Add an App Preview", systemImage: "play.rectangle")
                        } description: {
                            Text("Import a movie or record the booted Simulator.")
                        } actions: {
                            HStack {
                                Button("Import…", action: controller.importPreview)
                                Button(
                                    controller.isRecording ? "Stop Recording" : "Record Simulator",
                                    action: controller.togglePreviewRecording
                                )
                            }
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private var previewInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                campaignSection

                if let preview = controller.selectedPreview {
                    GroupBox("Preview") {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Name", text: previewBinding(\.name))
                            LabeledContent("Source") {
                                Text(preview.sourceDuration.formatted(
                                    .number.precision(.fractionLength(1))
                                ) + " sec")
                                .monospacedDigit()
                            }
                            LabeledContent("Audio") {
                                Label(
                                    preview.hasAudio ? "Preserved" : "Silent stereo added",
                                    systemImage: preview.hasAudio
                                        ? "speaker.wave.2.fill"
                                        : "waveform.badge.plus"
                                )
                                .foregroundStyle(preview.hasAudio ? Color.secondary : Color.green)
                            }
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Trim") {
                        VStack(spacing: 12) {
                            inspectorSlider(
                                "Start",
                                value: previewBinding(\.trimStart),
                                range: 0...max(0.1, preview.sourceDuration - 0.1)
                            )
                            inspectorSlider(
                                "End",
                                value: previewBinding(\.trimEnd),
                                range: 0.1...max(0.1, preview.sourceDuration)
                            )
                            LabeledContent("Export duration") {
                                Text(preview.trimmedDuration.formatted(
                                    .number.precision(.fractionLength(1))
                                ) + " sec")
                                .monospacedDigit()
                                .foregroundStyle(
                                    preview.trimmedDuration >= 15 &&
                                        preview.trimmedDuration <= 30
                                        ? .green
                                        : .red
                                )
                            }
                            Text("App Store previews must be 15–30 seconds. Silent Simulator recordings receive a 44.1 kHz stereo AAC track automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Delivery") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("H.264 QuickTime movie", systemImage: "checkmark.circle")
                            Label("Maximum 30 fps", systemImage: "checkmark.circle")
                            Label("Stereo AAC · 44.1 kHz", systemImage: "checkmark.circle")
                            Label("Maximum 500 MB", systemImage: "checkmark.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                } else {
                    ContentUnavailableView(
                        "Select a Preview",
                        systemImage: "slider.horizontal.3",
                        description: Text("Trim and delivery checks appear here.")
                    )
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if controller.isWorking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: controller.lastError == nil ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(controller.lastError == nil ? Color.secondary : Color.red)
            }

            Text(controller.lastError ?? controller.statusMessage)
                .font(.caption)
                .foregroundStyle(controller.lastError == nil ? Color.secondary : Color.red)
                .lineLimit(1)

            Spacer()

            let errors = controller.preflightIssues.filter { $0.severity == .error }.count
            let warnings = controller.preflightIssues.filter { $0.severity == .warning }.count
            Button {
                showsPreflight.toggle()
            } label: {
                Label(
                    errors == 0
                        ? (warnings == 0 ? "Ready to export" : "\(warnings) warning\(warnings == 1 ? "" : "s")")
                        : "\(errors) issue\(errors == 1 ? "" : "s")",
                    systemImage: errors == 0 ? "checkmark.seal" : "exclamationmark.triangle"
                )
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showsPreflight, arrowEdge: .bottom) {
                preflightPopover
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var preflightPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Preflight")
                .font(.headline)
            if controller.preflightIssues.isEmpty {
                Label("All enabled screenshot targets are ready.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(controller.preflightIssues) { issue in
                            Label {
                                Text(issue.message)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(
                                    systemName: issue.severity == .error
                                        ? "xmark.circle.fill"
                                        : "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(issue.severity == .error ? .red : .orange)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 380, height: min(420, 90 + CGFloat(controller.preflightIssues.count * 48)))
    }

    private var availableDevices: [ProductBezelDevice] {
        let category: ProductBezelCategory = controller.selectedTarget.isIPad ? .iPad : .iPhone
        let available = ProductBezelDevice.availableCases.filter { $0.category == category }
        return available.isEmpty
            ? ProductBezelDevice.allCases.filter { $0.category == category }
            : available
    }

    private var backgroundPreviewStyle: AnyShapeStyle {
        guard let background = controller.selectedPanel?.background else {
            return AnyShapeStyle(Color.gray)
        }
        switch background.kind {
        case .solid:
            return AnyShapeStyle(Color(nsColor: NSColor(hex: background.solidHex ?? "") ?? .gray))
        case .linearGradient, .radialGradient:
            let colors = background.gradientStops.map(\.color)
            return AnyShapeStyle(
                LinearGradient(
                    colors: colors.isEmpty ? [.gray, .black] : colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .presetImage:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var sectionBinding: Binding<AppStoreWorkspaceSection> {
        Binding(
            get: { controller.selectedSection },
            set: { section in
                controller.selectedSection = section
                if section == .previews {
                    controller.selectedPreviewID = controller.campaign.previews.first {
                        $0.target == controller.selectedTarget
                    }?.id
                }
            }
        )
    }

    private var panelSelectionBinding: Binding<UUID?> {
        Binding(
            get: { controller.selectedPanelID },
            set: { id in
                guard let id else { return }
                controller.selectPanel(id)
            }
        )
    }

    private var previewSelectionBinding: Binding<UUID?> {
        Binding(
            get: { controller.selectedPreviewID },
            set: { id in
                guard let id else { return }
                controller.selectPreview(id)
            }
        )
    }

    private var campaignNameBinding: Binding<String> {
        Binding(
            get: { controller.campaign.name },
            set: {
                controller.campaign.name = $0
                controller.campaignDidChange(render: false)
            }
        )
    }

    private var localeBinding: Binding<String> {
        Binding(
            get: { controller.campaign.locale },
            set: {
                controller.campaign.locale = $0
                controller.campaignDidChange(render: false)
            }
        )
    }

    private func panelBinding<Value>(
        _ keyPath: WritableKeyPath<AppStoreScreenshotPanel, Value>
    ) -> Binding<Value> {
        Binding(
            get: { controller.selectedPanel![keyPath: keyPath] },
            set: { value in
                controller.updateSelectedPanel { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func contentBinding<Value>(
        _ keyPath: WritableKeyPath<AppStoreTargetContent, Value>
    ) -> Binding<Value> {
        Binding(
            get: { controller.selectedContent![keyPath: keyPath] },
            set: { value in
                controller.updateSelectedContent { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func previewBinding<Value>(
        _ keyPath: WritableKeyPath<AppStorePreviewItem, Value>
    ) -> Binding<Value> {
        Binding(
            get: { controller.selectedPreview![keyPath: keyPath] },
            set: { value in
                controller.updateSelectedPreview { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func targetEnabledBinding(_ target: AppStoreDisplayTarget) -> Binding<Bool> {
        Binding(
            get: { controller.campaign.enabledTargets.contains(target) },
            set: { enabled in
                if enabled != controller.campaign.enabledTargets.contains(target) {
                    controller.toggleTarget(target)
                }
            }
        )
    }

    private func inspectorSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(
                    .number.precision(.fractionLength(2))
                ))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

}

private struct CampaignVideoPlayerView: View {
    let url: URL
    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
            }
            .onChange(of: url) { _, newURL in
                player.replaceCurrentItem(with: AVPlayerItem(url: newURL))
            }
            .onDisappear {
                player.pause()
                player.replaceCurrentItem(with: nil)
            }
            .accessibilityLabel("App Preview player")
    }
}
