//
//  CampaignPlacementSliderView.swift
//  ShotCapture
//

import SwiftUI

struct CampaignPlacementSliderView: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $value,
                in: range,
                onEditingChanged: onEditingChanged
            )
            .controlSize(.regular)
            .accessibilityLabel(title)
            .accessibilityValue(
                value.formatted(.number.precision(.fractionLength(2)))
            )
        }
    }
}
