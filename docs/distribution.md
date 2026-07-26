# Distribution

ShotCapture is open source and intended to be built locally. App Sandbox is
disabled because still and video capture invoke `xcrun simctl`, which needs
access to CoreSimulator services. The app therefore isn't eligible for Mac App
Store distribution with its current capture architecture.

Hardened Runtime remains enabled. If prebuilt binaries are distributed later,
sign them with a **Developer ID Application** certificate and notarize them with
Apple.

## Local builds

Install Xcode, select its command-line tools, and boot an iOS Simulator:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -scheme ShotCapture -configuration Debug -destination 'platform=macOS' build
```

## Optional binary releases

Source users can build and run the app without a distributed binary. If GitHub
Releases provide a prebuilt app later:

- Archive the Release configuration with Hardened Runtime enabled.
- Sign the app with a Developer ID Application certificate.
- Submit it to Apple's notary service and staple the ticket.
- Publish the notarized app in a ZIP or disk image with a checksum.

The release includes the product-bezel PNGs from `ShotCapture/ProductBezels/`.
It also keeps **Import Bezels…** and the Apple resources link for adding future
devices and finishes.

The current app deployment target is macOS 15.6.
