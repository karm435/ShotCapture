//
//  CampaignPlacementControlsView.swift
//  ShotCapture
//

import SwiftUI

struct CampaignPlacementControlsView: View {
    let transform: CanvasElementTransform
    let onPreview: (CanvasElementTransform) -> Void
    let onCommit: (CanvasElementTransform) -> Void

    @State private var draftTransform: CanvasElementTransform
    @State private var isInteracting = false
    @State private var commitTask: Task<Void, Never>?

    init(
        transform: CanvasElementTransform,
        onPreview: @escaping (CanvasElementTransform) -> Void,
        onCommit: @escaping (CanvasElementTransform) -> Void
    ) {
        self.transform = transform
        self.onPreview = onPreview
        self.onCommit = onCommit
        _draftTransform = State(initialValue: transform)
    }

    var body: some View {
        GroupBox("Placement") {
            VStack(spacing: 12) {
                CampaignPlacementSliderView(
                    title: "Scale",
                    value: $draftTransform.scale,
                    range: 0.25...1.6,
                    onEditingChanged: editingChanged
                )
                CampaignPlacementSliderView(
                    title: "Horizontal",
                    value: $draftTransform.offsetX,
                    range: -0.6...0.6,
                    onEditingChanged: editingChanged
                )
                CampaignPlacementSliderView(
                    title: "Vertical",
                    value: $draftTransform.offsetY,
                    range: -0.6...0.6,
                    onEditingChanged: editingChanged
                )
                CampaignPlacementSliderView(
                    title: "Rotation",
                    value: $draftTransform.rotationDegrees,
                    range: -30...30,
                    onEditingChanged: editingChanged
                )
                CampaignPlacementSliderView(
                    title: "Tilt X",
                    value: $draftTransform.tiltXDegrees,
                    range: -25...25,
                    onEditingChanged: editingChanged
                )
                CampaignPlacementSliderView(
                    title: "Tilt Y",
                    value: $draftTransform.tiltYDegrees,
                    range: -25...25,
                    onEditingChanged: editingChanged
                )
            }
            .padding(.top, 4)
        }
        .onChange(of: draftTransform) { _, newValue in
            guard isInteracting || newValue != transform else { return }
            onPreview(newValue)
            scheduleKeyboardCommit(newValue)
        }
        .onChange(of: transform) { _, newValue in
            guard !isInteracting, newValue != draftTransform else { return }
            draftTransform = newValue
        }
        .onDisappear {
            commitTask?.cancel()
            guard draftTransform != transform else { return }
            onCommit(draftTransform)
        }
    }

    private func editingChanged(_ editing: Bool) {
        isInteracting = editing
        guard !editing else { return }
        commitTask?.cancel()
        onCommit(draftTransform)
    }

    private func scheduleKeyboardCommit(_ value: CanvasElementTransform) {
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, !isInteracting else { return }
            onCommit(value)
        }
    }
}
