//
//  ProductBezelDevice.swift
//  ShotCapture
//

import AppKit
import Foundation

enum ProductBezelDevice: String, CaseIterable, Codable, Identifiable, Sendable {
    case iPhone17 = "iPhone 17"
    case iPhoneAir = "iPhone Air"
    case iPhone17Pro = "iPhone 17 Pro"
    case iPhone17ProMax = "iPhone 17 Pro Max"
    case iPhone16 = "iPhone 16"
    case iPhone16Plus = "iPhone 16 Plus"
    case iPhone16Pro = "iPhone 16 Pro"
    case iPhone16ProMax = "iPhone 16 Pro Max"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Distribution builds omit Apple's licensed design-resource files. Keep the
    /// built-in picker available only when those resources exist in this bundle.
    static var bundledResourcesAvailable: Bool {
        let sampleName = ProductBezelDevice.iPhone17.resourceName(
            finish: ProductBezelDevice.iPhone17.defaultFinish,
            isLandscape: false
        )
        return Bundle.main.url(
            forResource: sampleName,
            withExtension: "png",
            subdirectory: "ProductBezels"
        ) != nil || Bundle.main.url(forResource: sampleName, withExtension: "png") != nil
    }

    var finishes: [String] {
        switch self {
        case .iPhone17:
            ["Black", "Lavender", "Mist Blue", "Sage", "White"]
        case .iPhoneAir:
            ["Space Black", "Sky Blue", "Light Gold", "Cloud White"]
        case .iPhone17Pro, .iPhone17ProMax:
            ["Deep Blue", "Cosmic Orange", "Silver"]
        case .iPhone16, .iPhone16Plus:
            ["Black", "Pink", "Teal", "Ultramarine", "White"]
        case .iPhone16Pro, .iPhone16ProMax:
            ["Black Titanium", "Desert Titanium", "Natural Titanium", "White Titanium"]
        }
    }

    var defaultFinish: String { finishes[0] }

    /// Physical device depth divided by body width, using Apple's published dimensions.
    var thicknessToWidthRatio: Double {
        switch self {
        case .iPhone17:
            7.95 / 71.5
        case .iPhoneAir:
            5.64 / 74.7
        case .iPhone17Pro:
            8.75 / 71.9
        case .iPhone17ProMax:
            8.75 / 78.0
        case .iPhone16:
            7.80 / 71.6
        case .iPhone16Plus:
            7.80 / 77.8
        case .iPhone16Pro:
            8.25 / 71.5
        case .iPhone16ProMax:
            8.25 / 77.6
        }
    }

    func edgeTint(finish: String) -> NSColor {
        switch finish {
        case "White", "Cloud White", "Silver", "White Titanium":
            NSColor(calibratedRed: 0.67, green: 0.70, blue: 0.73, alpha: 1)
        case "Lavender":
            NSColor(calibratedRed: 0.48, green: 0.45, blue: 0.56, alpha: 1)
        case "Mist Blue", "Sky Blue":
            NSColor(calibratedRed: 0.32, green: 0.48, blue: 0.60, alpha: 1)
        case "Sage", "Teal":
            NSColor(calibratedRed: 0.28, green: 0.47, blue: 0.43, alpha: 1)
        case "Light Gold":
            NSColor(calibratedRed: 0.66, green: 0.57, blue: 0.42, alpha: 1)
        case "Cosmic Orange", "Desert Titanium":
            NSColor(calibratedRed: 0.61, green: 0.37, blue: 0.23, alpha: 1)
        case "Pink":
            NSColor(calibratedRed: 0.62, green: 0.39, blue: 0.45, alpha: 1)
        case "Ultramarine", "Deep Blue":
            NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.35, alpha: 1)
        case "Natural Titanium":
            NSColor(calibratedRed: 0.48, green: 0.46, blue: 0.42, alpha: 1)
        default:
            NSColor(calibratedWhite: 0.16, alpha: 1)
        }
    }

    func resourceName(finish: String, isLandscape: Bool) -> String {
        let validFinish = finishes.contains(finish) ? finish : defaultFinish
        let orientation = isLandscape ? "Landscape" : "Portrait"
        return "\(displayName) - \(validFinish) - \(orientation)"
    }

    /// Normalized transparent screen aperture measured from Apple's supplied PNG pixels.
    func screenAperture(isLandscape: Bool) -> CGRect {
        let portrait: CGRect
        switch self {
        case .iPhone17, .iPhone17Pro, .iPhone16Pro:
            portrait = CGRect(x: 72.0 / 1350.0, y: 69.0 / 2760.0, width: 1206.0 / 1350.0, height: 2622.0 / 2760.0)
        case .iPhoneAir:
            portrait = CGRect(x: 60.0 / 1380.0, y: 72.0 / 2880.0, width: 1260.0 / 1380.0, height: 2736.0 / 2880.0)
        case .iPhone17ProMax, .iPhone16ProMax:
            portrait = CGRect(x: 75.0 / 1470.0, y: 66.0 / 3000.0, width: 1320.0 / 1470.0, height: 2868.0 / 3000.0)
        case .iPhone16:
            portrait = CGRect(x: 90.0 / 1359.0, y: 90.0 / 2736.0, width: 1179.0 / 1359.0, height: 2556.0 / 2736.0)
        case .iPhone16Plus:
            portrait = CGRect(x: 90.0 / 1470.0, y: 87.0 / 2970.0, width: 1290.0 / 1470.0, height: 2796.0 / 2970.0)
        }

        guard isLandscape else { return portrait }
        return CGRect(
            x: portrait.minY,
            y: portrait.minX,
            width: portrait.height,
            height: portrait.width
        )
    }
}
