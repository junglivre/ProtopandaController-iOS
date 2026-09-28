# Protopanda Controller

<p align="center">
  <img src="https://github.com/mockthebear/proto-panda/raw/main/doc/logoprotopanda.png" alt="Protopanda logo">
</p>

**🇺🇸 English** | [🇧🇷 Português](README.pt-BR.md)

Native iOS port of [Protopanda Controller](https://github.com/junglivre/ProtopandaController) (Android). Acts as a Bluetooth Low Energy (BLE) peripheral for Protopanda platforms, sending the iPhone's motion data and on-screen button state using the same protocol as the Android app.

## Releases

[Download the latest release](https://github.com/junglivre/ProtopandaController-iOS/releases/latest): an unsigned `.ipa`, ready to sideload with SideStore, AltStore, or iLoader.

## Repository layout

| Path | Purpose |
|---|---|
| `ProtopandaControllerCore/` | Pure Swift Package: BLE identity model, packet encoder, motion scaling math, multitouch hit-testing. Cross-platform, unit-tested on Linux CI. |
| `App/` | iOS app target: SwiftUI UI, Core Bluetooth peripheral controller, Core Motion sensor reading. Generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `App/project.yml`, built with Xcode on macOS. |

## Requirements

- iOS 15 or newer.
- An iPhone whose Bluetooth chipset supports BLE peripheral and advertising mode.
- An accelerometer and gyroscope for motion controls.
- No Mac required for development: see [Building without a Mac](#building-without-a-mac).

## Building without a Mac

There is no local Xcode toolchain in this development environment, so the project is built two ways:

1. **Core logic** (`ProtopandaControllerCore/`): pure Swift, tested with `swift test` on Linux (works locally too, e.g. via the official `swift` Docker image, since it has no Apple-framework dependency).
2. **iOS app** (`App/`): built by a `macos-latest` GitHub Actions runner (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)). The workflow installs [XcodeGen](https://github.com/yonaskolb/XcodeGen), generates the `.xcodeproj` from `App/project.yml`, and runs `xcodebuild` with code signing disabled to produce an unsigned `.app`, packaged as the `ProtopandaController-unsigned-ipa` artifact.

Pushing a semantic-version tag (e.g. `git tag 1.1.0 && git push origin 1.1.0`) runs [`.github/workflows/release.yml`](.github/workflows/release.yml), which creates a [GitHub Release](../../releases) with notes pulled from `CHANGELOG.md` and attaches the raw `.ipa` directly as a release asset (not wrapped in an extra zip). On an iPhone, open the release in Safari and download the `.ipa` straight into SideStore, AltStore, or iLoader — this works from iOS itself, unlike GitHub Actions workflow artifacts, which are always zip-wrapped and awkward to unpack from mobile Safari. SideStore fully re-signs apps with your personal Apple ID certificate, so the IPA does not need to be signed ahead of time.

The simulator is not part of this pipeline: Core Bluetooth peripheral mode, advertising, and real motion sensors only work on a physical device, so acceptance testing always happens through a sideloaded build on an iPhone, against a real Protopanda receiver.

## About and credits

- [GooDDu](https://github.com/GooDDu) — first version of the Android app.
- [mockthebear](https://github.com/mockthebear) — creator of Protopanda.
- [junglivre](https://github.com/junglivre) — iOS port and Android app improvements.
