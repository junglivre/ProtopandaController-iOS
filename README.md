# Protopanda Controller — iOS

[🇺🇸 English](README.md) | [🇧🇷 Português](README.pt-BR.md)

Foreground-only native iOS port of [Protopanda Controller](https://github.com/junglivre/ProtopandaController) (Android). Acts as a Bluetooth Low Energy (BLE) peripheral for Protopanda platforms, sending the iPhone's motion data and on-screen button state using the same protocol as the Android app.

This app works only while it is open and in the foreground. It does not request the `bluetooth-peripheral` background mode; leaving the app or locking the screen stops advertising, sensors, and notifications. See [`docs/ios-foreground-port.md`](docs/ios-foreground-port.md) for the full specification, briefing, protocol contract, architecture, and test matrix.

## Repository layout

| Path | Purpose |
|---|---|
| `ProtopandaControllerCore/` | Pure Swift Package: BLE identity model, packet encoder, motion scaling math, multitouch hit-testing. Cross-platform, unit-tested on Linux CI. |
| `App/` | iOS app target: SwiftUI UI, Core Bluetooth peripheral controller, Core Motion sensor reading. Generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `App/project.yml`, built with Xcode on macOS. |
| `docs/` | Specification and briefing for this port. |

## Requirements

- iOS 15 or newer.
- An iPhone whose Bluetooth chipset supports BLE peripheral and advertising mode.
- An accelerometer and gyroscope for motion controls.
- No Mac required for development: see [Building without a Mac](#building-without-a-mac).

## Building without a Mac

There is no local Xcode toolchain in this development environment, so the project is built two ways:

1. **Core logic** (`ProtopandaControllerCore/`): pure Swift, tested with `swift test` on Linux (works locally too, e.g. via the official `swift` Docker image, since it has no Apple-framework dependency).
2. **iOS app** (`App/`): built by a `macos-latest` GitHub Actions runner (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)). The workflow installs [XcodeGen](https://github.com/yonaskolb/XcodeGen), generates the `.xcodeproj` from `App/project.yml`, and runs `xcodebuild` with code signing disabled to produce an unsigned `.app`, packaged as the `ProtopandaController-unsigned-ipa` artifact.

To install a build on a physical iPhone, download the `ProtopandaController-unsigned-ipa` artifact from the latest successful [Actions run](../../actions) and sideload it directly with [SideStore](https://sidestore.io) (or AltStore). SideStore fully re-signs apps with your personal Apple ID certificate, so the IPA does not need to be signed ahead of time.

The simulator is not part of this pipeline: Core Bluetooth peripheral mode, advertising, and real motion sensors only work on a physical device, so acceptance testing always happens through a sideloaded build on an iPhone, against a real Protopanda receiver.

## Known gaps in this first version

- No app icon asset yet (placeholder `AppIcon.appiconset` with no image; Xcode will warn, the app is still installable).
- No automated UI tests; `docs/ios-foreground-port.md` §11 lists the manual acceptance matrix (P01–P13) to run against a real Protopanda receiver.
- Background BLE, lock-screen operation, and Core Bluetooth state restoration are explicitly out of scope for this version (§13 of the spec).

## About and credits

- [GooDDu](https://github.com/GooDDu) — first version of the Android app.
- [mockthebear](https://github.com/mockthebear) — creator of Protopanda.
- [junglivre](https://github.com/junglivre) — iOS port and Android app improvements.
