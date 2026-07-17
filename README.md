# ShotCapture

Menu bar macOS app that captures the booted iOS Simulator, frames the shot on a social-ready canvas, and exports a shareable PNG.

## Features

- Menu bar capture of a booted iOS Simulator using `xcrun simctl`
- Import or paste any iPhone screenshot from the clipboard
- Companion preview window that docks beside Simulator (first open)
- Drag, scale, rotate, and apply 3D perspective tilt with model-accurate device depth; add a draggable title using any installed system font
- Built-in Apple iPhone 16/17 product bezels, every finish and orientation
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
| **Distribution** | Mac App Store or direct Developer ID distribution |
| **App Sandbox** | Enabled; the user selects Xcode to grant scoped access |
| **Category** | `public.app-category.developer-tools` |
| **Capture method** | `xcrun simctl io <UDID> screenshot` |

This configuration follows the sandboxed Xcode-access pattern used by Simulator companion tools on the Mac App Store.

## Requirements

| Need | Why | Required? |
|------|-----|-----------|
| **Selected Xcode application** | Grants sandboxed access to `simctl` | Yes |
| **Booted Simulator** | Screenshot source | Yes |
| **Accessibility** | Global hotkey only | Optional |
| **Downloads / Save panel** | Export framed PNGs | Yes |

## Usage

1. Launch ShotCapture and choose the installed Xcode application when prompted.
2. Boot an iOS Simulator.
3. Capture the Simulator, or use **Import** / **Paste** in the preview window.
4. Select **Screenshot** or **Title**, then drag on the canvas. On a Mac trackpad, pinch to scale, twist two fingers to rotate around Z, or pan two fingers to control Tilt X/Y. The sliders provide precise values, and 1× Depth follows the selected iPhone's physical proportions.
5. Copy or save the composed PNG.

## Apple Product Bezels

ShotCapture bundles Apple's official transparent PNG bezels for iPhone 17, iPhone Air, iPhone 17 Pro/Pro Max, and the complete iPhone 16 family. Choose **Apple Product Bezel**, then select a device and finish. Portrait or landscape artwork is selected automatically from the source image orientation, and measured screen apertures align the screenshot precisely.

Use **Import Bezels…** for additional artwork; **Screen inset** adjusts custom bezel alignment. Product bezels can use the same drag, scale, tilt, and shadow controls as generic frames.

## Build

```bash
xcodebuild -scheme ShotCapture -configuration Release -destination 'platform=macOS' build
```

See [Direct Distribution](docs/distribution.md) for GitHub Actions signing,
notarization, download delivery, and product-site guidance.
