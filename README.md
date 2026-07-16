# ShotCapture

Menu bar macOS app that captures the booted iOS Simulator, frames the shot on a social-ready canvas, and exports a shareable PNG.

## Features

- Menu bar capture of a booted iOS Simulator using `xcrun simctl`
- Companion preview window that docks beside Simulator (first open)
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
| **Distribution** | Direct distribution (Developer ID or local development) |
| **App Sandbox** | Disabled so the app can invoke Xcode's `simctl` tooling |
| **Category** | `public.app-category.developer-tools` |
| **Capture method** | `xcrun simctl io <UDID> screenshot` |

This configuration is not compatible with Mac App Store submission, which requires App Sandbox.

## Requirements

| Need | Why | Required? |
|------|-----|-----------|
| **Xcode command-line tools** | Provides `xcrun` and `simctl` | Yes |
| **Booted Simulator** | Screenshot source | Yes |
| **Accessibility** | Global hotkey only | Optional |
| **Downloads / Save panel** | Export framed PNGs | Yes |

## Usage

1. Boot an iOS Simulator.
2. Launch ShotCapture (menu bar camera icon).
3. Choose platform + background, then **Capture Simulator**.
4. Copy / Save / Downloads from the preview window.

## Build

```bash
xcodebuild -scheme ShotCapture -configuration Release -destination 'platform=macOS' build
```
