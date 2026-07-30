//
//  CampaignInteractiveScreenshotPreviewView.swift
//  ShotCapture
//

import SwiftUI

struct CampaignInteractiveScreenshotPreviewView: View {
    let layers: AppStoreScreenshotPreviewLayers
    let transform: CanvasElementTransform

    var body: some View {
        GeometryReader { geometry in
            let canvasScale = min(
                geometry.size.width / layers.canvasSize.width,
                geometry.size.height / layers.canvasSize.height
            )
            let deviceSize = CGSize(
                width: layers.device.size.width * canvasScale * transform.scale,
                height: layers.device.size.height * canvasScale * transform.scale
            )

            ZStack {
                Image(nsImage: layers.backdrop)
                    .resizable()
                    .interpolation(.high)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )

                Image(nsImage: layers.device)
                    .resizable()
                    .interpolation(.high)
                    .frame(
                        width: deviceSize.width,
                        height: deviceSize.height
                    )
                    .compositingGroup()
                    .rotation3DEffect(
                        .degrees(transform.tiltXDegrees),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 1 / 2.4
                    )
                    .rotation3DEffect(
                        .degrees(-transform.tiltYDegrees),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 1 / 2.4
                    )
                    .rotationEffect(.degrees(transform.rotationDegrees))
                    .shadow(
                        color: layers.showsDeviceShadow
                            ? .black.opacity(0.35)
                            : .clear,
                        radius: layers.showsDeviceShadow ? 18 : 0,
                        y: layers.showsDeviceShadow ? 8 : 0
                    )
                    .offset(
                        x: geometry.size.width * transform.offsetX,
                        y: geometry.size.height * transform.offsetY
                    )
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .clipped()
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live App Store screenshot placement preview")
    }
}
