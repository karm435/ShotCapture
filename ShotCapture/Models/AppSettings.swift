//
//  AppSettings.swift
//  ShotCapture
//

import AppKit
import Foundation
import SwiftUI

@Observable
final class AppSettings {
    private enum Keys {
        static let platform = "selectedPlatform"
        static let backgroundID = "selectedBackgroundID"
        static let customBackgrounds = "customBackgrounds"
        static let watermarkEnabled = "watermarkEnabled"
        static let watermarkText = "watermarkText"
        static let paddingPercent = "paddingPercent"
        static let cornerRadius = "deviceCornerRadius"
        static let showDeviceShadow = "showDeviceShadow"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let preferredSimulatorUDID = "preferredSimulatorUDID"
        static let screenshotTransform = "screenshotTransform"
        static let titleTransform = "titleTransform"
        static let deviceFrameStyle = "deviceFrameStyle"
        static let productBezelDevice = "productBezelDevice"
        static let productBezelFinish = "productBezelFinish"
        static let importedBezelInset = "importedBezelInset"
        static let titleEnabled = "titleEnabled"
        static let titleText = "titleText"
        static let titleFontName = "titleFontName"
        static let titleFontSize = "titleFontSize"
    }

    var selectedPlatform: SocialPlatform {
        didSet { UserDefaults.standard.set(selectedPlatform.rawValue, forKey: Keys.platform) }
    }

    var selectedBackgroundID: UUID {
        didSet { UserDefaults.standard.set(selectedBackgroundID.uuidString, forKey: Keys.backgroundID) }
    }

    var customBackgrounds: [BackgroundStyle] {
        didSet { saveCustomBackgrounds() }
    }

    var watermarkEnabled: Bool {
        didSet { UserDefaults.standard.set(watermarkEnabled, forKey: Keys.watermarkEnabled) }
    }

    var watermarkText: String {
        didSet { UserDefaults.standard.set(watermarkText, forKey: Keys.watermarkText) }
    }

    /// Inset of the device screenshot inside the canvas (0.04...0.20).
    var paddingPercent: Double {
        didSet { UserDefaults.standard.set(paddingPercent, forKey: Keys.paddingPercent) }
    }

    var deviceCornerRadius: Double {
        didSet { UserDefaults.standard.set(deviceCornerRadius, forKey: Keys.cornerRadius) }
    }

    var showDeviceShadow: Bool {
        didSet { UserDefaults.standard.set(showDeviceShadow, forKey: Keys.showDeviceShadow) }
    }

    var screenshotTransform: CanvasElementTransform {
        didSet { save(screenshotTransform, forKey: Keys.screenshotTransform) }
    }

    var titleTransform: CanvasElementTransform {
        didSet { save(titleTransform, forKey: Keys.titleTransform) }
    }

    var deviceFrameStyle: DeviceFrameStyle {
        didSet { UserDefaults.standard.set(deviceFrameStyle.rawValue, forKey: Keys.deviceFrameStyle) }
    }

    var productBezelDevice: ProductBezelDevice {
        didSet {
            UserDefaults.standard.set(productBezelDevice.rawValue, forKey: Keys.productBezelDevice)
            if !productBezelDevice.finishes.contains(productBezelFinish) {
                productBezelFinish = productBezelDevice.defaultFinish
            }
        }
    }

    var productBezelFinish: String {
        didSet { UserDefaults.standard.set(productBezelFinish, forKey: Keys.productBezelFinish) }
    }

    /// Symmetric screen inset used to align a screenshot below an imported transparent bezel.
    var importedBezelInset: Double {
        didSet { UserDefaults.standard.set(importedBezelInset, forKey: Keys.importedBezelInset) }
    }

    var titleEnabled: Bool {
        didSet { UserDefaults.standard.set(titleEnabled, forKey: Keys.titleEnabled) }
    }

    var titleText: String {
        didSet { UserDefaults.standard.set(titleText, forKey: Keys.titleText) }
    }

    /// PostScript font name from the user's installed macOS fonts.
    var titleFontName: String {
        didSet { UserDefaults.standard.set(titleFontName, forKey: Keys.titleFontName) }
    }

    var titleFontSize: Double {
        didSet { UserDefaults.standard.set(titleFontSize, forKey: Keys.titleFontSize) }
    }

    /// Carbon / NSEvent key code. Default: S
    var hotkeyKeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode) }
    }

    /// NSEvent modifier flags raw value. Default: ⌘⇧
    var hotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(Int(hotkeyModifiers), forKey: Keys.hotkeyModifiers) }
    }

    var preferredSimulatorUDID: String? {
        didSet { UserDefaults.standard.set(preferredSimulatorUDID, forKey: Keys.preferredSimulatorUDID) }
    }

    var allBackgrounds: [BackgroundStyle] {
        BackgroundStyle.presets + customBackgrounds
    }

    var selectedBackground: BackgroundStyle {
        allBackgrounds.first(where: { $0.id == selectedBackgroundID })
            ?? BackgroundStyle.presets[0]
    }

    init() {
        let defaults = UserDefaults.standard

        if let raw = defaults.string(forKey: Keys.platform),
           let platform = SocialPlatform(rawValue: raw) {
            selectedPlatform = platform
        } else {
            selectedPlatform = .instagramPortrait
        }

        if let idString = defaults.string(forKey: Keys.backgroundID),
           let id = UUID(uuidString: idString) {
            selectedBackgroundID = id
        } else {
            selectedBackgroundID = BackgroundStyle.presets[0].id
        }

        customBackgrounds = Self.loadCustomBackgrounds()
        watermarkEnabled = defaults.object(forKey: Keys.watermarkEnabled) as? Bool ?? true
        watermarkText = defaults.string(forKey: Keys.watermarkText) ?? "ShotCapture"
        paddingPercent = defaults.object(forKey: Keys.paddingPercent) as? Double ?? 0.10
        deviceCornerRadius = defaults.object(forKey: Keys.cornerRadius) as? Double ?? 48
        showDeviceShadow = defaults.object(forKey: Keys.showDeviceShadow) as? Bool ?? true
        screenshotTransform = Self.load(
            CanvasElementTransform.self,
            forKey: Keys.screenshotTransform
        ) ?? .screenshotDefault
        titleTransform = Self.load(
            CanvasElementTransform.self,
            forKey: Keys.titleTransform
        ) ?? .titleDefault
        let storedFrameStyle = defaults.string(forKey: Keys.deviceFrameStyle)
            .flatMap(DeviceFrameStyle.init(rawValue:)) ?? .appleProductBezel
        deviceFrameStyle = storedFrameStyle == .appleProductBezel
            && !ProductBezelDevice.bundledResourcesAvailable
            ? .genericPhone
            : storedFrameStyle
        let storedDevice = defaults.string(forKey: Keys.productBezelDevice)
            .flatMap(ProductBezelDevice.init(rawValue:)) ?? .iPhone17
        productBezelDevice = storedDevice
        let storedFinish = defaults.string(forKey: Keys.productBezelFinish)
        productBezelFinish = storedFinish.flatMap { storedDevice.finishes.contains($0) ? $0 : nil }
            ?? storedDevice.defaultFinish
        importedBezelInset = defaults.object(forKey: Keys.importedBezelInset) as? Double ?? 0.055
        titleEnabled = defaults.object(forKey: Keys.titleEnabled) as? Bool ?? false
        titleText = defaults.string(forKey: Keys.titleText) ?? "Your app, beautifully presented"
        titleFontName = defaults.string(forKey: Keys.titleFontName)
            ?? NSFont.systemFont(ofSize: 72, weight: .bold).fontName
        titleFontSize = defaults.object(forKey: Keys.titleFontSize) as? Double ?? 72

        // Default: ⌘⇧S
        let defaultModifiers = NSEvent.ModifierFlags([.command, .shift]).rawValue
        hotkeyKeyCode = UInt16(defaults.object(forKey: Keys.hotkeyKeyCode) as? Int ?? 1) // S
        hotkeyModifiers = UInt(defaults.object(forKey: Keys.hotkeyModifiers) as? Int ?? Int(defaultModifiers))
        preferredSimulatorUDID = defaults.string(forKey: Keys.preferredSimulatorUDID)
    }

    func addCustomBackground(_ style: BackgroundStyle) {
        var copy = style
        copy.isCustom = true
        customBackgrounds.append(copy)
        selectedBackgroundID = copy.id
    }

    func removeCustomBackground(_ id: UUID) {
        customBackgrounds.removeAll { $0.id == id }
        if selectedBackgroundID == id {
            selectedBackgroundID = BackgroundStyle.presets[0].id
        }
    }

    func resetCanvasTransforms() {
        screenshotTransform = .screenshotDefault
        titleTransform = .titleDefault
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func saveCustomBackgrounds() {
        guard let data = try? JSONEncoder().encode(customBackgrounds) else { return }
        UserDefaults.standard.set(data, forKey: Keys.customBackgrounds)
    }

    private static func loadCustomBackgrounds() -> [BackgroundStyle] {
        guard let data = UserDefaults.standard.data(forKey: Keys.customBackgrounds),
              let decoded = try? JSONDecoder().decode([BackgroundStyle].self, from: data) else {
            return []
        }
        return decoded
    }
}
