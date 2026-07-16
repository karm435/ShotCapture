//
//  CompositionService.swift
//  ShotCapture
//

import AppKit
import Foundation

struct CompositionRequest {
    let screenshot: NSImage
    let platform: SocialPlatform
    let background: BackgroundStyle
    let paddingPercent: Double
    let deviceCornerRadius: Double
    let showDeviceShadow: Bool
    let watermarkEnabled: Bool
    let watermarkText: String
}

enum CompositionService {
    static func compose(_ request: CompositionRequest) -> NSImage {
        let canvas = request.platform.canvasSize
        let width = Int(canvas.width)
        let height = Int(canvas.height)

        let image = NSImage(size: canvas)
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else { return image }

        drawBackground(request.background, in: context, size: canvas)

        let padding = min(canvas.width, canvas.height) * CGFloat(request.paddingPercent)
        let maxDeviceWidth = canvas.width - (padding * 2)
        let maxDeviceHeight = canvas.height - (padding * 2)

        let shotSize = request.screenshot.size
        let fitScale = min(maxDeviceWidth / shotSize.width, maxDeviceHeight / shotSize.height)
        let drawnSize = CGSize(width: shotSize.width * fitScale, height: shotSize.height * fitScale)
        let origin = CGPoint(
            x: (canvas.width - drawnSize.width) / 2,
            y: (canvas.height - drawnSize.height) / 2
        )
        let deviceRect = CGRect(origin: origin, size: drawnSize)
        let corner = CGFloat(request.deviceCornerRadius) * fitScale

        if request.showDeviceShadow {
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: -12),
                blur: 36,
                color: NSColor.black.withAlphaComponent(0.35).cgColor
            )
            let shadowPath = CGPath(
                roundedRect: deviceRect,
                cornerWidth: corner,
                cornerHeight: corner,
                transform: nil
            )
            context.addPath(shadowPath)
            context.setFillColor(NSColor.black.withAlphaComponent(0.01).cgColor)
            context.fillPath()
            context.restoreGState()
        }

        context.saveGState()
        let clip = CGPath(
            roundedRect: deviceRect,
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )
        context.addPath(clip)
        context.clip()
        request.screenshot.draw(in: deviceRect)
        context.restoreGState()

        // Subtle device bezel
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        context.setLineWidth(2)
        context.addPath(clip)
        context.strokePath()
        context.restoreGState()

        if request.watermarkEnabled {
            drawWatermark(
                text: request.watermarkText,
                in: context,
                canvas: canvas
            )
        }

        // Force width/height integers into bitmap for export fidelity
        _ = width
        _ = height

        return image
    }

    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Background

    private static func drawBackground(_ style: BackgroundStyle, in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        switch style.kind {
        case .presetImage:
            if let name = style.imageName,
               let image = NSImage(named: name) ?? loadBundleBackground(named: name) {
                drawImageFilling(image, in: rect, context: context)
                return
            }
            fillGradient(
                stops: [
                    GradientStop(location: 0, hex: "#1E293B"),
                    GradientStop(location: 1, hex: "#0F172A")
                ],
                angle: 135,
                in: context,
                size: size
            )

        case .solid:
            let color = NSColor(hex: style.solidHex ?? "#111111") ?? .black
            context.setFillColor(color.cgColor)
            context.fill(rect)

        case .linearGradient:
            fillGradient(stops: style.gradientStops, angle: style.gradientAngleDegrees, in: context, size: size)

        case .radialGradient:
            fillRadial(stops: style.gradientStops, in: context, size: size)
        }
    }

    private static func loadBundleBackground(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Backgrounds")
                ?? Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func drawImageFilling(_ image: NSImage, in rect: CGRect, context: CGContext) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawOrigin = CGPoint(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2
        )
        image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
    }

    private static func fillGradient(
        stops: [GradientStop],
        angle: Double,
        in context: CGContext,
        size: CGSize
    ) {
        let sorted = stops.sorted { $0.location < $1.location }
        guard sorted.count >= 2 else {
            context.setFillColor(NSColor.darkGray.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            return
        }

        let colors = sorted.map { $0.nsColor.cgColor } as CFArray
        let locations = sorted.map { CGFloat($0.location) }
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return }

        let radians = angle * .pi / 180
        let dx = cos(radians)
        let dy = sin(radians)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let length = hypot(size.width, size.height) / 2
        let start = CGPoint(x: center.x - dx * length, y: center.y - dy * length)
        let end = CGPoint(x: center.x + dx * length, y: center.y + dy * length)

        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func fillRadial(stops: [GradientStop], in context: CGContext, size: CGSize) {
        let sorted = stops.sorted { $0.location < $1.location }
        guard sorted.count >= 2,
              let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: sorted.map { $0.nsColor.cgColor } as CFArray,
                locations: sorted.map { CGFloat($0.location) }
              ) else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = hypot(size.width, size.height) / 2
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
    }

    private static func drawWatermark(text: String, in context: CGContext, canvas: CGSize) {
        let fontSize = max(14, min(canvas.width, canvas.height) * 0.028)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.72),
            .paragraphStyle: paragraph
        ]

        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let margin = max(16, min(canvas.width, canvas.height) * 0.035)
        let rect = CGRect(
            x: canvas.width - textSize.width - margin,
            y: margin,
            width: textSize.width,
            height: textSize.height
        )

        // Soft shadow behind watermark for contrast on light backgrounds
        let shadowAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.black.withAlphaComponent(0.35),
            .paragraphStyle: paragraph
        ]
        NSAttributedString(string: text, attributes: shadowAttributes)
            .draw(in: rect.offsetBy(dx: 0, dy: -1))
        attributed.draw(in: rect)
    }
}
