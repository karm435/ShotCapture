//
//  AppStoreCampaignController.swift
//  ShotCapture
//

import AppKit
import AVFoundation
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let shotCaptureCampaign = UTType(
        exportedAs: "com.karmaacademy.shotcapture.campaign",
        conformingTo: .package
    )
}

nonisolated enum AppStoreWorkspaceSection: String, CaseIterable, Identifiable, Sendable {
    case screenshots
    case previews

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .screenshots: "Screenshots"
        case .previews: "App Previews"
        }
    }

    var symbolName: String {
        switch self {
        case .screenshots: "photo.stack"
        case .previews: "play.rectangle"
        }
    }
}

@Observable
@MainActor
final class AppStoreCampaignController {
    let appController: AppController

    var campaign = AppStoreCampaign()
    var workspaceURL: URL?
    var externalPackageURL: URL?
    var selectedPanelID: UUID?
    var selectedPreviewID: UUID?
    var selectedTarget: AppStoreDisplayTarget = .iPhone69Portrait
    var selectedSection: AppStoreWorkspaceSection = .screenshots
    var renderedScreenshot: NSImage?
    var screenshotPreviewLayers: AppStoreScreenshotPreviewLayers?
    var interactiveScreenshotTransform: CanvasElementTransform?
    var isAdjustingScreenshotPlacement = false
    var preflightIssues: [AppStorePreflightIssue] = []
    var statusMessage = "Preparing campaign…"
    var lastError: String?
    var isWorking = false
    var progress = 0.0
    var recordingState: SimulatorRecordingState = .idle

    private let store = AppStoreCampaignStore()
    private let screenshotExporter = AppStoreScreenshotExportService()
    private let previewExporter = AppPreviewExportService()
    private let videoImportService = VideoImportService()
    private let recordingService = SimulatorRecordingService()
    private var saveTask: Task<Void, Never>?

    init(appController: AppController) {
        self.appController = appController
        selectedPanelID = campaign.panels.first?.id
        Task { await makeNewCampaign() }
    }

    var selectedPanelIndex: Int? {
        guard let selectedPanelID else { return nil }
        return campaign.panels.firstIndex { $0.id == selectedPanelID }
    }

    var selectedPanel: AppStoreScreenshotPanel? {
        guard let selectedPanelIndex else { return nil }
        return campaign.panels[selectedPanelIndex]
    }

    var selectedContent: AppStoreTargetContent? {
        selectedPanel?.targetContents.first { $0.target == selectedTarget }
    }

    var selectedPreview: AppStorePreviewItem? {
        guard let selectedPreviewID else { return nil }
        return campaign.previews.first { $0.id == selectedPreviewID }
    }

    var enabledTargets: [AppStoreDisplayTarget] {
        AppStoreDisplayTarget.allCases.filter(campaign.enabledTargets.contains)
    }

    var canAddPanel: Bool {
        campaign.panels.count < AppStoreCampaign.maximumScreenshots
    }

    var isRecording: Bool {
        recordingState == .recording
    }

    var projectTitle: String {
        externalPackageURL?.deletingPathExtension().lastPathComponent ?? campaign.name
    }

    func makeNewCampaign() async {
        guard !isWorking else { return }
        saveTask?.cancel()
        let newCampaign = AppStoreCampaign()
        do {
            let workspace = try await store.makeWorkspace(for: newCampaign)
            campaign = newCampaign
            workspaceURL = workspace
            externalPackageURL = nil
            selectedPanelID = newCampaign.panels.first?.id
            selectedPreviewID = nil
            selectedTarget = newCampaign.enabledTargets.first ?? .iPhone69Portrait
            selectedSection = .screenshots
            lastError = nil
            statusMessage = "New campaign"
            refreshPreviewAndPreflight()
        } catch {
            fail(error, status: "Could not create campaign")
        }
    }

    func openCampaign() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.shotCaptureCampaign]
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a .shotcapturecampaign project."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await openCampaign(at: url) }
    }

    func openCampaign(at url: URL) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let gainedScope = url.startAccessingSecurityScopedResource()
        defer {
            if gainedScope { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let loaded = try await store.loadPackage(at: url)
            let workspace = try await store.prepareImportedPackage(at: url)
            campaign = loaded
            workspaceURL = workspace
            externalPackageURL = url
            selectedPanelID = loaded.panels.first?.id
            selectedPreviewID = loaded.previews.first?.id
            selectedTarget = loaded.enabledTargets.first ?? .iPhone69Portrait
            lastError = nil
            statusMessage = "Opened \(url.lastPathComponent)"
            refreshPreviewAndPreflight()
        } catch {
            fail(error, status: "Could not open campaign")
        }
    }

    func saveCampaign() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self.persistCampaign(copyToExternalPackage: true)
        }
    }

    func saveCampaignNow() {
        saveTask?.cancel()
        Task { await persistCampaign(copyToExternalPackage: true) }
    }

    func saveCampaignAs() {
        guard workspaceURL != nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.shotCaptureCampaign]
        panel.nameFieldStringValue = "\(sanitizedFileName(campaign.name)).\(AppStoreCampaignStore.packageExtension)"
        panel.canCreateDirectories = true
        panel.message = "Save a portable campaign package containing its imported media."

        guard panel.runModal() == .OK, var destination = panel.url else { return }
        if destination.pathExtension != AppStoreCampaignStore.packageExtension {
            destination.appendPathExtension(AppStoreCampaignStore.packageExtension)
        }
        Task {
            await persistCampaign(copyToExternalPackage: false)
            guard let workspaceURL else { return }
            do {
                try await store.saveCopy(from: workspaceURL, to: destination)
                externalPackageURL = destination
                statusMessage = "Saved \(destination.lastPathComponent)"
            } catch {
                fail(error, status: "Save failed")
            }
        }
    }

    func campaignDidChange(render: Bool = true) {
        campaign.updatedAt = .now
        if render {
            refreshPreviewAndPreflight()
        } else {
            refreshPreflight()
        }
        saveCampaign()
    }

    func selectPanel(_ id: UUID) {
        selectedPanelID = id
        refreshPreviewAndPreflight()
    }

    func selectTarget(_ target: AppStoreDisplayTarget) {
        selectedTarget = target
        if selectedSection == .previews {
            selectedPreviewID = campaign.previews.first { $0.target == target }?.id
        }
        refreshPreviewAndPreflight()
    }

    func selectPreview(_ id: UUID) {
        selectedPreviewID = id
        if let preview = campaign.previews.first(where: { $0.id == id }) {
            selectedTarget = preview.target
        }
    }

    func assetURL(for preview: AppStorePreviewItem) -> URL? {
        workspaceURL?
            .appending(path: "Assets", directoryHint: .isDirectory)
            .appending(path: preview.mediaFileName)
    }

    func updateSelectedPanel(
        _ update: (inout AppStoreScreenshotPanel) -> Void,
        render: Bool = true
    ) {
        guard let index = selectedPanelIndex else { return }
        update(&campaign.panels[index])
        campaignDidChange(render: render)
    }

    func updateSelectedContent(
        _ update: (inout AppStoreTargetContent) -> Void
    ) {
        updateSelectedPanel { panel in
            panel.updateContent(for: selectedTarget, update)
        }
    }

    func previewScreenshotTransform(
        _ transform: CanvasElementTransform,
        panelID: UUID,
        target: AppStoreDisplayTarget
    ) {
        guard selectedPanelID == panelID, selectedTarget == target else { return }
        interactiveScreenshotTransform = transform
        isAdjustingScreenshotPlacement = true
    }

    func commitScreenshotTransform(
        _ transform: CanvasElementTransform,
        panelID: UUID,
        target: AppStoreDisplayTarget
    ) {
        guard let index = campaign.panels.firstIndex(where: { $0.id == panelID }) else {
            return
        }
        campaign.panels[index].updateContent(for: target) {
            $0.screenshotTransform = transform
        }
        campaign.updatedAt = .now
        if selectedPanelID == panelID, selectedTarget == target, let workspaceURL {
            renderedScreenshot = try? screenshotExporter.renderPreview(
                panel: campaign.panels[index],
                target: target,
                packageURL: workspaceURL,
                maximumDimension: 1_400
            )
            interactiveScreenshotTransform = nil
            isAdjustingScreenshotPlacement = false
        }
        saveCampaign()
    }

    func addPanel() {
        guard canAddPanel else { return }
        let panel = AppStoreScreenshotPanel(
            name: "Screenshot \(campaign.panels.count + 1)",
            headline: "A benefit users understand",
            subtitle: "Keep the story focused and easy to scan",
            background: BackgroundStyle.presets[campaign.panels.count % BackgroundStyle.presets.count],
            targets: AppStoreDisplayTarget.allCases
        )
        campaign.panels.append(panel)
        selectedPanelID = panel.id
        campaignDidChange()
    }

    func duplicateSelectedPanel() {
        guard canAddPanel, var copy = selectedPanel else { return }
        copy.id = UUID()
        copy.name += " Copy"
        copy.targetContents = copy.targetContents.map { content in
            var copyContent = content
            copyContent.id = UUID()
            return copyContent
        }
        let insertionIndex = (selectedPanelIndex ?? campaign.panels.count - 1) + 1
        campaign.panels.insert(copy, at: insertionIndex)
        selectedPanelID = copy.id
        campaignDidChange()
    }

    func deleteSelectedPanel() {
        guard campaign.panels.count > 1, let index = selectedPanelIndex else { return }
        campaign.panels.remove(at: index)
        selectedPanelID = campaign.panels[min(index, campaign.panels.count - 1)].id
        campaignDidChange()
    }

    func moveSelectedPanel(by offset: Int) {
        guard let index = selectedPanelIndex else { return }
        let destination = index + offset
        guard campaign.panels.indices.contains(destination) else { return }
        let panel = campaign.panels.remove(at: index)
        campaign.panels.insert(panel, at: destination)
        selectedPanelID = panel.id
        campaignDidChange(render: false)
    }

    func toggleTarget(_ target: AppStoreDisplayTarget) {
        if let index = campaign.enabledTargets.firstIndex(of: target) {
            guard campaign.enabledTargets.count > 1 else {
                lastError = "At least one display target must remain enabled."
                NSSound.beep()
                return
            }
            campaign.enabledTargets.remove(at: index)
            if selectedTarget == target {
                selectedTarget = enabledTargets.first ?? .iPhone69Portrait
            }
        } else {
            campaign.enabledTargets.append(target)
            campaign.enabledTargets.sort {
                AppStoreDisplayTarget.allCases.firstIndex(of: $0)! <
                    AppStoreDisplayTarget.allCases.firstIndex(of: $1)!
            }
        }
        campaignDidChange()
    }

    func importScreenshot() {
        guard selectedPanelID != nil, workspaceURL != nil else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the screenshot for \(selectedTarget.shortName)."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await importScreenshot(at: url) }
    }

    func importScreenshot(at url: URL) async {
        guard let workspaceURL else { return }
        let gainedScope = url.startAccessingSecurityScopedResource()
        defer {
            if gainedScope { url.stopAccessingSecurityScopedResource() }
        }
        do {
            guard NSImage(contentsOf: url) != nil else {
                throw AppStoreScreenshotExportError.unreadableMedia(url.lastPathComponent)
            }
            let fileName = try await store.copyAsset(
                from: url,
                preferredStem: "\(selectedTarget.exportFolderName)-screenshot",
                into: workspaceURL
            )
            updateSelectedContent { $0.mediaFileName = fileName }
            statusMessage = "Imported \(url.lastPathComponent)"
        } catch {
            fail(error, status: "Import failed")
        }
    }

    func captureScreenshot() {
        guard selectedPanelID != nil, workspaceURL != nil else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                await appController.refreshDevices()
                let udid = resolvedSimulatorUDID()
                let image = try await appController.captureService.captureScreenshot(udid: udid)
                guard let data = CompositionService.pngData(from: image),
                      let workspaceURL else {
                    throw AppStoreScreenshotExportError.renderingFailed
                }
                let fileName = try await store.writeAsset(
                    data,
                    preferredStem: "\(selectedTarget.exportFolderName)-capture",
                    fileExtension: "png",
                    into: workspaceURL
                )
                updateSelectedContent { $0.mediaFileName = fileName }
                statusMessage = "Captured \(selectedTarget.shortName)"
            } catch {
                fail(error, status: "Capture failed")
            }
        }
    }

    func importPreview() {
        guard workspaceURL != nil else { return }
        let existingCount = campaign.previews.filter { $0.target == selectedTarget }.count
        guard existingCount < AppStoreCampaign.maximumPreviewsPerTarget else {
            lastError = "App Store Connect accepts up to 3 previews for each display target."
            NSSound.beep()
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a 15–30 second App Preview source video."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await importPreview(at: url) }
    }

    func importPreview(at url: URL) async {
        guard let workspaceURL else { return }
        isWorking = true
        defer { isWorking = false }
        let gainedScope = url.startAccessingSecurityScopedResource()
        defer {
            if gainedScope { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let video = try await videoImportService.loadVideo(at: url)
            let fileName = try await store.copyAsset(
                from: url,
                preferredStem: "\(selectedTarget.exportFolderName)-preview",
                into: workspaceURL
            )
            let item = AppStorePreviewItem(
                name: video.displayName,
                target: selectedTarget,
                mediaFileName: fileName,
                sourceDuration: video.durationSeconds,
                hasAudio: video.hasAudio
            )
            campaign.previews.append(item)
            selectedPreviewID = item.id
            selectedSection = .previews
            campaignDidChange(render: false)
            statusMessage = video.hasAudio
                ? "Imported \(video.displayName)"
                : "Imported \(video.displayName) · silent stereo will be added on export"
        } catch {
            fail(error, status: "Preview import failed")
        }
    }

    func togglePreviewRecording() {
        if recordingState == .recording {
            Task { await stopPreviewRecording() }
        } else if recordingState == .idle {
            Task { await startPreviewRecording() }
        }
    }

    func startPreviewRecording() async {
        guard recordingState == .idle, !isWorking else { return }
        recordingState = .starting
        do {
            await appController.refreshDevices()
            guard let udid = resolvedSimulatorUDID() else {
                throw SimulatorCaptureError.noBootedSimulator
            }
            _ = try await recordingService.startRecording(udid: udid)
            recordingState = .recording
            statusMessage = "Recording Simulator for \(selectedTarget.shortName)…"
        } catch {
            recordingState = .idle
            fail(error, status: "Recording failed")
        }
    }

    func stopPreviewRecording() async {
        guard recordingState == .recording else { return }
        recordingState = .finalizing
        do {
            let url = try await recordingService.stopRecording()
            recordingState = .idle
            await importPreview(at: url)
            try? FileManager.default.removeItem(at: url)
        } catch {
            recordingState = .idle
            fail(error, status: "Recording failed")
        }
    }

    func cancelPreviewRecording() {
        guard recordingState.isActive else { return }
        Task { await recordingService.cancelRecording() }
        recordingState = .idle
        statusMessage = "Recording cancelled"
    }

    func updateSelectedPreview(_ update: (inout AppStorePreviewItem) -> Void) {
        guard let selectedPreviewID,
              let index = campaign.previews.firstIndex(where: { $0.id == selectedPreviewID }) else {
            return
        }
        update(&campaign.previews[index])
        let duration = campaign.previews[index].sourceDuration
        campaign.previews[index].trimStart = min(
            max(0, campaign.previews[index].trimStart),
            max(0, duration - 0.1)
        )
        campaign.previews[index].trimEnd = min(
            max(campaign.previews[index].trimStart + 0.1, campaign.previews[index].trimEnd),
            duration
        )
        campaignDidChange(render: false)
    }

    func deleteSelectedPreview() {
        guard let previewID = selectedPreviewID,
              let index = campaign.previews.firstIndex(where: { $0.id == previewID }) else {
            return
        }
        campaign.previews.remove(at: index)
        self.selectedPreviewID = campaign.previews.first { $0.target == selectedTarget }?.id
        campaignDidChange(render: false)
    }

    func exportScreenshots() {
        guard let workspaceURL else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose where ShotCapture should create the App Store asset folder."
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        Task {
            isWorking = true
            progress = 0
            lastError = nil
            defer { isWorking = false }
            do {
                await persistCampaign(copyToExternalPackage: true)
                let result = try await screenshotExporter.export(
                    campaign: campaign,
                    packageURL: workspaceURL,
                    destinationDirectory: destination
                ) { [weak self] progress, message in
                    self?.progress = progress
                    self?.statusMessage = message
                }
                statusMessage = "Exported \(result.exportedFiles.count) screenshots"
                NSWorkspace.shared.activateFileViewerSelecting([result.rootURL])
            } catch {
                fail(error, status: "Screenshot export failed")
            }
        }
    }

    func exportPreviews() {
        guard let workspaceURL else { return }
        let items = campaign.previews.filter { campaign.enabledTargets.contains($0.target) }
        guard !items.isEmpty else {
            lastError = "Add at least one App Preview before exporting."
            NSSound.beep()
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose where ShotCapture should create the App Preview files."
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        Task {
            isWorking = true
            progress = 0
            lastError = nil
            defer { isWorking = false }
            let root = uniquePreviewExportDirectory(in: destination)
            do {
                for (index, item) in items.enumerated() {
                    try Task.checkCancellation()
                    let sourceURL = try await store.assetURL(
                        named: item.mediaFileName,
                        in: workspaceURL
                    )
                    let targetItems = items.filter { $0.target == item.target }
                    let targetIndex = targetItems.firstIndex { $0.id == item.id } ?? 0
                    let directory = root
                        .appending(path: campaign.locale, directoryHint: .isDirectory)
                        .appending(path: "App Previews", directoryHint: .isDirectory)
                        .appending(path: item.target.exportFolderName, directoryHint: .isDirectory)
                    try FileManager.default.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )
                    let destinationURL = directory.appending(
                        path: String(
                            format: "%02d-%@.mov",
                            targetIndex + 1,
                            sanitizedFileName(item.name)
                        )
                    )
                    statusMessage = "Exporting preview \(index + 1) of \(items.count)…"
                    _ = try await previewExporter.export(
                        sourceURL: sourceURL,
                        target: item.target,
                        trimStart: item.trimStart,
                        trimEnd: item.trimEnd,
                        destinationURL: destinationURL
                    ) { [weak self] itemProgress in
                        self?.progress = (
                            Double(index) + itemProgress
                        ) / Double(items.count)
                    }
                }
                progress = 1
                statusMessage = "Exported \(items.count) App Preview\(items.count == 1 ? "" : "s")"
                NSWorkspace.shared.activateFileViewerSelecting([root])
            } catch {
                fail(error, status: "App Preview export failed")
            }
        }
    }

    func cancelCurrentWork() {
        previewExporter.cancel()
        isWorking = false
        statusMessage = "Cancelling…"
    }

    func refreshPreviewAndPreflight() {
        refreshRenderedScreenshot()
        refreshPreflight()
    }

    private func refreshRenderedScreenshot() {
        guard let panel = selectedPanel, let workspaceURL else {
            renderedScreenshot = nil
            screenshotPreviewLayers = nil
            interactiveScreenshotTransform = nil
            isAdjustingScreenshotPlacement = false
            return
        }
        renderedScreenshot = try? screenshotExporter.renderPreview(
            panel: panel,
            target: selectedTarget,
            packageURL: workspaceURL,
            maximumDimension: 1_400
        )
        screenshotPreviewLayers = try? screenshotExporter.renderPreviewLayers(
            panel: panel,
            target: selectedTarget,
            packageURL: workspaceURL,
            maximumDimension: 1_400
        )
        interactiveScreenshotTransform = nil
        isAdjustingScreenshotPlacement = false
    }

    private func refreshPreflight() {
        guard let workspaceURL else {
            preflightIssues = []
            return
        }
        preflightIssues = screenshotExporter.preflight(
            campaign: campaign,
            packageURL: workspaceURL
        )
    }

    private func persistCampaign(copyToExternalPackage: Bool) async {
        guard let workspaceURL else { return }
        do {
            try await store.write(campaign, to: workspaceURL)
            if copyToExternalPackage, let externalPackageURL {
                let gainedScope = externalPackageURL.startAccessingSecurityScopedResource()
                defer {
                    if gainedScope { externalPackageURL.stopAccessingSecurityScopedResource() }
                }
                try await store.saveCopy(
                    from: workspaceURL,
                    to: externalPackageURL
                )
            }
            statusMessage = externalPackageURL == nil ? "Autosaved locally" : "Saved"
        } catch {
            fail(error, status: "Autosave failed")
        }
    }

    private func resolvedSimulatorUDID() -> String? {
        if let preferred = appController.settings.preferredSimulatorUDID,
           appController.bootedDevices.contains(where: { $0.udid == preferred }) {
            return preferred
        }
        return appController.bootedDevices.first?.udid
    }

    private func uniquePreviewExportDirectory(in parent: URL) -> URL {
        let base = "\(sanitizedFileName(campaign.name))-app-previews"
        var candidate = parent.appending(path: base, directoryHint: .isDirectory)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path()) {
            candidate = parent.appending(
                path: "\(base)-\(suffix)",
                directoryHint: .isDirectory
            )
            suffix += 1
        }
        return candidate
    }

    private func sanitizedFileName(_ value: String) -> String {
        let words = value.lowercased().split { !$0.isLetter && !$0.isNumber }
        return words.isEmpty ? "campaign" : words.joined(separator: "-")
    }

    private func fail(_ error: Error, status: String) {
        lastError = error.localizedDescription
        statusMessage = status
        NSSound.beep()
    }
}
