import Combine
import Foundation
import ProtopandaControllerCore

/// Top-level app state: owns the BLE and motion controllers, exposes UI-facing state, and
/// coordinates the background-capable lifecycle described in `docs/ios-foreground-port.md`
/// §7/§13: the BLE session starts once at launch and keeps running regardless of
/// foreground/background (so the receiver-assigned controller ID stays stable across app
/// switches); only motion sensors, touch-driven button state, and the outgoing notify timer
/// pause with `scenePhase`, since CoreMotion and touch input both require the foreground.
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
        bleController.startSession()
    }

    /// Called when the scene becomes `.active`. Only resumes motion sensing and the proactive
    /// notify timer — the BLE session itself is already running from launch.
    func handleSceneActive() {
        motionController.start()
        bleController.resumeOutgoingNotificationsIfNeeded()
    }

    /// Called when the scene leaves `.active` (`.inactive` or `.background`). Stops motion
    /// sensing and the proactive notify timer, but deliberately leaves the BLE session,
    /// advertising, and subscription untouched so the connection survives backgrounding.
    func handleSceneInactive() {
        motionController.stop()
        bleController.pauseOutgoingNotifications()
    }

    /// Fully terminates the app process after a clean BLE/motion teardown. Regular iOS apps
    /// have no public API to ask the system to close them; this is a deliberate, user-requested
    /// "quit" action for this sideload-only build (see docs/ios-foreground-port.md §7).
    func quitApp() {
        handleSceneInactive()
        bleController.stopSession()
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
