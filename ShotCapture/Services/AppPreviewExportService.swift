//
//  AppPreviewExportService.swift
//  ShotCapture
//

import AVFoundation
import Foundation

nonisolated struct AppPreviewInspection: Sendable {
    let duration: Double
    let pixelSize: CGSize
    let frameRate: Float
    let audioChannelCount: UInt32
    let audioSampleRate: Double
    let fileSize: Int

    var isDurationCompliant: Bool {
        duration >= 14.95 && duration <= 30.05
    }

    var hasCompliantAudio: Bool {
        audioChannelCount == 2 &&
            (abs(audioSampleRate - 44_100) < 1 || abs(audioSampleRate - 48_000) < 1)
    }
}

nonisolated enum AppPreviewExportError: LocalizedError {
    case noVideoTrack
    case invalidDuration
    case tooShort(Double)
    case unsupportedExport
    case inspectionFailed
    case outputDoesNotMatchTarget
    case silentAudio(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            "The selected App Preview has no video track."
        case .invalidDuration:
            "Choose a valid trim range between 15 and 30 seconds."
        case .tooShort(let duration):
            "App Previews must be at least 15 seconds. This trim is \(duration.formatted(.number.precision(.fractionLength(1)))) seconds."
        case .unsupportedExport:
            "This video cannot be exported as an H.264 App Preview."
        case .inspectionFailed:
            "The exported App Preview could not be inspected."
        case .outputDoesNotMatchTarget:
            "The exported App Preview does not match the selected display size or audio requirements."
        case .silentAudio(let detail):
            "ShotCapture could not create the silent stereo track: \(detail)"
        }
    }
}

@MainActor
final class AppPreviewExportService {
    private var activeSession: AVAssetExportSession?

    func export(
        sourceURL: URL,
        target: AppStoreDisplayTarget,
        trimStart: Double,
        trimEnd: Double,
        destinationURL: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> AppPreviewInspection {
        let duration = trimEnd - trimStart
        guard duration > 0 else { throw AppPreviewExportError.invalidDuration }
        guard duration >= 15 else { throw AppPreviewExportError.tooShort(duration) }
        guard duration <= 30.001 else { throw AppPreviewExportError.invalidDuration }

        let sourceAsset = AVURLAsset(
            url: sourceURL,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )
        guard let sourceVideoTrack = try await sourceAsset.loadTracks(withMediaType: .video).first else {
            throw AppPreviewExportError.noVideoTrack
        }

        let start = CMTime(seconds: trimStart, preferredTimescale: 600)
        let requestedRange = CMTimeRange(
            start: start,
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AppPreviewExportError.unsupportedExport
        }
        try compositionVideoTrack.insertTimeRange(
            requestedRange,
            of: sourceVideoTrack,
            at: .zero
        )

        let sourceTransform = try await sourceVideoTrack.load(.preferredTransform)
        let sourceNaturalSize = try await sourceVideoTrack.load(.naturalSize)
        let nominalFrameRate = try await sourceVideoTrack.load(.nominalFrameRate)
        let videoComposition = makeVideoComposition(
            compositionTrack: compositionVideoTrack,
            sourceSize: sourceNaturalSize,
            sourceTransform: sourceTransform,
            targetSize: target.previewSize,
            sourceFrameRate: nominalFrameRate,
            duration: duration
        )

        let sourceAudioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        var temporarySilenceURL: URL?
        if let sourceAudioTrack = sourceAudioTracks.first {
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw AppPreviewExportError.unsupportedExport
            }
            try compositionAudioTrack.insertTimeRange(
                requestedRange,
                of: sourceAudioTrack,
                at: .zero
            )
        } else {
            let silenceURL = try makeSilentStereoAudio(duration: duration)
            temporarySilenceURL = silenceURL
            let silenceAsset = AVURLAsset(url: silenceURL)
            guard let silenceTrack = try await silenceAsset.loadTracks(withMediaType: .audio).first,
                  let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                  ) else {
                throw AppPreviewExportError.unsupportedExport
            }
            try compositionAudioTrack.insertTimeRange(
                CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                ),
                of: silenceTrack,
                at: .zero
            )
        }
        defer {
            if let temporarySilenceURL {
                try? FileManager.default.removeItem(at: temporarySilenceURL)
            }
        }

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AppPreviewExportError.unsupportedExport
        }
        if FileManager.default.fileExists(atPath: destinationURL.path()) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        session.videoComposition = videoComposition
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
                try await session.export(to: destinationURL, as: .mov)
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.cancel()
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
        progress(1)

        let inspection = try await inspect(url: destinationURL)
        let expected = target.previewSize
        guard abs(inspection.pixelSize.width - expected.width) < 1,
              abs(inspection.pixelSize.height - expected.height) < 1,
              inspection.frameRate <= 30.01,
              inspection.hasCompliantAudio,
              inspection.fileSize <= 500_000_000 else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw AppPreviewExportError.outputDoesNotMatchTarget
        }
        return inspection
    }

    func inspect(url: URL) async throws -> AppPreviewInspection {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AppPreviewExportError.inspectionFailed
        }

        async let naturalSize = videoTrack.load(.naturalSize)
        async let transform = videoTrack.load(.preferredTransform)
        async let frameRate = videoTrack.load(.nominalFrameRate)
        async let audioDescriptions = audioTrack.load(.formatDescriptions)
        let loadedSize = try await naturalSize
        let loadedTransform = try await transform
        let displayRect = CGRect(origin: .zero, size: loadedSize).applying(loadedTransform)
        let descriptions = try await audioDescriptions
        guard let audioDescription = descriptions.first,
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(
                audioDescription
              )?.pointee else {
            throw AppPreviewExportError.inspectionFailed
        }
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return AppPreviewInspection(
            duration: duration,
            pixelSize: CGSize(
                width: abs(displayRect.width),
                height: abs(displayRect.height)
            ),
            frameRate: try await frameRate,
            audioChannelCount: streamDescription.mChannelsPerFrame,
            audioSampleRate: streamDescription.mSampleRate,
            fileSize: fileSize
        )
    }

    func cancel() {
        activeSession?.cancelExport()
    }

    private func makeVideoComposition(
        compositionTrack: AVCompositionTrack,
        sourceSize: CGSize,
        sourceTransform: CGAffineTransform,
        targetSize: CGSize,
        sourceFrameRate: Float,
        duration: Double
    ) -> AVMutableVideoComposition {
        let transformedRect = CGRect(origin: .zero, size: sourceSize)
            .applying(sourceTransform)
        let displaySize = CGSize(
            width: abs(transformedRect.width),
            height: abs(transformedRect.height)
        )
        let fillScale = max(
            targetSize.width / displaySize.width,
            targetSize.height / displaySize.height
        )
        let scaledSize = CGSize(
            width: displaySize.width * fillScale,
            height: displaySize.height * fillScale
        )
        var transform = sourceTransform
        transform = transform.concatenating(
            CGAffineTransform(translationX: -transformedRect.minX, y: -transformedRect.minY)
        )
        transform = transform.concatenating(
            CGAffineTransform(scaleX: fillScale, y: fillScale)
        )
        transform = transform.concatenating(
            CGAffineTransform(
                translationX: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )
        )

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: compositionTrack
        )
        layerInstruction.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
        instruction.layerInstructions = [layerInstruction]

        let composition = AVMutableVideoComposition()
        composition.instructions = [instruction]
        composition.renderSize = targetSize
        let resolvedFrameRate = max(1, min(30, sourceFrameRate > 0 ? sourceFrameRate : 30))
        composition.frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(resolvedFrameRate.rounded())
        )
        return composition
    }

    private func makeSilentStereoAudio(duration: Double) throws -> URL {
        let sampleRate: UInt32 = 44_100
        let channelCount: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let bytesPerFrame = UInt32(channelCount) * UInt32(bitsPerSample / 8)
        let frameCount = UInt32((duration * Double(sampleRate)).rounded(.up))
        let audioByteCount = frameCount * bytesPerFrame
        var wave = Data(capacity: 44 + Int(audioByteCount))

        func appendASCII(_ value: String) {
            wave.append(value.data(using: .ascii)!)
        }
        func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { wave.append(contentsOf: $0) }
        }

        appendASCII("RIFF")
        appendLittleEndian(UInt32(36) + audioByteCount)
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendLittleEndian(UInt32(16))
        appendLittleEndian(UInt16(1))
        appendLittleEndian(channelCount)
        appendLittleEndian(sampleRate)
        appendLittleEndian(sampleRate * bytesPerFrame)
        appendLittleEndian(UInt16(bytesPerFrame))
        appendLittleEndian(bitsPerSample)
        appendASCII("data")
        appendLittleEndian(audioByteCount)
        wave.append(Data(count: Int(audioByteCount)))

        let url = URL.temporaryDirectory.appending(
            path: "ShotCapture-Silence-\(UUID().uuidString).wav"
        )
        do {
            try wave.write(to: url, options: .atomic)
        } catch {
            throw AppPreviewExportError.silentAudio(error.localizedDescription)
        }
        return url
    }
}
