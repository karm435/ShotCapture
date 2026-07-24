//
//  VideoImportService.swift
//  ShotCapture
//

import AVFoundation
import Foundation

actor VideoImportService {
    func loadVideo(
        at url: URL,
        deletesFileWhenReplaced: Bool = false
    ) async throws -> EditorVideo {
        let asset = AVURLAsset(
            url: url,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )
        let duration = try await asset.load(.duration)
        guard duration.isNumeric, duration.seconds > 0 else {
            throw VideoImportError.invalidDuration
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw VideoImportError.noVideoTrack
        }

        async let naturalSize = videoTrack.load(.naturalSize)
        async let preferredTransform = videoTrack.load(.preferredTransform)
        async let nominalFrameRate = videoTrack.load(.nominalFrameRate)
        async let audioTracks = asset.loadTracks(withMediaType: .audio)

        let loadedNaturalSize = try await naturalSize
        let loadedPreferredTransform = try await preferredTransform
        let loadedNominalFrameRate = try await nominalFrameRate
        let loadedAudioTracks = try await audioTracks

        return EditorVideo(
            url: url,
            displayName: url.deletingPathExtension().lastPathComponent,
            duration: duration,
            naturalSize: loadedNaturalSize,
            preferredTransform: loadedPreferredTransform,
            trackID: videoTrack.trackID,
            nominalFrameRate: loadedNominalFrameRate,
            hasAudio: !loadedAudioTracks.isEmpty,
            deletesFileWhenReplaced: deletesFileWhenReplaced
        )
    }
}
