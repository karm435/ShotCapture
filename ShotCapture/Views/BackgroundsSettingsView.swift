//
//  BackgroundsSettingsView.swift
//  ShotCapture
//

import SwiftUI

struct BackgroundsSettingsView: View {
    @Environment(AppController.self) private var app
    @Binding var showGradientEditor: Bool

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        @Bindable var settings = app.settings

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Presets")
                        .font(.headline)
                    Spacer()
                    Button("New Gradient…") {
                        showGradientEditor = true
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(BackgroundStyle.presets) { style in
                        backgroundCell(style, selected: settings.selectedBackgroundID == style.id) {
                            settings.selectedBackgroundID = style.id
                            app.recompose()
                        }
                    }
                }

                if !settings.customBackgrounds.isEmpty {
                    Text("Custom")
                        .font(.headline)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(settings.customBackgrounds) { style in
                            ZStack(alignment: .topTrailing) {
                                backgroundCell(style, selected: settings.selectedBackgroundID == style.id) {
                                    settings.selectedBackgroundID = style.id
                                    app.recompose()
                                }

                                Button {
                                    settings.removeCustomBackground(style.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.55))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func backgroundCell(
        _ style: BackgroundStyle,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                BackgroundCanvas(style: style)
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1)
                    }

                Text(style.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
