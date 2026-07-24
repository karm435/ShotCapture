//
//  ShotVideoCompositionInstruction.swift
//  ShotCapture
//

import AVFoundation
import Foundation

nonisolated final class ShotVideoCompositionInstruction: NSObject,
    AVVideoCompositionInstructionProtocol,
    @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = true
    let containsTweening = false
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let sourceTrackID: CMPersistentTrackID
    let sourceTransform: CGAffineTransform
    let compositionRequest: CompositionRequest

    init(
        timeRange: CMTimeRange,
        sourceTrackID: CMPersistentTrackID,
        sourceTransform: CGAffineTransform,
        compositionRequest: CompositionRequest
    ) {
        self.timeRange = timeRange
        self.sourceTrackID = sourceTrackID
        self.sourceTransform = sourceTransform
        self.compositionRequest = compositionRequest
        requiredSourceTrackIDs = [NSNumber(value: sourceTrackID)]
        super.init()
    }
}
