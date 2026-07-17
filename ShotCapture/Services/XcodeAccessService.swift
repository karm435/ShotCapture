//
//  XcodeAccessService.swift
//  ShotCapture
//

import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class XcodeAccessService {
    private enum Keys {
        static let bookmark = "selectedXcodeSecurityScopedBookmark"
    }

    private(set) var selectedXcodeURL: URL?
    private(set) var lastError: String?

    var developerDirectoryURL: URL? {
        selectedXcodeURL?.appending(path: "Contents/Developer", directoryHint: .isDirectory)
    }

    var displayPath: String {
        selectedXcodeURL?.path(percentEncoded: false) ?? "Not selected"
    }

    var hasAccess: Bool {
        developerDirectoryURL.map(Self.isValidDeveloperDirectory) ?? false
    }

    init() {
        restoreBookmark()
    }

    @discardableResult
    func chooseXcode() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Choose Xcode"
        panel.message = "ShotCapture needs access to Xcode to run simctl inside the App Sandbox."
        panel.prompt = "Choose Xcode"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return storeAccess(to: url)
    }

    private func storeAccess(to url: URL) -> Bool {
        let developerDirectory = url.appending(path: "Contents/Developer", directoryHint: .isDirectory)
        guard Self.isValidDeveloperDirectory(developerDirectory) else {
            lastError = "Choose a complete Xcode application that contains simctl."
            return false
        }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            guard url.startAccessingSecurityScopedResource() else {
                lastError = "macOS did not grant access to the selected Xcode application."
                return false
            }

            selectedXcodeURL?.stopAccessingSecurityScopedResource()
            selectedXcodeURL = url
            UserDefaults.standard.set(bookmark, forKey: Keys.bookmark)
            lastError = nil
            return true
        } catch {
            lastError = "Could not save Xcode access: \(error.localizedDescription)"
            return false
        }
    }

    private func restoreBookmark() {
        guard let bookmark = UserDefaults.standard.data(forKey: Keys.bookmark) else { return }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard url.startAccessingSecurityScopedResource() else {
                UserDefaults.standard.removeObject(forKey: Keys.bookmark)
                return
            }

            let developerDirectory = url.appending(path: "Contents/Developer", directoryHint: .isDirectory)
            guard Self.isValidDeveloperDirectory(developerDirectory) else {
                url.stopAccessingSecurityScopedResource()
                UserDefaults.standard.removeObject(forKey: Keys.bookmark)
                return
            }

            selectedXcodeURL = url
            if isStale {
                let refreshedBookmark = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(refreshedBookmark, forKey: Keys.bookmark)
            }
        } catch {
            UserDefaults.standard.removeObject(forKey: Keys.bookmark)
            lastError = "Xcode access expired. Choose Xcode again."
        }
    }

    private static func isValidDeveloperDirectory(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(
            atPath: url.appending(path: "usr/bin/simctl").path(percentEncoded: false)
        )
    }
}
