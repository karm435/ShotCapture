//
//  BackgroundStyle.swift
//  ShotCapture
//

import AppKit
import Foundation
import SwiftUI

nonisolated enum BackgroundKind: String, Codable, Hashable, Sendable {
    case presetImage
    case solid
    case linearGradient
    case radialGradient
}

nonisolated struct GradientStop: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var location: Double
    var hex: String

    init(id: UUID = UUID(), location: Double, hex: String) {
        self.id = id
        self.location = location
        self.hex = hex
    }

    var color: Color {
        Color(nsColor: NSColor(hex: hex) ?? .gray)
    }

    var nsColor: NSColor {
        NSColor(hex: hex) ?? .gray
    }
}

nonisolated struct BackgroundStyle: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: BackgroundKind
    /// Asset catalog / bundle image name for preset images.
    var imageName: String?
    var solidHex: String?
    var gradientStops: [GradientStop]
    var gradientAngleDegrees: Double
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: BackgroundKind,
        imageName: String? = nil,
        solidHex: String? = nil,
        gradientStops: [GradientStop] = [],
        gradientAngleDegrees: Double = 135,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.imageName = imageName
        self.solidHex = solidHex
        self.gradientStops = gradientStops
        self.gradientAngleDegrees = gradientAngleDegrees
        self.isCustom = isCustom
    }

    static let presets: [BackgroundStyle] = [
        .image(id: "11111111-0001-4000-8000-000000000001", "Midnight Bloom", "bg_01_midnight_bloom"),
        .image(id: "11111111-0001-4000-8000-000000000002", "Ocean Mist", "bg_02_ocean_mist"),
        .image(id: "11111111-0001-4000-8000-000000000003", "Sunset Drift", "bg_03_sunset_drift"),
        .image(id: "11111111-0001-4000-8000-000000000004", "Aurora Soft", "bg_04_aurora_soft"),
        .image(id: "11111111-0001-4000-8000-000000000005", "Forest Haze", "bg_05_forest_haze"),
        .image(id: "11111111-0001-4000-8000-000000000006", "Coral Glow", "bg_06_coral_glow"),
        .image(id: "11111111-0001-4000-8000-000000000007", "Slate Studio", "bg_07_slate_studio"),
        .image(id: "11111111-0001-4000-8000-000000000008", "Peach Cream", "bg_08_peach_cream"),
        .image(id: "11111111-0001-4000-8000-000000000009", "Indigo Night", "bg_09_indigo_night"),
        .image(id: "11111111-0001-4000-8000-00000000000A", "Mint Fog", "bg_10_mint_fog"),
        .image(id: "11111111-0001-4000-8000-00000000000B", "Ember Fade", "bg_11_ember_fade"),
        .image(id: "11111111-0001-4000-8000-00000000000C", "Skyline Blue", "bg_12_skyline_blue"),
        .image(id: "11111111-0001-4000-8000-00000000000D", "Lavender Field", "bg_13_lavender_field"),
        .image(id: "11111111-0001-4000-8000-00000000000E", "Graphite Mesh", "bg_14_graphite_mesh"),
        .image(id: "11111111-0001-4000-8000-00000000000F", "Golden Hour", "bg_15_golden_hour"),
        .image(id: "11111111-0001-4000-8000-000000000010", "Teal Depth", "bg_16_teal_depth"),
        .image(id: "11111111-0001-4000-8000-000000000011", "Rose Quartz", "bg_17_rose_quartz"),
        .image(id: "11111111-0001-4000-8000-000000000012", "Neon Dusk", "bg_18_neon_dusk"),
        .image(id: "11111111-0001-4000-8000-000000000013", "Paper Warm", "bg_19_paper_warm"),
        .image(id: "11111111-0001-4000-8000-000000000014", "Ice Crystal", "bg_20_ice_crystal"),
        .image(id: "11111111-0001-4000-8000-000000000015", "Moss Quiet", "bg_21_moss_quiet"),
        .image(id: "11111111-0001-4000-8000-000000000016", "Berry Pop", "bg_22_berry_pop"),
        .linear(
            id: "11111111-0001-4000-8000-000000000017",
            "Studio Black",
            stops: [
                GradientStop(location: 0, hex: "#1A1A1A"),
                GradientStop(location: 1, hex: "#0A0A0A")
            ],
            angle: 180
        ),
        .linear(
            id: "11111111-0001-4000-8000-000000000018",
            "Clean White",
            stops: [
                GradientStop(location: 0, hex: "#FFFFFF"),
                GradientStop(location: 1, hex: "#F2F2F2")
            ],
            angle: 180
        )
    ]

    private static func image(id: String, _ name: String, _ imageName: String) -> BackgroundStyle {
        BackgroundStyle(id: UUID(uuidString: id)!, name: name, kind: .presetImage, imageName: imageName)
    }

    private static func linear(id: String, _ name: String, stops: [GradientStop], angle: Double) -> BackgroundStyle {
        BackgroundStyle(
            id: UUID(uuidString: id)!,
            name: name,
            kind: .linearGradient,
            gradientStops: stops,
            gradientAngleDegrees: angle
        )
    }
}

extension NSColor {
    nonisolated convenience init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let hasAlpha = cleaned.count == 8
        let a = hasAlpha ? CGFloat((value & 0xFF000000) >> 24) / 255 : 1
        let r = CGFloat((value & 0x00FF0000) >> 16) / 255
        let g = CGFloat((value & 0x0000FF00) >> 8) / 255
        let b = CGFloat(value & 0x000000FF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    nonisolated var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
