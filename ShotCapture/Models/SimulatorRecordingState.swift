//
//  SimulatorRecordingState.swift
//  ShotCapture
//

enum SimulatorRecordingState: Equatable {
    case idle
    case starting
    case recording
    case finalizing

    var isActive: Bool {
        self != .idle
    }
}
