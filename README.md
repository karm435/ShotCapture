# ShotCapture

ShotCapture is an open-source macOS workspace for creating App Store screenshots
and App Previews from an iOS Simulator or imported media. It also includes a
menu-bar Quick Editor for producing framed social images and videos.

## Features

### App Store screenshot campaigns

- Native three-pane campaign workspace that opens when ShotCapture launches
- Up to 10 ordered screenshot panels with duplicate, delete, and reorder actions
- iPhone 6.9-inch and iPad 13-inch portrait and landscape display targets
- Feature, Centered, Full Bleed, and Editorial layout templates
- Per-target screenshots, device frames, positioning, scaling, and rotation
- Reusable headlines, subtitles, backgrounds, gradients, fonts, and text colors
- Import existing screenshots or capture a booted Simulator directly
- Built-in Apple product bezels, a generic frame, and imported bezel support
- Live preview and preflight checks for missing media and App Store limits
- Exact-size, opaque PNG export grouped by locale and display target
- Autosaved projects and portable `.shotcapturecampaign` Finder packages that
  include imported media

### App Previews

- Import MOV, MP4, or M4V video, or record a booted Simulator
- Maintain up to 3 App Previews for each display target
- Play, seek, and choose a 15–30 second trim range
- Aspect-fill source video into the selected App Store display size
- Export QuickTime MOV with H.264 video at no more than 30 fps
- Preserve existing audio when it meets App Store requirements
- Automatically add a silent stereo 44.1 kHz audio track when Simulator video
  has no audio—no separate `ffmpeg` repair step is required
- Validate duration, dimensions, frame rate, stereo audio, sample rate, and the
  500 MB file limit after export
- Progress reporting and cancellation for longer exports

### Quick Editor and social exports

- Capture stills and H.264 video from a booted iOS Simulator using `xcrun simctl`
- Import or paste images and copied video files
- Play, seek, and trim imported video while preserving its audio
- Export social-ready PNG or H.264/AAC MP4 compositions
- Dock Simulator captures beside Simulator for a fast edit-and-export workflow
- Drag, scale, rotate, and apply 3D perspective tilt with model-accurate depth
- Add draggable titles using any installed system font
- Built-in Apple product bezels for iPhone, iPad, Mac, displays, Apple Watch,
  and Apple TV
- Generic frames and support for additional locally imported bezels
- 22 Grok Imagine background presets, Studio Black and Clean White gradients,
  and a custom linear/radial gradient creator
- Configurable bottom-right watermark
- Configurable global keyboard shortcut, defaulting to ⌘⇧S

## App Store display targets

| Display target | Screenshot size | App Preview size |
|---|---:|---:|
| iPhone 6.9-inch portrait | 1320×2868 | 886×1920 |
| iPhone 6.9-inch landscape | 2868×1320 | 1920×886 |
| iPad 13-inch portrait | 2064×2752 | 1200×1600 |
| iPad 13-inch landscape | 2752×2064 | 1600×1200 |

See Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
and [App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
before submitting exported assets.

## Social platform presets

| Platform | Canvas |
|---|---:|
| X | 1600×900 |
| LinkedIn landscape | 1200×627 |
| LinkedIn square | 1200×1200 |
| Instagram portrait / Facebook | 1080×1350 |
| Instagram square | 1080×1080 |
| Instagram Stories / TikTok | 1080×1920 |
| YouTube thumbnail | 1280×720 |
| Bluesky | 1000×1000 |

## Usage

### Create App Store assets

1. Launch ShotCapture. The **App Store Campaigns** workspace opens automatically.
2. Select the iPhone and iPad display targets needed for the release.
3. Add screenshot panels and choose a layout, background, typography, and frame.
4. Import a screenshot for each target or capture the active Simulator.
5. Switch to **App Previews** to import or record video, then set its trim range.
6. Resolve any preflight errors and export screenshots or App Previews.
7. Use **Save As** to keep a portable `.shotcapturecampaign` project.

Screenshot exports are organized as:

```text
<campaign>-app-store-assets/
└── <locale>/
    └── Screenshots/
        └── <display-target>/
            └── 01-<panel-name>.png
```

App Preview exports use the same locale and display-target grouping under an
`App Previews` directory.

### Use the Quick Editor

1. Choose **Quick Editor** from the ShotCapture menu-bar item.
2. Import or paste media, or use **Capture Simulator Still** or
   **Record Simulator Video**.
3. Select the screenshot or title and adjust its position, scale, rotation,
   perspective tilt, frame, background, and shadow.
4. Use the playback and trim controls when editing video.
5. Copy or save a composed PNG, or export an MP4.

Simulator recordings do not contain audio. Quick Editor video exports preserve
audio from imported movies; App Preview exports insert a compliant silent stereo
track when the source is silent.

## Apple Product Bezels

ShotCapture bundles Apple's transparent PNG bezels for current iPhone, iPad,
MacBook, iMac, Studio Display, Apple Watch, and Apple TV hardware. Choose
**Apple Product Bezel**, then select a grouped device and its available finish,
case-and-band combination, or backdrop. Portrait or landscape artwork is
selected automatically where Apple supplies both orientations, and measured
screen apertures align the screenshot precisely.

Use **Import Bezels…** for additional artwork. **Screen inset** adjusts custom
bezel alignment. Product bezels support the same drag, scale, tilt, depth, and
shadow controls as generic frames.

## Requirements

| Need | Why | Required? |
|---|---|---|
| macOS 15.6 or later | ShotCapture deployment target | Yes |
| Xcode command-line tools | Provides `xcrun simctl` | Simulator capture only |
| Booted iOS Simulator | Simulator media source | Simulator capture only |
| Accessibility permission | Global keyboard shortcut | Optional |

Image and video import work without Xcode or a running Simulator.

## Distribution

| Setting | Value |
|---|---|
| Distribution | Local source builds or direct Developer ID distribution |
| App Sandbox | Disabled because Simulator capture invokes `simctl` |
| Category | `public.app-category.developer-tools` |
| Capture method | `xcrun simctl io <UDID> screenshot` or `recordVideo` |

ShotCapture uses the active Xcode command-line tools selected on the Mac. App
Sandbox prevents the child `simctl` process from reaching the CoreSimulator
services used for capture, so the current architecture does not support Mac App
Store distribution.

## Build

```bash
git clone https://github.com/karm435/ShotCapture.git
cd ShotCapture
xcodebuild -scheme ShotCapture -configuration Debug -destination 'platform=macOS' build
open ShotCapture.xcodeproj
```

See [Direct Distribution](docs/distribution.md) for GitHub Actions signing,
notarization, download delivery, and product-site guidance.
