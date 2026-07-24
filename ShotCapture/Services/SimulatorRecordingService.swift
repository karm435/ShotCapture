//
//  SimulatorRecordingService.swift
//  ShotCapture
//

import Foundation

actor SimulatorRecordingService {
    private final class Session: @unchecked Sendable {
        let id = UUID()
        let process = Process()
        let errorPipe = Pipe()
        let outputURL: URL
        var errorData = Data()
        var isCancelled = false

        init(outputURL: URL) {
            self.outputURL = outputURL
        }
    }

    private var activeSession: Session?
    private var stopContinuation: CheckedContinuation<URL, Error>?
    private var completedResult: Result<URL, Error>?

    func startRecording(
        udid: String,
        developerDirectory: URL
    ) async throws -> URL {
        guard activeSession == nil else {
            throw SimulatorRecordingError.alreadyRecording
        }

        let outputURL = URL.temporaryDirectory
            .appending(path: "ShotCapture-\(UUID().uuidString).mov")
        let session = Session(outputURL: outputURL)
        activeSession = session
        completedResult = nil

        session.process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        session.process.arguments = [
            "simctl",
            "io",
            udid,
            "recordVideo",
            "--codec=h264",
            "--force",
            outputURL.path(),
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["DEVELOPER_DIR"] = developerDirectory.path(percentEncoded: false)
        session.process.environment = environment
        session.process.standardError = session.errorPipe

        session.errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task {
                await self?.receivedStandardError(data, sessionID: session.id)
            }
        }
        session.process.terminationHandler = { [weak self] process in
            Task {
                await self?.processTerminated(
                    sessionID: session.id,
                    status: process.terminationStatus
                )
            }
        }

        do {
            try session.process.run()
        } catch {
            activeSession = nil
            throw SimulatorRecordingError.processFailed(error.localizedDescription)
        }

        do {
            // simctl has no structured "started" signal. Remaining alive after
            // launch is the reliable indicator and avoids parsing localized text.
            try await Task<Never, Never>.sleep(nanoseconds: 250_000_000)
        } catch {
            cancelRecording()
            throw error
        }

        guard activeSession?.id == session.id, session.process.isRunning else {
            if let completedResult {
                self.completedResult = nil
                return try completedResult.get()
            }
            throw SimulatorRecordingError.processFailed(
                "simctl stopped before recording could begin."
            )
        }
        return session.outputURL
    }

    func stopRecording() async throws -> URL {
        if activeSession == nil, let completedResult {
            self.completedResult = nil
            return try completedResult.get()
        }
        guard let session = activeSession else {
            throw SimulatorRecordingError.notRecording
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                stopContinuation = continuation
                session.process.interrupt()
            }
        } onCancel: {
            Task { await self.cancelRecording() }
        }
    }

    func cancelRecording() {
        guard let session = activeSession else { return }
        session.isCancelled = true
        if session.process.isRunning {
            session.process.interrupt()
        }
    }

    private func receivedStandardError(_ data: Data, sessionID: UUID) {
        guard let session = activeSession, session.id == sessionID else { return }
        session.errorData.append(data)
    }

    private func processTerminated(sessionID: UUID, status: Int32) {
        guard let session = activeSession, session.id == sessionID else { return }
        session.errorPipe.fileHandleForReading.readabilityHandler = nil
        session.process.terminationHandler = nil
        activeSession = nil

        let result: Result<URL, Error>
        if session.isCancelled {
            try? FileManager.default.removeItem(at: session.outputURL)
            result = .failure(CancellationError())
        } else if isReadableMovie(at: session.outputURL) {
            result = .success(session.outputURL)
        } else {
            let detail = String(decoding: session.errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if status == 0, detail.isEmpty {
                result = .failure(SimulatorRecordingError.emptyRecording)
            } else {
                result = .failure(SimulatorRecordingError.processFailed(
                    detail.isEmpty ? "simctl exited with status \(status)." : detail
                ))
            }
        }
        completedResult = result

        if let continuation = stopContinuation {
            stopContinuation = nil
            completedResult = nil
            continuation.resume(with: result)
        }
    }

    private func isReadableMovie(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return false }
        return size > 0
    }
}
