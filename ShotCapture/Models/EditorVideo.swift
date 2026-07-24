//
//  EditorVideo.swift
//  ShotCapture
//

import AVFoundation
import Foundation

nonisolated struct EditorVideo: Equatable, Sendable {
    let url: URL
    let displayName: String
    let duration: CMTime
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let trackID: CMPersistentTrackID
    let nominalFrameRate: Float
    let hasAudio: Bool
    let deletesFileWhenReplaced: Bool

    var durationSeconds: Double {
        let seconds = duration.seconds
        return seconds.isFinite ? max(0, seconds) : 0
    }

    var displaySize: CGSize {
        let transformed = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }
}
