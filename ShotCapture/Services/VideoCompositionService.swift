//
//  VideoCompositionService.swift
//  ShotCapture
//

import AVFoundation
import Foundation

nonisolated enum VideoCompositionService {
    static func makeComposition(
        for video: EditorVideo,
        request: CompositionRequest
    ) -> AVVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = ShotVideoCompositor.self
        composition.renderSize = request.canvasSize
        composition.frameDuration = CMTime(
            value: 1,
            timescale: outputFrameRate(for: video)
        )
        composition.instructions = [
            ShotVideoCompositionInstruction(
                timeRange: CMTimeRange(start: .zero, duration: video.duration),
                sourceTrackID: video.trackID,
                sourceTransform: video.preferredTransform,
                compositionRequest: request
            )
        ]
        return composition
    }

    private static func outputFrameRate(for video: EditorVideo) -> CMTimeScale {
        guard video.nominalFrameRate.isFinite, video.nominalFrameRate > 0 else {
            return 30
        }
        return CMTimeScale(min(max(video.nominalFrameRate.rounded(), 24), 60))
    }
}
