//
//  VideoPlayerCanvas.swift
//  ShotCapture
//

import AVFoundation
import SwiftUI

struct VideoPlayerCanvas: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerView, context: Context) {
        nsView.playerLayer.player = player
    }

    final class PlayerView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            playerLayer.videoGravity = .resizeAspect
            layer = playerLayer
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
        }
    }
}
