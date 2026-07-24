//
//  SimulatorRecordingError.swift
//  ShotCapture
//

import Foundation

enum SimulatorRecordingError: LocalizedError {
    case alreadyRecording
    case notRecording
    case processFailed(String)
    case emptyRecording

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "A Simulator recording is already in progress."
        case .notRecording:
            "There is no active Simulator recording to stop."
        case .processFailed(let detail):
            "Simulator recording failed: \(detail)"
        case .emptyRecording:
            "Simulator did not produce a readable video file."
        }
    }
}
