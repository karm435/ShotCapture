//
//  ProductBezelDevice.swift
//  ShotCapture
//

import AppKit
import Foundation

nonisolated enum ProductBezelCategory: String, CaseIterable, Identifiable, Sendable {
    case iPhone = "iPhone"
    case iPad = "iPad"
    case mac = "Mac & Displays"
    case appleWatch = "Apple Watch"
    case appleTV = "Apple TV"

    var id: String { rawValue }

    var devices: [ProductBezelDevice] {
        ProductBezelDevice.availableCases.filter { $0.category == self }
    }
}

nonisolated enum ProductBezelDevice: String, CaseIterable, Codable, Identifiable, Sendable {
    case iPhone17 = "iPhone 17"
    case iPhoneAir = "iPhone Air"
    case iPhone17Pro = "iPhone 17 Pro"
    case iPhone17ProMax = "iPhone 17 Pro Max"
    case iPhone16 = "iPhone 16"
    case iPhone16Plus = "iPhone 16 Plus"
    case iPhone16Pro = "iPhone 16 Pro"
    case iPhone16ProMax = "iPhone 16 Pro Max"

    case iPadA16 = "iPad (A16)"
    case iPadAir11M4 = "iPad Air 11-inch (M4)"
    case iPadAir13M4 = "iPad Air 13-inch (M4)"
    case iPadMiniA17Pro = "iPad mini (A17 Pro)"
    case iPadPro11M5 = "iPad Pro 11-inch (M5)"
    case iPadPro13M5 = "iPad Pro 13-inch (M5)"

    case macBookAir13M5 = "MacBook Air 13-inch (M5)"
    case macBookAir15M5 = "MacBook Air 15-inch (M5)"
    case macBookPro14M5 = "MacBook Pro 14-inch (M5)"
    case macBookPro16M5 = "MacBook Pro 16-inch (M5)"
    case macBookNeo = "MacBook Neo"
    case iMacM4 = "iMac 24-inch (M4)"
    case studioDisplay = "Studio Display (2026)"
    case studioDisplayXDR = "Studio Display XDR (2026)"

    case appleWatchUltra2 = "Apple Watch Ultra 2 (2024)"
    case appleWatchUltra3 = "Apple Watch Ultra 3 (2025)"
    case appleWatchSeries11_42 = "Apple Watch Series 11 (42mm)"
    case appleWatchSeries11_46 = "Apple Watch Series 11 (46mm)"

    case appleTV4K = "Apple TV 4K"

    private enum ResourceNaming {
        case oriented
        case hyphenatedFinish
        case spacedFinish
        case studioDisplay
    }

    var id: String { rawValue }
    var displayName: String { rawValue }

    static var availableCases: [ProductBezelDevice] {
        allCases.filter(\.hasBundledResource)
    }

    static var bundledResourcesAvailable: Bool {
        !availableCases.isEmpty
    }

    var category: ProductBezelCategory {
        switch self {
        case .iPhone17, .iPhoneAir, .iPhone17Pro, .iPhone17ProMax,
             .iPhone16, .iPhone16Plus, .iPhone16Pro, .iPhone16ProMax:
            .iPhone
        case .iPadA16, .iPadAir11M4, .iPadAir13M4, .iPadMiniA17Pro,
             .iPadPro11M5, .iPadPro13M5:
            .iPad
        case .macBookAir13M5, .macBookAir15M5, .macBookPro14M5,
             .macBookPro16M5, .macBookNeo, .iMacM4, .studioDisplay,
             .studioDisplayXDR:
            .mac
        case .appleWatchUltra2, .appleWatchUltra3,
             .appleWatchSeries11_42, .appleWatchSeries11_46:
            .appleWatch
        case .appleTV4K:
            .appleTV
        }
    }

    var variantLabel: String {
        switch category {
        case .appleWatch: "Case & band"
        case .appleTV: "Model"
        case .iPhone, .iPad, .mac:
            switch self {
            case .studioDisplay, .studioDisplayXDR: "Backdrop"
            default: "Finish"
            }
        }
    }

    var finishes: [String] {
        let discovered = Set(Self.bundledResourceNames.compactMap { finish(from: $0) })
        return discovered.isEmpty ? [defaultFinish] : discovered.sorted()
    }

    var defaultFinish: String {
        switch self {
        case .iPhone17, .iPhone16, .iPhone16Plus:
            "Black"
        case .iPhoneAir:
            "Space Black"
        case .iPhone17Pro, .iPhone17ProMax:
            "Deep Blue"
        case .iPhone16Pro, .iPhone16ProMax:
            "Black Titanium"
        case .iPadA16, .iPadAir11M4, .iPadAir13M4, .iPadMiniA17Pro:
            "Blue"
        case .iPadPro11M5, .iPadPro13M5,
             .macBookPro14M5, .macBookPro16M5:
            "Silver"
        case .macBookAir13M5, .macBookAir15M5:
            "Midnight"
        case .macBookNeo:
            "Blush"
        case .iMacM4:
            "Blue"
        case .studioDisplay, .studioDisplayXDR:
            "On Light Background"
        case .appleWatchUltra2:
            "Black + Alpine Loop Dark Green"
        case .appleWatchUltra3:
            "Black + Alpine Loop Black"
        case .appleWatchSeries11_42, .appleWatchSeries11_46:
            "Aluminum Jet Black + Sport Band Black"
        case .appleTV4K:
            "4K"
        }
    }

    /// Approximate physical device depth divided by body width. Display artwork
    /// uses a conservative ratio because its PNG can also include a stand or base.
    var thicknessToWidthRatio: Double {
        switch self {
        case .iPhone17: 7.95 / 71.5
        case .iPhoneAir: 5.64 / 74.7
        case .iPhone17Pro: 8.75 / 71.9
        case .iPhone17ProMax: 8.75 / 78.0
        case .iPhone16: 7.80 / 71.6
        case .iPhone16Plus: 7.80 / 77.8
        case .iPhone16Pro: 8.25 / 71.5
        case .iPhone16ProMax: 8.25 / 77.6
        case .iPadA16: 7.0 / 179.5
        case .iPadAir11M4: 6.1 / 178.5
        case .iPadAir13M4: 6.1 / 214.9
        case .iPadMiniA17Pro: 6.3 / 134.8
        case .iPadPro11M5: 5.3 / 177.5
        case .iPadPro13M5: 5.1 / 215.5
        case .macBookAir13M5: 11.3 / 304.1
        case .macBookAir15M5: 11.5 / 340.4
        case .macBookPro14M5: 15.5 / 312.6
        case .macBookPro16M5: 16.8 / 355.7
        case .macBookNeo: 0.045
        case .iMacM4, .studioDisplay, .studioDisplayXDR, .appleTV4K: 0.025
        case .appleWatchUltra2, .appleWatchUltra3: 12.0 / 49.0
        case .appleWatchSeries11_42: 9.7 / 42.0
        case .appleWatchSeries11_46: 9.7 / 46.0
        }
    }

    var screenCornerRadiusRatio: Double {
        switch category {
        case .iPhone: 0.105
        case .iPad: 0.055
        case .appleWatch: 0.16
        case .appleTV: 0.0
        case .mac:
            switch self {
            case .macBookAir13M5, .macBookAir15M5, .macBookPro14M5,
                 .macBookPro16M5, .macBookNeo:
                0.012
            case .iMacM4, .studioDisplay, .studioDisplayXDR:
                0.0
            default:
                0.0
            }
        }
    }

    func edgeTint(finish: String) -> NSColor {
        let normalized = finish.lowercased()
        if normalized.contains("silver") || normalized.contains("white")
            || normalized.contains("starlight") || normalized.contains("natural") {
            return NSColor(calibratedRed: 0.67, green: 0.70, blue: 0.73, alpha: 1)
        }
        if normalized.contains("lavender") || normalized.contains("purple") {
            return NSColor(calibratedRed: 0.48, green: 0.45, blue: 0.56, alpha: 1)
        }
        if normalized.contains("blue") || normalized.contains("indigo")
            || normalized.contains("ultramarine") {
            return NSColor(calibratedRed: 0.25, green: 0.40, blue: 0.55, alpha: 1)
        }
        if normalized.contains("sage") || normalized.contains("teal")
            || normalized.contains("green") {
            return NSColor(calibratedRed: 0.28, green: 0.47, blue: 0.43, alpha: 1)
        }
        if normalized.contains("gold") || normalized.contains("orange")
            || normalized.contains("desert") || normalized.contains("citrus") {
            return NSColor(calibratedRed: 0.61, green: 0.43, blue: 0.25, alpha: 1)
        }
        if normalized.contains("pink") || normalized.contains("blush")
            || normalized.contains("rose") {
            return NSColor(calibratedRed: 0.62, green: 0.39, blue: 0.45, alpha: 1)
        }
        return NSColor(calibratedWhite: 0.16, alpha: 1)
    }

    func resourceName(finish: String, isLandscape: Bool) -> String {
        let validFinish = finishes.contains(finish) ? finish : defaultFinish
        switch resourceNaming {
        case .oriented:
            let orientation = isLandscape ? "Landscape" : "Portrait"
            return "\(resourcePrefix) - \(validFinish) - \(orientation)"
        case .hyphenatedFinish:
            return "\(resourcePrefix) - \(validFinish)"
        case .spacedFinish:
            return "\(resourcePrefix) \(validFinish)"
        case .studioDisplay:
            return "\(resourcePrefix) 2026 \(validFinish)"
        }
    }

    func resourceURL(finish: String, isLandscape: Bool, bundle: Bundle = .main) -> URL? {
        let name = resourceName(finish: finish, isLandscape: isLandscape)
        return bundle.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "ProductBezels"
        ) ?? bundle.url(forResource: name, withExtension: "png")
    }

    /// Normalized transparent screen aperture measured from Apple's supplied PNG pixels.
    func screenAperture(isLandscape: Bool) -> CGRect {
        let aperture: CGRect
        switch self {
        case .iPhone17, .iPhone17Pro, .iPhone16Pro:
            aperture = Self.aperture(1350, 2760, 72, 69, 1278, 2691)
        case .iPhoneAir:
            aperture = Self.aperture(1380, 2880, 60, 72, 1320, 2808)
        case .iPhone17ProMax, .iPhone16ProMax:
            aperture = Self.aperture(1470, 3000, 75, 66, 1395, 2934)
        case .iPhone16:
            aperture = Self.aperture(1359, 2736, 90, 90, 1269, 2646)
        case .iPhone16Plus:
            aperture = Self.aperture(1470, 2970, 90, 87, 1380, 2883)
        case .iPadA16:
            aperture = Self.aperture(2040, 2760, 200, 200, 1839, 2560)
        case .iPadAir11M4:
            aperture = Self.aperture(1900, 2620, 130, 130, 1770, 2490)
        case .iPadAir13M4:
            aperture = Self.aperture(2300, 2980, 126, 124, 2174, 2856)
        case .iPadMiniA17Pro:
            aperture = Self.aperture(1780, 2550, 146, 142, 1634, 2408)
        case .iPadPro11M5:
            aperture = Self.aperture(1880, 2640, 106, 110, 1774, 2530)
        case .iPadPro13M5:
            aperture = Self.aperture(2300, 3000, 118, 124, 2182, 2876)
        case .macBookAir13M5:
            return Self.aperture(3400, 2240, 420, 288, 2980, 1952)
        case .macBookAir15M5:
            return Self.aperture(3540, 2300, 329, 218, 3209, 2082)
        case .macBookPro14M5:
            return Self.aperture(3860, 2540, 418, 288, 3442, 2252)
        case .macBookPro16M5:
            return Self.aperture(4260, 2840, 402, 303, 3858, 2537)
        case .macBookNeo:
            return Self.aperture(3220, 2100, 406, 297, 2814, 1803)
        case .iMacM4:
            return Self.aperture(4760, 4050, 140, 150, 4620, 2670)
        case .studioDisplay, .studioDisplayXDR:
            return Self.aperture(5400, 4160, 140, 140, 5260, 3020)
        case .appleWatchUltra2:
            return Self.aperture(600, 940, 95, 219, 505, 721)
        case .appleWatchUltra3:
            return Self.aperture(600, 960, 89, 223, 511, 737)
        case .appleWatchSeries11_42:
            return Self.aperture(520, 800, 73, 177, 447, 623)
        case .appleWatchSeries11_46:
            return Self.aperture(560, 880, 72, 192, 488, 688)
        case .appleTV4K:
            return Self.aperture(4300, 2780, 103, 120, 3943, 2280)
        }

        guard isLandscape else { return aperture }
        return CGRect(
            x: aperture.minY,
            y: aperture.minX,
            width: aperture.height,
            height: aperture.width
        )
    }

    private var hasBundledResource: Bool {
        resourceURL(finish: defaultFinish, isLandscape: false) != nil
    }

    private var resourceNaming: ResourceNaming {
        switch self {
        case .iPhone17, .iPhoneAir, .iPhone17Pro, .iPhone17ProMax,
             .iPhone16, .iPhone16Plus, .iPhone16Pro, .iPhone16ProMax,
             .iPadA16, .iPadAir11M4, .iPadAir13M4, .iPadMiniA17Pro,
             .iPadPro11M5, .iPadPro13M5:
            .oriented
        case .macBookNeo, .appleWatchUltra2, .appleWatchUltra3,
             .appleWatchSeries11_42, .appleWatchSeries11_46, .appleTV4K:
            .hyphenatedFinish
        case .macBookAir13M5, .macBookAir15M5, .macBookPro14M5,
             .macBookPro16M5, .iMacM4:
            .spacedFinish
        case .studioDisplay, .studioDisplayXDR:
            .studioDisplay
        }
    }

    private var resourcePrefix: String {
        switch self {
        case .iPadAir11M4: "iPad Air 11\" (M4)"
        case .iPadAir13M4: "iPad Air 13\" (M4)"
        case .iPadPro11M5: "iPad Pro (M5) 11\""
        case .iPadPro13M5: "iPad Pro (M5) 13\""
        case .macBookAir13M5: "MacBook Air M5 13-inch"
        case .macBookAir15M5: "MacBook Air M5 15-inch"
        case .macBookPro14M5: "MacBook Pro M5 14-inch"
        case .macBookPro16M5: "MacBook Pro M5 16-inch"
        case .iMacM4: "iMac M4 24-inch"
        case .studioDisplay: "Studio Display"
        case .studioDisplayXDR: "Studio Display XDR"
        case .appleWatchUltra2: "AW Ultra 2"
        case .appleWatchUltra3: "AW Ultra 3"
        case .appleWatchSeries11_42: "Apple Watch S11 - 42mm"
        case .appleWatchSeries11_46: "Apple Watch S11 - 46mm"
        case .appleTV4K: "Apple TV"
        default: rawValue
        }
    }

    private func finish(from resourceName: String) -> String? {
        let prefix: String
        switch resourceNaming {
        case .oriented, .hyphenatedFinish:
            prefix = "\(resourcePrefix) - "
        case .spacedFinish:
            prefix = "\(resourcePrefix) "
        case .studioDisplay:
            prefix = "\(resourcePrefix) 2026 "
        }
        guard resourceName.hasPrefix(prefix) else { return nil }
        let remainder = String(resourceName.dropFirst(prefix.count))
        switch resourceNaming {
        case .oriented:
            for suffix in [" - Portrait", " - Landscape"] where remainder.hasSuffix(suffix) {
                return String(remainder.dropLast(suffix.count))
            }
            return nil
        case .hyphenatedFinish, .spacedFinish, .studioDisplay:
            return remainder
        }
    }

    private static func aperture(
        _ imageWidth: CGFloat,
        _ imageHeight: CGFloat,
        _ left: CGFloat,
        _ top: CGFloat,
        _ right: CGFloat,
        _ bottom: CGFloat
    ) -> CGRect {
        CGRect(
            x: left / imageWidth,
            y: (imageHeight - bottom) / imageHeight,
            width: (right - left) / imageWidth,
            height: (bottom - top) / imageHeight
        )
    }

    private static let bundledResourceNames: Set<String> = {
        let nested = Bundle.main.urls(
            forResourcesWithExtension: "png",
            subdirectory: "ProductBezels"
        ) ?? []
        let root = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        return Set((nested + root).map { $0.deletingPathExtension().lastPathComponent })
    }()
}
