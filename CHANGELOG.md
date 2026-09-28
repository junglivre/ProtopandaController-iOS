# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- Initial foreground-only iOS port scaffold:
  - `ProtopandaControllerCore` Swift package: BLE identity model, 23-byte packet encoder,
    motion scaling math, and multitouch hit-testing, fully unit-tested (23 tests) and
    verified with `swift test` on Linux.
  - SwiftUI app skeleton (`App/`): status bar, multitouch D-pad, IMU readout, Settings
    screen, Core Bluetooth peripheral controller, and Core Motion sensor reading.
  - `App/project.yml` (XcodeGen) to generate the `.xcodeproj` without committing binary
    project files.
  - Two-job CI pipeline (`.github/workflows/ci.yml`): `swift test` for the core package on
    Linux, and an unsigned-IPA build via `xcodebuild` on a `macos-latest` runner, uploaded
    as a workflow artifact for SideStore sideloading.
  - `docs/ios-foreground-port.md`, `PRIVACY.md`, and bilingual READMEs.
- App icon: the official Protopanda Play Store icon
  (`fastlane/metadata/android/en-US/images/icon.png` from the Android repo), upscaled to
  an opaque 1024×1024 PNG, for visual consistency across both apps. `CFBundleName` also
  set to the literal "Protopanda Controller" (not just `CFBundleDisplayName`), so the app
  name shows correctly everywhere regardless of which key a given sideloading tool reads.
- Localization (English/Portuguese), a real "quit app" action, and GitHub Release
  publishing tagged with the short commit SHA (raw, unzipped `.ipa` asset for sideloading
  directly from an iPhone).

### Changed

- **Background BLE session** (`bluetooth-peripheral` mode): the app is no longer
  foreground-only. `ControllerViewModel` now starts the BLE session once at launch instead
  of on every `scenePhase` transition; only motion sensing, touch input, and the outgoing
  notify timer pause when the app leaves `.active`. `BLEPeripheralController` opts in to
  Core Bluetooth state preservation/restoration (`CBPeripheralManagerOptionRestoreIdentifierKey`
  + `willRestoreState`) so a system-killed-and-relaunched process can recover its published
  service and already-subscribed central. CI now asserts `UIBackgroundModes` contains
  `bluetooth-peripheral` in the compiled binary.

  Root cause this replaces: reported on real hardware, leaving the app for more than a few
  seconds made the Protopanda receiver assign a new controller ID on reconnect (the old one
  stuck unusable), with iOS's Bluetooth settings showing a nameless "connected" device even
  after the app tore down its GATT services. An earlier mitigation (fully deallocating
  `CBPeripheralManager` on backgrounding) did not fix it. Motion sensors and touch input
  still require the foreground — there is no background mode for continuous
  `CMMotionManager` streaming — so input freezes at its last known state while backgrounded,
  but the connection and controller ID now stay stable across app switches.
