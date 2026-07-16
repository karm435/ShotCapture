# Repository Guidelines

## Project Structure & Module Organization

`ShotCapture/` contains the macOS application. Keep domain values in `Models/`, system and capture behavior in `Services/`, and SwiftUI presentation in `Views/`. `ShotCaptureApp.swift` owns application startup and the AppKit menu-bar integration. Add colors, icons, and background images to `ShotCapture/Assets.xcassets`; privacy purpose strings belong in `Configuration/ShotCapture-Info.plist`.

Unit tests live in `ShotCaptureTests/`; launch and interaction tests live in `ShotCaptureUITests/`. `Scripts/` contains app-icon utilities. `ShotCapture.xcodeproj` defines the Xcode project and `ShotCapture` scheme.

## Build, Test, and Development Commands

- `open ShotCapture.xcodeproj` opens the project; use Xcode's Run action to launch the app.
- `xcodebuild -scheme ShotCapture -configuration Debug -destination 'platform=macOS' build` performs a local debug build.
- `xcodebuild -scheme ShotCapture -configuration Release -destination 'platform=macOS' build` creates a release build.
- `xcodebuild -scheme ShotCapture -destination 'platform=macOS' test` runs both unit and UI test targets.

Boot an iOS Simulator before manually validating capture behavior. Capture uses `xcrun simctl`, so Xcode command-line tools are required. Accessibility permission is only needed for the global hotkey.

## Coding Style & Naming Conventions

Follow standard Swift formatting: four-space indentation, one primary type per file, and trailing commas in multiline argument lists when they improve diffs. Use `UpperCamelCase` for types and protocols, `lowerCamelCase` for methods and properties, and role suffixes such as `Service`, `Controller`, and `View`. Keep UI state changes on the main actor. No external formatter or linter is configured; match nearby code before introducing a pattern.

## Testing Guidelines

Use Swift Testing (`@Test`, `#expect`) for model and service tests. Use XCTest for UI launch and interaction coverage. Name tests after observable behavior, for example `compositionProducesPNG()`. Tests involving Simulator or privacy permissions must handle unavailable devices and denied access without becoming environment-dependent failures.

## Commit & Pull Request Guidelines

History contains only an initial commit, so no established message convention exists. Use short, imperative subjects such as `Add custom gradient presets`. Keep commits focused and exclude generated artifacts such as `default.profraw` or user-specific Xcode data. Pull requests should explain behavior changes, list verification commands, link issues, and include screenshots or exported PNGs for visual changes. Call out permission or distribution changes explicitly; App Sandbox must remain disabled while capture depends on `simctl`.

## Agent-Specific Instructions

Confirm existing code patterns and project settings before editing; do not assume conventions or capabilities. Preserve unrelated working-tree changes and keep changes scoped to the request.
