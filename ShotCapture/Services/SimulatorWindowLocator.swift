//
//  SimulatorWindowLocator.swift
//  ShotCapture
//

import AppKit
import CoreGraphics
import Foundation

enum SimulatorWindowLocator {
    /// Returns the frame of the frontmost Simulator device window in AppKit coordinates
    /// (origin bottom-left), or nil if Simulator is not visible.
    static func frontSimulatorFrame() -> CGRect? {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let simulatorPIDs = NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == "com.apple.iphonesimulator" }
            .map(\.processIdentifier)

        guard !simulatorPIDs.isEmpty else { return nil }

        for info in infoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  simulatorPIDs.contains(ownerPID),
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  width > 200,
                  height > 200 else {
                continue
            }

            // CGWindow bounds use top-left origin; convert to AppKit bottom-left.
            let screenHeight = NSScreen.screens.map(\.frame.maxY).max() ?? 0
            let appKitY = screenHeight - y - height
            return CGRect(x: x, y: appKitY, width: width, height: height)
        }
        return nil
    }

    /// Places a companion window to the right of the Simulator when possible.
    static func companionWindowFrame(
        preferredSize: CGSize = CGSize(width: 420, height: 720)
    ) -> CGRect {
        let gap: CGFloat = 16

        if let sim = frontSimulatorFrame() {
            let proposed = CGRect(
                x: sim.maxX + gap,
                y: sim.midY - preferredSize.height / 2,
                width: preferredSize.width,
                height: preferredSize.height
            )
            if let screen = NSScreen.screens.first(where: { $0.frame.intersects(sim) }) ?? NSScreen.main {
                return proposed.clamped(to: screen.visibleFrame.insetBy(dx: 8, dy: 8))
            }
            return proposed
        }

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            return CGRect(
                x: frame.maxX - preferredSize.width - 24,
                y: frame.midY - preferredSize.height / 2,
                width: preferredSize.width,
                height: preferredSize.height
            )
        }

        return CGRect(x: 100, y: 100, width: preferredSize.width, height: preferredSize.height)
    }
}

private extension CGRect {
    func clamped(to bounds: CGRect) -> CGRect {
        var result = self
        if result.width > bounds.width { result.size.width = bounds.width }
        if result.height > bounds.height { result.size.height = bounds.height }
        if result.minX < bounds.minX { result.origin.x = bounds.minX }
        if result.maxX > bounds.maxX { result.origin.x = bounds.maxX - result.width }
        if result.minY < bounds.minY { result.origin.y = bounds.minY }
        if result.maxY > bounds.maxY { result.origin.y = bounds.maxY - result.height }
        return result
    }
}
