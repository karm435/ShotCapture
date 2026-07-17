//
//  TwoFingerTiltGesture.swift
//  ShotCapture
//

import SwiftUI

#if os(macOS)
import AppKit

extension View {
    func twoFingerTiltGesture(
        isEnabled: Bool,
        onDelta: @escaping (CGSize) -> Void
    ) -> some View {
        background {
            TrackpadTiltMonitor(isEnabled: isEnabled, onDelta: onDelta)
                .allowsHitTesting(false)
        }
    }
}

private struct TrackpadTiltMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let onDelta: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onDelta: onDelta)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onDelta = onDelta
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator {
        var isEnabled: Bool
        var onDelta: (CGSize) -> Void
        private weak var view: NSView?
        private var eventMonitor: Any?

        init(isEnabled: Bool, onDelta: @escaping (CGSize) -> Void) {
            self.isEnabled = isEnabled
            self.onDelta = onDelta
        }

        func attach(to view: NSView) {
            self.view = view
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func stopMonitoring() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard isEnabled,
                  event.hasPreciseScrollingDeltas,
                  event.momentumPhase.isEmpty,
                  let view,
                  let window = view.window,
                  event.window === window else {
                return event
            }

            let location = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(location) else { return event }

            let delta = CGSize(
                width: event.scrollingDeltaX,
                height: event.scrollingDeltaY
            )
            guard abs(delta.width) + abs(delta.height) > 0 else { return event }
            onDelta(delta)
            return nil
        }
    }
}

#elseif os(iOS)
import UIKit

extension View {
    func twoFingerTiltGesture(
        isEnabled: Bool,
        onDelta: @escaping (CGSize) -> Void
    ) -> some View {
        gesture(TwoFingerPanGesture(onDelta: onDelta), isEnabled: isEnabled)
    }
}

private struct TwoFingerPanGesture: UIGestureRecognizerRepresentable {
    let onDelta: (CGSize) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.minimumNumberOfTouches = 2
        recognizer.maximumNumberOfTouches = 2
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIPanGestureRecognizer,
        context: Context
    ) {
        guard recognizer.state == .changed else { return }
        let translation = recognizer.translation(in: recognizer.view)
        onDelta(CGSize(width: translation.x, height: translation.y))
        recognizer.setTranslation(.zero, in: recognizer.view)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif
