# Changelog

All notable changes to this project are documented in this file.

## [0.1.0] - 2026-09-28

### Added

- Initial public release of Protopanda Controller for iOS.
- `ProtopandaControllerCore` Swift package: BLE identity model, packet
  encoder, motion scaling math, and multitouch hit-testing, unit-tested on
  Linux.
- SwiftUI app: status bar, multitouch D-pad, IMU readout, Settings screen,
  Core Bluetooth peripheral controller, Core Motion sensor reading.
- Background BLE session (`bluetooth-peripheral`): the app keeps its GATT
  session and controller ID across app switches instead of tearing down on
  backgrounding.
- English and Portuguese (Brazil) localization, a hard "quit app" action,
  and GitHub Release publishing of an unsigned IPA for sideloading.
