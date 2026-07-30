//
//  AppStoreCampaignStore.swift
//  ShotCapture
//

import Foundation

nonisolated enum AppStoreCampaignStoreError: LocalizedError {
    case invalidPackage
    case unsupportedSchema(Int)
    case missingAsset(String)

    var errorDescription: String? {
        switch self {
        case .invalidPackage:
            "The selected ShotCapture campaign is incomplete or unreadable."
        case .unsupportedSchema(let version):
            "This campaign uses unsupported schema version \(version)."
        case .missingAsset(let name):
            "The campaign asset “\(name)” could not be found."
        }
    }
}

actor AppStoreCampaignStore {
    static let packageExtension = "shotcapturecampaign"

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let baseDirectoryOverride: URL?

    init(baseDirectory: URL? = nil) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        self.baseDirectoryOverride = baseDirectory
    }

    func makeWorkspace(for campaign: AppStoreCampaign) throws -> URL {
        let workspace = try workspaceURL(for: campaign.id)
        try ensurePackageDirectories(at: workspace)
        try write(campaign, to: workspace)
        return workspace
    }

    func loadPackage(at packageURL: URL) throws -> AppStoreCampaign {
        let manifestURL = packageURL.appending(path: "campaign.json")
        guard fileManager.fileExists(atPath: manifestURL.path()) else {
            throw AppStoreCampaignStoreError.invalidPackage
        }
        let data = try Data(contentsOf: manifestURL)
        let campaign = try decoder.decode(AppStoreCampaign.self, from: data)
        guard campaign.schemaVersion <= AppStoreCampaign.schemaVersion else {
            throw AppStoreCampaignStoreError.unsupportedSchema(campaign.schemaVersion)
        }
        return campaign
    }

    func write(_ campaign: AppStoreCampaign, to packageURL: URL) throws {
        try ensurePackageDirectories(at: packageURL)
        let data = try encoder.encode(campaign)
        try data.write(
            to: packageURL.appending(path: "campaign.json"),
            options: .atomic
        )
    }

    func copyAsset(
        from sourceURL: URL,
        preferredStem: String,
        into packageURL: URL
    ) throws -> String {
        try ensurePackageDirectories(at: packageURL)
        let assetsURL = packageURL.appending(path: "Assets", directoryHint: .isDirectory)
        let fileExtension = sourceURL.pathExtension.lowercased()
        let stem = sanitizedFileName(preferredStem)
        var candidate = "\(stem)-\(UUID().uuidString.lowercased())"
        if !fileExtension.isEmpty {
            candidate += ".\(fileExtension)"
        }
        let destination = assetsURL.appending(path: candidate)
        try fileManager.copyItem(at: sourceURL, to: destination)
        return candidate
    }

    func writeAsset(
        _ data: Data,
        preferredStem: String,
        fileExtension: String,
        into packageURL: URL
    ) throws -> String {
        try ensurePackageDirectories(at: packageURL)
        let fileName = "\(sanitizedFileName(preferredStem))-\(UUID().uuidString.lowercased()).\(fileExtension)"
        let destination = packageURL
            .appending(path: "Assets", directoryHint: .isDirectory)
            .appending(path: fileName)
        try data.write(to: destination, options: .atomic)
        return fileName
    }

    func assetURL(named fileName: String, in packageURL: URL) throws -> URL {
        let url = packageURL
            .appending(path: "Assets", directoryHint: .isDirectory)
            .appending(path: fileName)
        guard fileManager.fileExists(atPath: url.path()) else {
            throw AppStoreCampaignStoreError.missingAsset(fileName)
        }
        return url
    }

    func saveCopy(from workspaceURL: URL, to destinationURL: URL) throws {
        let stagedURL = destinationURL
            .deletingLastPathComponent()
            .appending(
                path: ".\(destinationURL.lastPathComponent)-\(UUID().uuidString).staged",
                directoryHint: .isDirectory
            )
        defer { try? fileManager.removeItem(at: stagedURL) }

        try fileManager.copyItem(at: workspaceURL, to: stagedURL)
        if fileManager.fileExists(atPath: destinationURL.path()) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: stagedURL, to: destinationURL)
    }

    func prepareImportedPackage(at sourceURL: URL) throws -> URL {
        let campaign = try loadPackage(at: sourceURL)
        let workspace = try workspaceURL(for: campaign.id)
        if sourceURL.standardizedFileURL == workspace.standardizedFileURL {
            return workspace
        }
        if fileManager.fileExists(atPath: workspace.path()) {
            try fileManager.removeItem(at: workspace)
        }
        try fileManager.createDirectory(
            at: workspace.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: sourceURL, to: workspace)
        return workspace
    }

    private func ensurePackageDirectories(at packageURL: URL) throws {
        try fileManager.createDirectory(
            at: packageURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: packageURL.appending(path: "Assets", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    private func applicationSupportDirectory() throws -> URL {
        if let baseDirectoryOverride {
            return baseDirectoryOverride
        }
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root.appending(path: "ShotCapture", directoryHint: .isDirectory)
    }

    private func workspaceURL(for campaignID: UUID) throws -> URL {
        try applicationSupportDirectory()
            .appending(path: "Campaigns", directoryHint: .isDirectory)
            .appending(
                path: "\(campaignID.uuidString).\(Self.packageExtension)",
                directoryHint: .isDirectory
            )
    }

    private func sanitizedFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "asset" : collapsed
    }
}
