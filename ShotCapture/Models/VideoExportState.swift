//
//  VideoExportState.swift
//  ShotCapture
//

enum VideoExportState: Equatable {
    case idle
    case exporting(progress: Double)
    case failed(message: String)

    var isExporting: Bool {
        if case .exporting = self { return true }
        return false
    }

    var progress: Double? {
        guard case .exporting(let progress) = self else { return nil }
        return progress
    }
}
