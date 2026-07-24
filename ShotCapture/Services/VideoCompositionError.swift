//
//  VideoCompositionError.swift
//  ShotCapture
//

import Foundation

nonisolated enum VideoCompositionError: LocalizedError {
    case invalidInstruction
    case missingSourceFrame
    case cannotCreateFrame

    var errorDescription: String? {
        switch self {
        case .invalidInstruction:
            "The video composition instructions are invalid."
        case .missingSourceFrame:
            "A source video frame could not be read."
        case .cannotCreateFrame:
            "A composed video frame could not be created."
        }
    }
}
