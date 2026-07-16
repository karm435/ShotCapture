//
//  BackgroundCanvas.swift
//  ShotCapture
//

import AppKit
import SwiftUI

struct BackgroundCanvas: View {
    let style: BackgroundStyle

    var body: some View {
        switch style.kind {
        case .presetImage:
            if let name = style.imageName {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .overlay {
                        // Fallback fill when asset missing
                        if NSImage(named: name) == nil {
                            LinearGradient(
                                colors: [Color(hex: "#1E293B"), Color(hex: "#0F172A")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
            } else {
                Color.gray
            }

        case .solid:
            Color(hex: style.solidHex ?? "#111111")

        case .linearGradient:
            LinearGradient(
                stops: style.gradientStops
                    .sorted { $0.location < $1.location }
                    .map { .init(color: $0.color, location: $0.location) },
                startPoint: unitPoint(for: style.gradientAngleDegrees, start: true),
                endPoint: unitPoint(for: style.gradientAngleDegrees, start: false)
            )

        case .radialGradient:
            RadialGradient(
                stops: style.gradientStops
                    .sorted { $0.location < $1.location }
                    .map { .init(color: $0.color, location: $0.location) },
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
        }
    }

    private func unitPoint(for degrees: Double, start: Bool) -> UnitPoint {
        let radians = (degrees + (start ? 180 : 0)) * .pi / 180
        let x = 0.5 + 0.5 * cos(radians)
        let y = 0.5 + 0.5 * sin(radians)
        return UnitPoint(x: x, y: y)
    }
}

extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
