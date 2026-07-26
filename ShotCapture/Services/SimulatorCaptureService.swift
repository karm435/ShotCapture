//
//  SimulatorCaptureService.swift
//  ShotCapture
//

import AppKit
import Foundation

struct SimulatorDevice: Identifiable, Hashable {
    var id: String { udid }
    let udid: String
    let name: String
    let runtime: String
    let state: String

    var isBooted: Bool { state == "Booted" }
}

enum SimulatorCaptureError: LocalizedError {
    case noBootedSimulator
    case simctlFailed(String)
    case captureFailed(String)
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .noBootedSimulator:
            return "No booted iOS Simulator found. Boot a device, then try again."
        case .simctlFailed(let detail):
            return "Could not communicate with Simulator: \(detail)"
        case .captureFailed(let detail):
            return "Screenshot failed: \(detail)"
        case .invalidImageData:
            return "Could not read the captured simulator image."
        }
    }
}

actor SimulatorCaptureService {
    func listBootedDevices() async throws -> [SimulatorDevice] {
        let result: CommandResult
        do {
            result = try Self.runSimctl(["list", "devices", "booted", "--json"])
        } catch {
            throw SimulatorCaptureError.simctlFailed(error.localizedDescription)
        }

        do {
            guard result.terminationStatus == 0 else {
                throw SimulatorCaptureError.simctlFailed(result.errorMessage)
            }

            let list = try JSONDecoder().decode(SimctlDeviceList.self, from: result.standardOutput)
            return list.devices.flatMap { runtimeIdentifier, devices in
                devices.compactMap { device in
                    guard device.state == "Booted", device.isAvailable != false else { return nil }
                    return SimulatorDevice(
                        udid: device.udid,
                        name: device.name,
                        runtime: Self.runtimeName(from: runtimeIdentifier),
                        state: device.state
                    )
                }
            }
            .sorted {
                if $0.name == $1.name { return $0.runtime < $1.runtime }
                return $0.name < $1.name
            }
        } catch let error as SimulatorCaptureError {
            throw error
        } catch {
            throw SimulatorCaptureError.simctlFailed("Invalid device list: \(error.localizedDescription)")
        }
    }

    func captureScreenshot(udid: String?) async throws -> NSImage {
        let devices = try await listBootedDevices()
        guard !devices.isEmpty else { throw SimulatorCaptureError.noBootedSimulator }

        let targetUDID: String
        if let udid, let match = devices.first(where: { $0.udid == udid }) {
            targetUDID = match.udid
        } else {
            targetUDID = devices[0].udid
        }

        let destination = URL.temporaryDirectory
            .appending(path: "ShotCapture-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: destination) }

        let result: CommandResult
        do {
            result = try Self.runSimctl([
                "io",
                targetUDID,
                "screenshot",
                "--type=png",
                destination.path(),
            ])
        } catch {
            throw SimulatorCaptureError.captureFailed(error.localizedDescription)
        }

        guard result.terminationStatus == 0 else {
            throw SimulatorCaptureError.captureFailed(result.errorMessage)
        }

        guard let image = NSImage(contentsOf: destination) else {
            throw SimulatorCaptureError.invalidImageData
        }
        return image
    }

    private static func runtimeName(from identifier: String) -> String {
        guard let component = identifier.split(separator: ".").last else {
            return identifier
        }
        let parts = component.split(separator: "-")
        guard let platform = parts.first, parts.count > 1 else {
            return String(component)
        }
        return "\(platform) \(parts.dropFirst().joined(separator: "."))"
    }

    private static func runSimctl(_ arguments: [String]) throws -> CommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        return CommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            standardError: standardError.fileHandleForReading.readDataToEndOfFile()
        )
    }
}

private struct SimctlDeviceList: Decodable {
    let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool?
}

private struct CommandResult {
    let terminationStatus: Int32
    let standardOutput: Data
    let standardError: Data

    var errorMessage: String {
        let message = String(decoding: standardError, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "simctl exited with status \(terminationStatus)." : message
    }
}
