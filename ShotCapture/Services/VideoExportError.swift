//
//  VideoExportError.swift
//  ShotCapture
//

import Foundation

enum VideoExportError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        "This video cannot be exported with the selected composition."
    }
}
