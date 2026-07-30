//
//  CampaignScreenshotCanvasView.swift
//  ShotCapture
//

import AppKit
import SwiftUI

struct CampaignScreenshotCanvasView: View {
    @Environment(AppStoreCampaignController.self) private var controller

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(
                    controller.selectedTarget.displayName,
                    systemImage: controller.selectedTarget.isIPad ? "ipad" : "iphone"
                )
                .font(.subheadline.weight(.semibold))

                Spacer()

                Button(action: controller.importScreenshot) {
                    Label("Import", systemImage: "photo.badge.plus")
                }
                Button(action: controller.captureScreenshot) {
                    Label("Capture Simulator", systemImage: "camera")
                }
                .disabled(controller.isWorking)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            GeometryReader { geometry in
                ZStack {
                    Color(nsColor: .underPageBackgroundColor)

                    if controller.isAdjustingScreenshotPlacement,
                       let layers = controller.screenshotPreviewLayers,
                       let transform = controller.interactiveScreenshotTransform {
                        let size = fittedSize(
                            content: layers.canvasSize,
                            available: CGSize(
                                width: max(0, geometry.size.width - 64),
                                height: max(0, geometry.size.height - 64)
                            )
                        )
                        CampaignInteractiveScreenshotPreviewView(
                            layers: layers,
                            transform: transform
                        )
                        .frame(width: size.width, height: size.height)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
                    } else if let image = controller.renderedScreenshot {
                        let size = fittedSize(
                            content: image.size,
                            available: CGSize(
                                width: max(0, geometry.size.width - 64),
                                height: max(0, geometry.size.height - 64)
                            )
                        )
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: size.width, height: size.height)
                            .clipShape(.rect(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
                            .accessibilityLabel("Rendered App Store screenshot")
                    } else {
                        ContentUnavailableView {
                            Label("Add a Simulator Screenshot", systemImage: "iphone.gen3")
                        } description: {
                            Text("Import an image or capture a booted Simulator for this target.")
                        } actions: {
                            HStack {
                                Button("Import…", action: controller.importScreenshot)
                                Button("Capture Simulator", action: controller.captureScreenshot)
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private func fittedSize(content: CGSize, available: CGSize) -> CGSize {
        guard content.width > 0, content.height > 0 else { return .zero }
        let scale = min(
            available.width / content.width,
            available.height / content.height
        )
        return CGSize(
            width: content.width * scale,
            height: content.height * scale
        )
    }
}
