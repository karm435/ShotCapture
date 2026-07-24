//
//  ShotVideoCompositor.swift
//  ShotCapture
//

import AppKit
import AVFoundation
import CoreImage
import CoreVideo
import Foundation

/// AVFoundation creates this type itself. All mutable state is serialized on
/// `renderQueue`, which is the safety invariant for unchecked sendability.
nonisolated final class ShotVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let renderQueue = DispatchQueue(
        label: "com.karmaacademy.ShotCapture.video-compositor",
        qos: .userInitiated
    )
    private let ciContext = CIContext(options: [.cacheIntermediates: true])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var cancellationGeneration = 0

    var sourcePixelBufferAttributes: [String: Any]? {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Each request supplies its current render context.
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        let generation = renderQueue.sync { cancellationGeneration }
        renderQueue.async { [self] in
            guard generation == cancellationGeneration else {
                request.finishCancelledRequest()
                return
            }
            autoreleasepool {
                render(request)
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        renderQueue.sync {
            cancellationGeneration += 1
        }
    }

    private func render(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction
            as? ShotVideoCompositionInstruction else {
            request.finish(with: VideoCompositionError.invalidInstruction)
            return
        }
        guard let sourceBuffer = request.sourceFrame(byTrackID: instruction.sourceTrackID) else {
            request.finish(with: VideoCompositionError.missingSourceFrame)
            return
        }
        guard let outputBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: VideoCompositionError.cannotCreateFrame)
            return
        }

        let sourceImage = normalizedSourceImage(
            from: sourceBuffer,
            transform: instruction.sourceTransform
        )
        guard let sourceImage else {
            request.finish(with: VideoCompositionError.cannotCreateFrame)
            return
        }

        let frameRequest = instruction.compositionRequest.replacingScreenshot(sourceImage)
        let composed = CompositionService.compose(frameRequest)
        var proposedRect = CGRect(origin: .zero, size: composed.size)
        guard let composedCGImage = composed.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else {
            request.finish(with: VideoCompositionError.cannotCreateFrame)
            return
        }

        let outputImage = CIImage(cgImage: composedCGImage)
        ciContext.render(
            outputImage,
            to: outputBuffer,
            bounds: CGRect(origin: .zero, size: request.renderContext.size),
            colorSpace: colorSpace
        )
        request.finish(withComposedVideoFrame: outputBuffer)
    }

    private func normalizedSourceImage(
        from pixelBuffer: CVPixelBuffer,
        transform: CGAffineTransform
    ) -> NSImage? {
        let transformed = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: transform)
        let extent = transformed.extent.integral
        guard !extent.isEmpty, !extent.isInfinite else { return nil }

        let normalized = transformed.transformed(by: CGAffineTransform(
            translationX: -extent.minX,
            y: -extent.minY
        ))
        guard let cgImage = ciContext.createCGImage(normalized, from: normalized.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: normalized.extent.size)
    }
}
