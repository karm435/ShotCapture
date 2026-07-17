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
    var tiltXDegrees: Double
    var tiltYDegrees: Double
    /// Multiplier for the selected device's physical depth. One uses Apple's dimensions.
    var depthScale: Double

    init(
        offsetX: Double,
        offsetY: Double,
        scale: Double,
        rotationDegrees: Double,
        tiltXDegrees: Double = 0,
        tiltYDegrees: Double = 0,
        depthScale: Double = 1
    ) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.tiltXDegrees = tiltXDegrees
        self.tiltYDegrees = tiltYDegrees
        self.depthScale = depthScale
    }

    private enum CodingKeys: String, CodingKey {
        case offsetX
        case offsetY
        case scale
        case rotationDegrees
        case tiltXDegrees
        case tiltYDegrees
        case depthScale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offsetX = try container.decode(Double.self, forKey: .offsetX)
        offsetY = try container.decode(Double.self, forKey: .offsetY)
        scale = try container.decode(Double.self, forKey: .scale)
        rotationDegrees = try container.decode(Double.self, forKey: .rotationDegrees)
        tiltXDegrees = try container.decodeIfPresent(Double.self, forKey: .tiltXDegrees) ?? 0
        tiltYDegrees = try container.decodeIfPresent(Double.self, forKey: .tiltYDegrees) ?? 0
        depthScale = try container.decodeIfPresent(Double.self, forKey: .depthScale) ?? 1
    }

    static let screenshotDefault = CanvasElementTransform(
        offsetX: 0,
        offsetY: 0,
        scale: 1,
        rotationDegrees: 0,
        tiltXDegrees: 0,
        tiltYDegrees: 0,
        depthScale: 1
    )

    static let titleDefault = CanvasElementTransform(
        offsetX: 0,
        offsetY: -0.38,
        scale: 1,
        rotationDegrees: 0,
        tiltXDegrees: 0,
        tiltYDegrees: 0,
        depthScale: 1
    )
}

enum DeviceFrameStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case none
    case genericPhone
    case appleProductBezel
    case importedProductBezel

    var id: String { rawValue }

    static var availableCases: [DeviceFrameStyle] {
        allCases.filter { style in
            style != .appleProductBezel || ProductBezelDevice.bundledResourcesAvailable
        }
    }

    var displayName: String {
        switch self {
        case .none: "None"
        case .genericPhone: "Generic iPhone"
        case .appleProductBezel: "Apple Product Bezel"
        case .importedProductBezel: "Imported Bezel"
        }
    }
}

struct ImportedProductBezel: Identifiable {
    let id = UUID()
    let name: String
    let image: NSImage
}
