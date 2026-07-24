//
//  VideoExportService.swift
//  ShotCapture
//

import AVFoundation
import Foundation

@MainActor
final class VideoExportService {
    private var activeSession: AVAssetExportSession?

    func export(
        video: EditorVideo,
        composition: AVVideoComposition,
        trimRange: CMTimeRange,
        to destination: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: video.url)
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoExportError.unsupported
        }

        if FileManager.default.fileExists(atPath: destination.path()) {
            try FileManager.default.removeItem(at: destination)
        }
        session.videoComposition = composition
        session.timeRange = trimRange
        session.shouldOptimizeForNetworkUse = true
        activeSession = session

        let progressTask = Task { @MainActor in
            for await state in session.states(updateInterval: 0.15) {
                if case .exporting(let exportProgress) = state {
                    progress(exportProgress.fractionCompleted)
                }
            }
        }
        defer {
            progressTask.cancel()
            activeSession = nil
        }

        do {
            try await withTaskCancellationHandler {
                try await session.export(to: destination, as: .mp4)
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.cancel()
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        progress(1)
    }

    func cancel() {
        activeSession?.cancelExport()
    }
}
