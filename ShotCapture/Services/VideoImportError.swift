//
//  VideoImportError.swift
//  ShotCapture
//

import Foundation

enum VideoImportError: LocalizedError {
    case noVideoTrack
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            "The selected file does not contain a readable video track."
        case .invalidDuration:
            "The selected video has an invalid duration."
        }
    }
}
