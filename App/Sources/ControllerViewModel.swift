import Combine
import Foundation
import ProtopandaControllerCore

/// Top-level app state: owns the BLE and motion controllers, exposes UI-facing state, and
/// enforces the foreground-only lifecycle described in `docs/ios-foreground-port.md` §7.
@MainActor
final class ControllerViewModel: ObservableObject {

    enum IdentityValidationError: Equatable {
        case invalidServiceUUID
        case invalidReadWriteUUID
        case invalidNotifyUUID
        case duplicateUUIDs
    }

    @Published private(set) var identity: BLEIdentity
    @Published private(set) var pressedButtons: Set<ButtonIndex> = []

    let bleController: BLEPeripheralController
    let motionController: MotionController
    private let inputState = ControllerInputState()

    init() {
        let loadedIdentity = BLEIdentityStore.load()
        self.identity = loadedIdentity
        self.bleController = BLEPeripheralController(identity: loadedIdentity, inputState: inputState)
        self.motionController = MotionController(inputState: inputState)
    }

    /// Called when the scene becomes `.active`.
    func handleSceneActive() {
        motionController.start()
        bleController.startSession()
    }

    /// Called when the scene leaves `.active` (`.inactive` or `.background`).
    func handleSceneInactive() {
        motionController.stop()
        bleController.stopSession()
    }

    /// Fully terminates the app process after a clean BLE/motion teardown. Regular iOS apps
    /// have no public API to ask the system to close them; this is a deliberate, user-requested
    /// "quit" action for this sideload-only build (see docs/ios-foreground-port.md §7).
    func quitApp() {
        handleSceneInactive()
        exit(0)
    }

    /// Updates the set of currently pressed D-pad/face buttons from the touch layer.
    func setPressedButtons(_ buttons: Set<ButtonIndex>) {
        guard buttons != pressedButtons else { return }
        pressedButtons = buttons
        inputState.updateButtons(buttons)
    }

    /// Validates and saves a new identity from the Settings screen, then rebuilds the GATT
    /// session under the new UUIDs. Returns the validation error, or `nil` on success.
    @discardableResult
    func saveIdentity(serviceText: String, readWriteText: String, notifyText: String) -> IdentityValidationError? {
        guard let serviceUUID = BLEIdentityParsing.parse(serviceText) else { return .invalidServiceUUID }
        guard let readWriteUUID = BLEIdentityParsing.parse(readWriteText) else { return .invalidReadWriteUUID }
        guard let notifyUUID = BLEIdentityParsing.parse(notifyText) else { return .invalidNotifyUUID }

        let newIdentity = BLEIdentity(serviceUUID: serviceUUID, readWriteUUID: readWriteUUID, notifyUUID: notifyUUID)
        guard newIdentity.hasDistinctUUIDs else { return .duplicateUUIDs }

        identity = newIdentity
        BLEIdentityStore.save(newIdentity)
        bleController.applyNewIdentity(newIdentity)
        return nil
    }
}
