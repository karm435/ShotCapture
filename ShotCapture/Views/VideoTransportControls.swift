//
//  VideoTransportControls.swift
//  ShotCapture
//

import Foundation
import SwiftUI

struct VideoTransportControls: View {
    @Environment(AppController.self) private var app

    var body: some View {
        @Bindable var app = app

        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(
                    app.isVideoPlaying ? "Pause" : "Play",
                    systemImage: app.isVideoPlaying ? "pause.fill" : "play.fill",
                    action: app.toggleVideoPlayback
                )

                Slider(
                    value: $app.videoCurrentTime,
                    in: playbackRange,
                    onEditingChanged: scrubberEditingChanged
                )

                Text("\(formatted(app.videoCurrentTime)) / \(formatted(app.videoDuration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 92, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Text("Trim")
                    .font(.caption.weight(.medium))

                Text("Start \(formatted(app.videoTrimStart))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Slider(value: $app.videoTrimStart, in: trimStartRange)

                Text("End \(formatted(app.videoTrimEnd))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Slider(value: $app.videoTrimEnd, in: trimEndRange)

                if app.videoHasAudio {
                    Label("Audio", systemImage: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Silent", systemImage: "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: app.videoTrimStart) { _, _ in app.normalizeVideoTrim() }
        .onChange(of: app.videoTrimEnd) { _, _ in app.normalizeVideoTrim() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Video playback and trim controls")
    }

    private var playbackRange: ClosedRange<Double> {
        let end = max(app.videoTrimEnd, app.videoTrimStart + 0.01)
        return app.videoTrimStart...end
    }

    private var trimStartRange: ClosedRange<Double> {
        0...max(0.01, app.videoTrimEnd - 0.05)
    }

    private var trimEndRange: ClosedRange<Double> {
        min(app.videoTrimStart + 0.05, app.videoDuration)...max(app.videoDuration, 0.05)
    }

    private func scrubberEditingChanged(_ isEditing: Bool) {
        if isEditing {
            app.pauseVideo()
        } else {
            app.seekVideo(to: app.videoCurrentTime)
        }
    }

    private func formatted(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
