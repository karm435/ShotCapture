# ShotCapture

Menu bar macOS app that captures stills or video from a booted iOS Simulator, imports images and movies, and exports social-ready PNG or MP4 compositions.

## Features

- Menu bar capture of a booted iOS Simulator using `xcrun simctl`
- H.264 Simulator video recording with start, stop, and automatic editor import
- Import images or MOV, MP4, and M4V video; paste images or copied video files
- Play, seek, and trim video while preserving imported audio
- Export composed video as social-ready H.264 and AAC MP4
- Standalone editor for imported or pasted images; Simulator captures can dock the editor beside Simulator
- Drag, scale, rotate, and apply 3D perspective tilt with model-accurate device depth; add a draggable title using any installed system font
- Built-in Apple product bezels for iPhone, iPad, Mac, displays, Apple Watch, and Apple TV
- Generic framing and support for additional locally imported bezels
- Platform presets sized so the full image shows in-feed:
  - **X** 1600×900 (16:9)
  - **LinkedIn** 1200×627 and 1200×1200
  - **Instagram** 1080×1350, 1080×1080, 1080×1920
  - **Facebook**, **TikTok**, **YouTube**, **Bluesky**
- 22 Grok Imagine preset backgrounds + Studio Black / Clean White gradients
- Custom linear/radial gradient creator
- Bottom-right watermark (configurable)
- Global keyboard shortcut (default ⌘⇧S)

## Distribution requirements

| Setting | Value |
|---------|--------|
| **Distribution** | Local source builds or direct Developer ID distribution |
| **App Sandbox** | Disabled because Simulator capture invokes `simctl` |
| **Category** | `public.app-category.developer-tools` |
| **Capture method** | `xcrun simctl io <UDID> screenshot` or `recordVideo` |

ShotCapture uses the active Xcode command-line tools selected on the Mac. App
Sandbox is incompatible with the CoreSimulator services used by `simctl`, so
Mac App Store distribution is not supported by this capture architecture.

## Requirements

| Need | Why | Required? |
|------|-----|-----------|
| **Xcode command-line tools** | Provides `xcrun simctl` | Simulator still or video capture only |
| **Booted Simulator** | Simulator media source | Simulator still or video capture only |
| **Accessibility** | Global hotkey only | Optional |
| **Downloads / Save panel** | Export framed PNGs or MP4 videos | Yes |

## Usage

1. Launch ShotCapture and choose **Open Editor** from the menu bar item.
2. Use **Import** or **Paste** to prepare an image or video without Xcode or a running Simulator.
3. For Simulator capture, boot an iOS Simulator, then choose **Capture Simulator Still** or **Record Simulator Video**.
4. Select **Screenshot** or **Title**, then drag on the canvas. On a Mac trackpad, pinch to scale, twist two fingers to rotate around Z, or pan two fingers to control Tilt X/Y. The sliders provide precise values, and 1× Depth follows the selected iPhone's physical proportions.
5. For video, use the playback and trim controls below the canvas.
6. Copy or save a composed PNG, or export video as MP4.

Simulator video capture records the Simulator display without audio. Audio from imported videos is preserved during MP4 export.

## Apple Product Bezels

ShotCapture bundles Apple's official transparent PNG bezels for current iPhone, iPad, MacBook, iMac, Studio Display, Apple Watch, and Apple TV hardware. Choose **Apple Product Bezel**, then select a grouped device and its available finish, case-and-band combination, or backdrop. Portrait or landscape artwork is selected automatically where Apple supplies both orientations, and measured screen apertures align the screenshot precisely.

Use **Import Bezels…** for additional artwork; **Screen inset** adjusts custom bezel alignment. Product bezels can use the same drag, scale, tilt, and shadow controls as generic frames.

## Build

```bash
xcodebuild -scheme ShotCapture -configuration Release -destination 'platform=macOS' build
```

See [Direct Distribution](docs/distribution.md) for GitHub Actions signing,
notarization, download delivery, and product-site guidance.
