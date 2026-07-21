//
//  CompositionService.swift
//  ShotCapture
//

import AppKit
import CoreImage
import Foundation

struct CompositionRequest {
    let screenshot: NSImage
    let platform: SocialPlatform
    let background: BackgroundStyle
    let paddingPercent: Double
    let deviceCornerRadius: Double
    let showDeviceShadow: Bool
    let screenshotTransform: CanvasElementTransform
    let deviceFrameStyle: DeviceFrameStyle
    let productBezel: NSImage?
    let productBezelAperture: CGRect?
    let productBezelScreenCornerRadiusRatio: Double
    let importedBezelInset: Double
    let deviceDepthRatio: Double
    let deviceEdgeTint: NSColor
    let titleEnabled: Bool
    let titleText: String
    let titleFontName: String
    let titleFontSize: Double
    let titleTransform: CanvasElementTransform
    let watermarkEnabled: Bool
    let watermarkText: String

    init(
        screenshot: NSImage,
        platform: SocialPlatform,
        background: BackgroundStyle,
        paddingPercent: Double,
        deviceCornerRadius: Double,
        showDeviceShadow: Bool,
        watermarkEnabled: Bool,
        watermarkText: String,
        screenshotTransform: CanvasElementTransform = .screenshotDefault,
        deviceFrameStyle: DeviceFrameStyle = .genericPhone,
        productBezel: NSImage? = nil,
        productBezelAperture: CGRect? = nil,
        productBezelScreenCornerRadiusRatio: Double = 0.105,
        importedBezelInset: Double = 0.055,
        deviceDepthRatio: Double = 0.11,
        deviceEdgeTint: NSColor = NSColor(calibratedWhite: 0.16, alpha: 1),
        titleEnabled: Bool = false,
        titleText: String = "",
        titleFontName: String = NSFont.systemFont(ofSize: 72, weight: .bold).fontName,
        titleFontSize: Double = 72,
        titleTransform: CanvasElementTransform = .titleDefault
    ) {
        self.screenshot = screenshot
        self.platform = platform
        self.background = background
        self.paddingPercent = paddingPercent
        self.deviceCornerRadius = deviceCornerRadius
        self.showDeviceShadow = showDeviceShadow
        self.watermarkEnabled = watermarkEnabled
        self.watermarkText = watermarkText
        self.screenshotTransform = screenshotTransform
        self.deviceFrameStyle = deviceFrameStyle
        self.productBezel = productBezel
        self.productBezelAperture = productBezelAperture
        self.productBezelScreenCornerRadiusRatio = productBezelScreenCornerRadiusRatio
        self.importedBezelInset = importedBezelInset
        self.deviceDepthRatio = deviceDepthRatio
        self.deviceEdgeTint = deviceEdgeTint
        self.titleEnabled = titleEnabled
        self.titleText = titleText
        self.titleFontName = titleFontName
        self.titleFontSize = titleFontSize
        self.titleTransform = titleTransform
    }
}

enum CompositionService {
    private static let coreImageContext = CIContext(options: [
        .cacheIntermediates: true
    ])

    static func compose(_ request: CompositionRequest) -> NSImage {
        let canvas = request.platform.canvasSize
        let width = Int(canvas.width)
        let height = Int(canvas.height)

        let image = NSImage(size: canvas)
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else { return image }

        drawBackground(request.background, in: context, size: canvas)

        drawScreenshot(request, in: context, canvas: canvas)

        if request.titleEnabled, !request.titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drawTitle(request, in: context, canvas: canvas)
        }

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

    private static func drawScreenshot(
        _ request: CompositionRequest,
        in context: CGContext,
        canvas: CGSize
    ) {
        let padding = min(canvas.width, canvas.height) * CGFloat(request.paddingPercent)
        let maxSize = CGSize(
            width: canvas.width - (padding * 2),
            height: canvas.height - (padding * 2)
        )
        let transform = request.screenshotTransform
        let center = CGPoint(
            x: canvas.width / 2 + canvas.width * CGFloat(transform.offsetX),
            y: canvas.height / 2 - canvas.height * CGFloat(transform.offsetY)
        )

        guard let deviceLayer = makeDeviceLayer(request, maxSize: maxSize) else { return }
        let perspective = perspectiveTransform(
            deviceLayer,
            using: transform,
            depthRatio: request.deviceDepthRatio
        ) ?? (image: deviceLayer, depthOffset: .zero)
        let renderedLayer = addDeviceDepth(
            to: perspective.image,
            offset: perspective.depthOffset,
            edgeTint: request.deviceEdgeTint
        )
        let layerRect = CGRect(
            x: center.x - renderedLayer.frontCenter.x,
            y: center.y - renderedLayer.frontCenter.y,
            width: renderedLayer.image.size.width,
            height: renderedLayer.image.size.height
        )

        context.saveGState()
        if request.showDeviceShadow {
            context.setShadow(
                offset: CGSize(width: 0, height: -12),
                blur: 36,
                color: NSColor.black.withAlphaComponent(0.35).cgColor
            )
        }
        renderedLayer.image.draw(in: layerRect)
        context.restoreGState()
    }

    private static func makeDeviceLayer(
        _ request: CompositionRequest,
        maxSize: CGSize
    ) -> NSImage? {
        let usesProductBezel = request.deviceFrameStyle == .appleProductBezel
            || request.deviceFrameStyle == .importedProductBezel

        if usesProductBezel, let bezel = request.productBezel {
            guard bezel.size.width > 0, bezel.size.height > 0 else { return nil }
            let fitScale = min(maxSize.width / bezel.size.width, maxSize.height / bezel.size.height)
                * CGFloat(request.screenshotTransform.scale)
            let layerSize = CGSize(
                width: bezel.size.width * fitScale,
                height: bezel.size.height * fitScale
            )
            let layer = NSImage(size: layerSize)
            layer.lockFocus()
            if let layerContext = NSGraphicsContext.current?.cgContext {
                layerContext.translateBy(x: layerSize.width / 2, y: layerSize.height / 2)
                drawProductBezel(
                    bezel,
                    screenshot: request.screenshot,
                    aperture: request.productBezelAperture,
                    screenCornerRadiusRatio: CGFloat(request.productBezelScreenCornerRadiusRatio),
                    inset: CGFloat(request.importedBezelInset),
                    scale: 1,
                    maxSize: layerSize,
                    showShadow: false,
                    in: layerContext
                )
            }
            layer.unlockFocus()
            return layer
        }

        let screenshot = request.screenshot
        guard screenshot.size.width > 0, screenshot.size.height > 0 else { return nil }
        let fitScale = min(
            maxSize.width / screenshot.size.width,
            maxSize.height / screenshot.size.height
        ) * CGFloat(request.screenshotTransform.scale)
        let screenSize = CGSize(
            width: screenshot.size.width * fitScale,
            height: screenshot.size.height * fitScale
        )
        let frameWidth = request.deviceFrameStyle == .genericPhone
            ? max(8, min(screenSize.width, screenSize.height) * 0.018)
            : 0
        let layerSize = CGSize(
            width: screenSize.width + frameWidth * 2,
            height: screenSize.height + frameWidth * 2
        )
        let layer = NSImage(size: layerSize)
        layer.lockFocus()
        if let layerContext = NSGraphicsContext.current?.cgContext {
            layerContext.translateBy(x: layerSize.width / 2, y: layerSize.height / 2)
            drawFramedScreenshot(
                screenshot,
                frameStyle: request.deviceFrameStyle,
                scale: 1,
                maxSize: screenSize,
                deviceCornerRadius: CGFloat(request.deviceCornerRadius),
                showShadow: false,
                in: layerContext
            )
        }
        layer.unlockFocus()
        return layer
    }

    private static func perspectiveTransform(
        _ image: NSImage,
        using transform: CanvasElementTransform,
        depthRatio: Double
    ) -> (image: NSImage, depthOffset: CGPoint)? {
        let hasRotation = abs(transform.rotationDegrees) > 0.001
            || abs(transform.tiltXDegrees) > 0.001
            || abs(transform.tiltYDegrees) > 0.001
        guard hasRotation else { return (image, .zero) }

        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let halfWidth = width / 2
        let halfHeight = height / 2
        let tiltX = CGFloat(transform.tiltXDegrees * .pi / 180)
        let tiltY = CGFloat(transform.tiltYDegrees * .pi / 180)
        let rotationZ = CGFloat(-transform.rotationDegrees * .pi / 180)
        let perspectiveDistance = max(width, height) * 2.4

        func projectedPoint(x: CGFloat, y: CGFloat, z: CGFloat = 0) -> CGPoint {
            let rotatedY = y * cos(tiltX) - z * sin(tiltX)
            let depthAfterX = y * sin(tiltX) + z * cos(tiltX)
            let rotatedX = x * cos(tiltY) + depthAfterX * sin(tiltY)
            let depth = -x * sin(tiltY) + depthAfterX * cos(tiltY)
            let perspective = perspectiveDistance / max(1, perspectiveDistance - depth)
            let perspectiveX = rotatedX * perspective
            let perspectiveY = rotatedY * perspective
            return CGPoint(
                x: perspectiveX * cos(rotationZ) - perspectiveY * sin(rotationZ),
                y: perspectiveX * sin(rotationZ) + perspectiveY * cos(rotationZ)
            )
        }

        let topLeft = projectedPoint(x: -halfWidth, y: halfHeight)
        let topRight = projectedPoint(x: halfWidth, y: halfHeight)
        let bottomRight = projectedPoint(x: halfWidth, y: -halfHeight)
        let bottomLeft = projectedPoint(x: -halfWidth, y: -halfHeight)
        let minimumX = min(topLeft.x, topRight.x, bottomRight.x, bottomLeft.x)
        let minimumY = min(topLeft.y, topRight.y, bottomRight.y, bottomLeft.y)
        let translation = CGAffineTransform(translationX: -minimumX, y: -minimumY)

        guard let filter = CIFilter(name: "CIPerspectiveTransform") else { return nil }
        filter.setValue(CIImage(cgImage: cgImage), forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft.applying(translation)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight.applying(translation)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomRight.applying(translation)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: bottomLeft.applying(translation)), forKey: "inputBottomLeft")

        guard let output = filter.outputImage else { return nil }
        let outputExtent = output.extent.integral
        guard outputExtent.width > 0, outputExtent.height > 0,
              let outputCGImage = coreImageContext.createCGImage(output, from: outputExtent) else {
            return nil
        }
        let transformedImage = NSImage(
            cgImage: outputCGImage,
            size: CGSize(
                width: image.size.width * outputExtent.width / width,
                height: image.size.height * outputExtent.height / height
            )
        )
        let clampedDepthScale = min(max(transform.depthScale, 0), 3)
        let physicalDepth = min(width, height) * CGFloat(depthRatio * clampedDepthScale)
        let projectedBackCenter = projectedPoint(x: 0, y: 0, z: -physicalDepth)
        let pointsPerPixel = image.size.width / width
        let depthOffset = CGPoint(
            x: projectedBackCenter.x * pointsPerPixel,
            y: projectedBackCenter.y * pointsPerPixel
        )
        return (transformedImage, depthOffset)
    }

    private static func addDeviceDepth(
        to front: NSImage,
        offset: CGPoint,
        edgeTint: NSColor
    ) -> (image: NSImage, frontCenter: CGPoint) {
        let distance = hypot(offset.x, offset.y)
        guard distance >= 0.75 else {
            return (
                front,
                CGPoint(x: front.size.width / 2, y: front.size.height / 2)
            )
        }

        let minimumX = min(0, offset.x)
        let minimumY = min(0, offset.y)
        let maximumX = max(front.size.width, front.size.width + offset.x)
        let maximumY = max(front.size.height, front.size.height + offset.y)
        let combinedSize = CGSize(
            width: ceil(maximumX - minimumX),
            height: ceil(maximumY - minimumY)
        )
        let frontOrigin = CGPoint(x: -minimumX, y: -minimumY)
        let frontRect = CGRect(origin: frontOrigin, size: front.size)
        let baseTint = edgeTint.usingColorSpace(.deviceRGB) ?? edgeTint
        let darkTint = baseTint.blended(withFraction: 0.52, of: .black) ?? baseTint
        let highlightTint = baseTint.blended(withFraction: 0.38, of: .white) ?? baseTint
        let baseSilhouette = tintedSilhouette(of: front, color: baseTint)
        let darkSilhouette = tintedSilhouette(of: front, color: darkTint)
        let highlightSilhouette = tintedSilhouette(of: front, color: highlightTint)
        let stepCount = min(96, max(2, Int(ceil(distance))))

        let combined = NSImage(size: combinedSize)
        combined.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
        }
        for step in stride(from: stepCount, through: 1, by: -1) {
            let fraction = CGFloat(step) / CGFloat(stepCount)
            let silhouette: NSImage
            if fraction > 0.78 {
                silhouette = darkSilhouette
            } else if fraction < 0.12 {
                silhouette = highlightSilhouette
            } else {
                silhouette = baseSilhouette
            }
            silhouette.draw(in: frontRect.offsetBy(
                dx: offset.x * fraction,
                dy: offset.y * fraction
            ))
        }
        front.draw(in: frontRect)
        combined.unlockFocus()

        return (
            combined,
            CGPoint(x: frontRect.midX, y: frontRect.midY)
        )
    }

    private static func tintedSilhouette(of image: NSImage, color: NSColor) -> NSImage {
        let bounds = CGRect(origin: .zero, size: image.size)
        let silhouette = NSImage(size: image.size)
        silhouette.lockFocus()
        image.draw(in: bounds)
        if let context = NSGraphicsContext.current?.cgContext {
            context.setBlendMode(.sourceIn)
            context.setFillColor(color.cgColor)
            context.fill(bounds)
        }
        silhouette.unlockFocus()
        return silhouette
    }

    private static func drawFramedScreenshot(
        _ screenshot: NSImage,
        frameStyle: DeviceFrameStyle,
        scale: CGFloat,
        maxSize: CGSize,
        deviceCornerRadius: CGFloat,
        showShadow: Bool,
        in context: CGContext
    ) {
        guard screenshot.size.width > 0, screenshot.size.height > 0 else { return }
        let fitScale = min(
            maxSize.width / screenshot.size.width,
            maxSize.height / screenshot.size.height
        ) * scale
        let screenSize = CGSize(
            width: screenshot.size.width * fitScale,
            height: screenshot.size.height * fitScale
        )
        let screenRect = CGRect(
            x: -screenSize.width / 2,
            y: -screenSize.height / 2,
            width: screenSize.width,
            height: screenSize.height
        )
        let corner = max(0, deviceCornerRadius * fitScale)
        let frameWidth = frameStyle == .genericPhone
            ? max(8, min(screenRect.width, screenRect.height) * 0.018)
            : 0
        let outerRect = screenRect.insetBy(dx: -frameWidth, dy: -frameWidth)
        let outerCorner = corner + frameWidth
        let outerPath = CGPath(
            roundedRect: outerRect,
            cornerWidth: outerCorner,
            cornerHeight: outerCorner,
            transform: nil
        )

        if showShadow {
            drawShadow(for: outerPath, in: context)
        }

        if frameStyle == .genericPhone {
            context.saveGState()
            context.setFillColor(NSColor.black.cgColor)
            context.addPath(outerPath)
            context.fillPath()
            context.restoreGState()
        }

        let screenPath = CGPath(
            roundedRect: screenRect,
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )
        context.saveGState()
        context.addPath(screenPath)
        context.clip()
        screenshot.draw(in: screenRect)
        context.restoreGState()

        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        context.setLineWidth(max(1, fitScale))
        context.addPath(frameStyle == .genericPhone ? outerPath : screenPath)
        context.strokePath()
        context.restoreGState()
    }

    private static func drawProductBezel(
        _ bezel: NSImage,
        screenshot: NSImage,
        aperture: CGRect?,
        screenCornerRadiusRatio: CGFloat,
        inset: CGFloat,
        scale: CGFloat,
        maxSize: CGSize,
        showShadow: Bool,
        in context: CGContext
    ) {
        guard bezel.size.width > 0, bezel.size.height > 0 else { return }
        let fitScale = min(maxSize.width / bezel.size.width, maxSize.height / bezel.size.height) * scale
        let bezelSize = CGSize(width: bezel.size.width * fitScale, height: bezel.size.height * fitScale)
        let bezelRect = CGRect(
            x: -bezelSize.width / 2,
            y: -bezelSize.height / 2,
            width: bezelSize.width,
            height: bezelSize.height
        )

        let screenRect: CGRect
        if let aperture {
            screenRect = CGRect(
                x: bezelRect.minX + bezelRect.width * aperture.minX,
                y: bezelRect.minY + bezelRect.height * aperture.minY,
                width: bezelRect.width * aperture.width,
                height: bezelRect.height * aperture.height
            )
        } else {
            let clampedInset = min(max(inset, 0), 0.2)
            screenRect = bezelRect.insetBy(
                dx: bezelRect.width * clampedInset,
                dy: bezelRect.height * clampedInset
            )
        }
        let clampedCornerRadiusRatio = min(max(screenCornerRadiusRatio, 0), 0.25)
        let screenCornerRadius = min(screenRect.width, screenRect.height) * clampedCornerRadiusRatio
        let screenPath = CGPath(
            roundedRect: screenRect,
            cornerWidth: screenCornerRadius,
            cornerHeight: screenCornerRadius,
            transform: nil
        )
        context.saveGState()
        context.addPath(screenPath)
        context.clip()
        drawImageFitting(screenshot, in: screenRect, context: context)
        context.restoreGState()

        context.saveGState()
        if showShadow {
            context.setShadow(
                offset: CGSize(width: 0, height: -12),
                blur: 36,
                color: NSColor.black.withAlphaComponent(0.35).cgColor
            )
        }
        bezel.draw(in: bezelRect)
        context.restoreGState()
    }

    private static func drawShadow(for path: CGPath, in context: CGContext) {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -12),
            blur: 36,
            color: NSColor.black.withAlphaComponent(0.35).cgColor
        )
        context.addPath(path)
        context.setFillColor(NSColor.black.withAlphaComponent(0.01).cgColor)
        context.fillPath()
        context.restoreGState()
    }

    private static func drawTitle(
        _ request: CompositionRequest,
        in context: CGContext,
        canvas: CGSize
    ) {
        let transform = request.titleTransform
        let fontSize = CGFloat(request.titleFontSize * transform.scale)
        let font = NSFont(name: request.titleFontName, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
            .shadow: {
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
                shadow.shadowBlurRadius = max(2, fontSize * 0.08)
                shadow.shadowOffset = CGSize(width: 0, height: -2)
                return shadow
            }()
        ]
        let attributed = NSAttributedString(string: request.titleText, attributes: attributes)
        let measured = attributed.boundingRect(
            with: CGSize(width: canvas.width * 0.88, height: canvas.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).integral.size
        let center = CGPoint(
            x: canvas.width / 2 + canvas.width * CGFloat(transform.offsetX),
            y: canvas.height / 2 - canvas.height * CGFloat(transform.offsetY)
        )

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(-transform.rotationDegrees * .pi / 180))
        attributed.draw(in: CGRect(
            x: -measured.width / 2,
            y: -measured.height / 2,
            width: measured.width,
            height: measured.height
        ))
        context.restoreGState()
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

    /// Keeps every screenshot pixel visible when its aspect ratio differs from
    /// the selected product bezel's screen aperture.
    private static func drawImageFitting(_ image: NSImage, in rect: CGRect, context: CGContext) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        context.setFillColor(NSColor.black.cgColor)
        context.fill(rect)

        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
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
