//
//  GradientEditorView.swift
//  ShotCapture
//

import AppKit
import SwiftUI

struct GradientEditorView: View {
    var onSave: (BackgroundStyle) -> Void
    var onCancel: () -> Void

    @State private var name = "My Gradient"
    @State private var angle: Double = 135
    @State private var isRadial = false
    @State private var startHex = "#0EA5E9"
    @State private var endHex = "#6366F1"
    @State private var midHex = "#8B5CF6"
    @State private var useMid = true

    var body: some View {
        VStack(spacing: 16) {
            Text("Custom Gradient")
                .font(.title2.weight(.semibold))

            BackgroundCanvas(style: previewStyle)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                }

            Form {
                TextField("Name", text: $name)
                Toggle("Three-color blend", isOn: $useMid)
                HStack {
                    Text("Start")
                    TextField("#RRGGBB", text: $startHex)
                        .textFieldStyle(.roundedBorder)
                    ColorPicker("", selection: binding(for: $startHex))
                        .labelsHidden()
                }
                if useMid {
                    HStack {
                        Text("Mid")
                        TextField("#RRGGBB", text: $midHex)
                            .textFieldStyle(.roundedBorder)
                        ColorPicker("", selection: binding(for: $midHex))
                            .labelsHidden()
                    }
                }
                HStack {
                    Text("End")
                    TextField("#RRGGBB", text: $endHex)
                        .textFieldStyle(.roundedBorder)
                    ColorPicker("", selection: binding(for: $endHex))
                        .labelsHidden()
                }
                Toggle("Radial", isOn: $isRadial)
                if !isRadial {
                    Slider(value: $angle, in: 0...360) {
                        Text("Angle \(Int(angle))°")
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Background") {
                    onSave(previewStyle)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private var previewStyle: BackgroundStyle {
        var stops = [
            GradientStop(location: 0, hex: normalized(startHex)),
            GradientStop(location: 1, hex: normalized(endHex))
        ]
        if useMid {
            stops.insert(GradientStop(location: 0.5, hex: normalized(midHex)), at: 1)
        }
        return BackgroundStyle(
            name: name.isEmpty ? "Custom Gradient" : name,
            kind: isRadial ? .radialGradient : .linearGradient,
            gradientStops: stops,
            gradientAngleDegrees: angle,
            isCustom: true
        )
    }

    private func normalized(_ hex: String) -> String {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.hasPrefix("#") { value = "#\(value)" }
        return value.uppercased()
    }

    private func binding(for hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: normalized(hex.wrappedValue)) },
            set: { newColor in
                hex.wrappedValue = NSColor(newColor).hexString
            }
        )
    }
}
