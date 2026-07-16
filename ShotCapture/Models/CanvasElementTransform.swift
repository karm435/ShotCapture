//
//  CanvasElementTransform.swift
//  ShotCapture
//

import AppKit
import Foundation

struct CanvasElementTransform: Codable, Equatable, Sendable {
    /// Horizontal offset from the canvas center as a fraction of canvas width.
    var offsetX: Double

    /// Vertical offset from the canvas center as a fraction of canvas height.
    /// Positive values move the element down in the editor.
    var offsetY: Double

    var scale: Double
    var rotationDegrees: Double

    static let screenshotDefault = CanvasElementTransform(
        offsetX: 0,
        offsetY: 0,
        scale: 1,
        rotationDegrees: 0
    )

    static let titleDefault = CanvasElementTransform(
        offsetX: 0,
        offsetY: -0.38,
        scale: 1,
        rotationDegrees: 0
    )
}

enum DeviceFrameStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case none
    case genericPhone
    case importedProductBezel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .genericPhone: "Generic iPhone"
        case .importedProductBezel: "Imported Bezel"
        }
    }
}

struct ImportedProductBezel: Identifiable {
    let id = UUID()
    let name: String
    let image: NSImage
}
