//
//  ShotCaptureTests.swift
//  ShotCaptureTests
//

import Testing
import AppKit
@testable import ShotCapture

struct ShotCaptureTests {
    @Test func socialPlatformCanvasSizesAreValid() {
        for platform in SocialPlatform.allCases {
            #expect(platform.canvasSize.width > 0)
            #expect(platform.canvasSize.height > 0)
        }
    }

    @Test func compositionProducesPNG() {
        let shot = NSImage(size: NSSize(width: 390, height: 844))
        shot.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: shot.size).fill()
        shot.unlockFocus()

        let composed = CompositionService.compose(
            CompositionRequest(
                screenshot: shot,
                platform: .instagramPortrait,
                background: BackgroundStyle.presets[0],
                paddingPercent: 0.1,
                deviceCornerRadius: 40,
                showDeviceShadow: true,
                watermarkEnabled: true,
                watermarkText: "ShotCapture"
            )
        )

        #expect(composed.size.width == 1080)
        #expect(composed.size.height == 1350)
        #expect(CompositionService.pngData(from: composed) != nil)
    }

    @Test func presetBackgroundCount() {
        let images = BackgroundStyle.presets.filter { $0.kind == .presetImage }
        #expect(images.count >= 20)
    }

    @Test func listBootedSimulators() async throws {
        let service = SimulatorCaptureService()
        // May be empty when no Simulator is booted.
        let devices = try await service.listBootedDevices()
        _ = devices
    }

    @Test func captureBootedSimulatorScreenshot() async throws {
        let service = SimulatorCaptureService()
        let devices = try await service.listBootedDevices()
        guard !devices.isEmpty else {
            // Skip when Simulator isn't available in this environment.
            return
        }

        let image = try await service.captureScreenshot(udid: nil)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }
}
