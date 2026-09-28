import CoreBluetooth
import Combine
import Foundation
import ProtopandaControllerCore

/// GATT peripheral role implementation: publishes the Protopanda service/characteristics,
/// advertises, accepts a single central, and pushes notify packets.
///
/// Backgrounded via the `bluetooth-peripheral` mode (see `docs/ios-foreground-port.md` §7/§13):
/// the GATT session, advertising, and the central's subscription persist across foreground/
/// background transitions — `ControllerViewModel` no longer starts/stops this controller on
/// `scenePhase` changes, only `startSession()` once at launch and `stopSession()` on explicit
/// quit. This is what keeps the receiver-assigned controller ID stable when the app is
/// backgrounded briefly instead of forcing a full teardown/reconnect on every app switch.
/// Motion sensors and touch input still require the foreground, so `pauseOutgoingNotifications()`/
/// `resumeOutgoingNotificationsIfNeeded()` only stop/start the proactive notify timer (a battery
/// optimization — there's no fresh input to send while backgrounded anyway); they never touch
/// the underlying connection.
///
/// Opts in to Core Bluetooth state preservation and restoration via a restoration identifier,
/// so if iOS kills the process while backgrounded (memory pressure) and later relaunches it to
/// service a Bluetooth event, `peripheralManager(_:willRestoreState:)` recovers the previously
/// published service/characteristic and any already-subscribed central.
///
/// Runs entirely on the main actor. Core Bluetooth requires every peripheral-manager method
/// call to happen on the same queue the manager was created with; passing `queue: nil` means
/// the main queue, so keeping this whole class on the main actor avoids any cross-queue calls.
@MainActor
final class BLEPeripheralController: NSObject, ObservableObject {

    enum Status: Equatable {
        case bluetoothUnavailable(BluetoothUnavailableReason)
        case idle
        case advertising
        case connectedAwaitingID
        case connected(id: Int32)
        case advertisingFailed(AdvertisingFailureReason)
    }

    /// Why Bluetooth isn't usable right now. The view layer maps these to localized text;
    /// this type intentionally carries no language-specific strings.
    enum BluetoothUnavailableReason: Equatable {
        case poweredOff
        case unauthorized
        case unsupported
    }

    /// Why advertising/service-publishing failed. `.systemError` wraps
    /// `error.localizedDescription`, which iOS already localizes for the device's language.
    enum AdvertisingFailureReason: Equatable {
        case serviceRegistrationFailed
        case systemError(String)
    }

    private static let restorationIdentifier = "gay.protopanda.controller.peripheral"

    @Published private(set) var status: Status = .idle

    private var peripheralManager: CBPeripheralManager?
    private var identity: BLEIdentity
    private let inputState: ControllerInputState

    private var notifyCharacteristic: CBMutableCharacteristic?
    private var subscribedCentral: CBCentral?
    private var isServicePublished = false
    private var isSessionActive = false

    /// Whether the proactive notify timer is allowed to run. Set to `false` while backgrounded
    /// to save battery/radio use; the connection and subscription stay untouched either way.
    private var shouldSendNotifications = true

    private var notifyTimer: DispatchSourceTimer?
    private var hasPendingNotify = false

    init(identity: BLEIdentity, inputState: ControllerInputState) {
        self.identity = identity
        self.inputState = inputState
        super.init()
    }

    /// Starts the peripheral session. Safe to call repeatedly. Intended to be called once at
    /// launch and left running for the app's lifetime (see the type-level doc comment).
    func startSession() {
        guard !isSessionActive else { return }
        isSessionActive = true
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(
                delegate: self,
                queue: nil,
                options: [CBPeripheralManagerOptionRestoreIdentifierKey: Self.restorationIdentifier]
            )
        } else if peripheralManager?.state == .poweredOn {
            publishServiceIfNeeded()
        }
    }

    /// Fully stops advertising, tears down the GATT database, and deallocates the peripheral
    /// manager. Only called on explicit user-initiated quit now that the session persists
    /// across backgrounding — this is the real, deliberate end of the BLE session.
    func stopSession() {
        isSessionActive = false
        teardownGATT()
        peripheralManager = nil
        if case .bluetoothUnavailable = status {
            // Keep the "unavailable" banner visible instead of overwriting it with idle.
        } else {
            status = .idle
        }
    }

    /// Stops the proactive notify timer without touching the session, GATT database, or
    /// subscription. Call when the scene leaves `.active`.
    func pauseOutgoingNotifications() {
        shouldSendNotifications = false
        stopNotifyTimer()
    }

    /// Resumes the proactive notify timer if a central is already subscribed and has a valid
    /// controller ID. Call when the scene becomes `.active`.
    func resumeOutgoingNotificationsIfNeeded() {
        shouldSendNotifications = true
        guard isSessionActive, subscribedCentral != nil, inputState.controllerID != -1 else { return }
        startNotifyTimer()
    }

    /// Applies a new identity: tears down the current GATT database and republishes under the
    /// new UUIDs. `CBPeripheralManager` has no API to force-disconnect a central, so the
    /// receiver must reconnect on its own to pick up the new identity (see spec §7).
    func applyNewIdentity(_ identity: BLEIdentity) {
        self.identity = identity
        guard isSessionActive else { return }
        teardownGATT()
        if peripheralManager?.state == .poweredOn {
            publishServiceIfNeeded()
        }
        recomputeStatus()
    }

    private func teardownGATT() {
        stopNotifyTimer()
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        isServicePublished = false
        subscribedCentral = nil
        notifyCharacteristic = nil
        inputState.updateControllerID(-1)
    }

    /// Derives `status` from the current session/subscription/ID state. Centralizing this
    /// avoids status drifting out of sync depending on which delegate callback fires first.
    private func recomputeStatus() {
        guard isSessionActive else { status = .idle; return }
        guard peripheralManager?.state == .poweredOn else { return }
        if subscribedCentral != nil {
            let id = inputState.controllerID
            status = id == -1 ? .connectedAwaitingID : .connected(id: id)
        } else if isServicePublished {
            status = .advertising
        } else {
            status = .idle
        }
    }

    private func publishServiceIfNeeded() {
        guard let peripheralManager, !isServicePublished else { return }

        let readWriteChar = CBMutableCharacteristic(
            type: CBUUID(nsuuid: identity.readWriteUUID),
            properties: [.read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )
        let notifyChar = CBMutableCharacteristic(
            type: CBUUID(nsuuid: identity.notifyUUID),
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
        notifyCharacteristic = notifyChar

        let service = CBMutableService(type: CBUUID(nsuuid: identity.serviceUUID), primary: true)
        service.characteristics = [readWriteChar, notifyChar]
        peripheralManager.add(service)
    }

    private func startAdvertising() {
        guard let peripheralManager, peripheralManager.state == .poweredOn, isSessionActive else { return }
        guard subscribedCentral == nil else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(nsuuid: identity.serviceUUID)]
        ])
    }

    private func startNotifyTimer() {
        guard shouldSendNotifications, notifyTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            self?.sendNotifyIfPossible()
        }
        timer.resume()
        notifyTimer = timer
    }

    private func stopNotifyTimer() {
        notifyTimer?.cancel()
        notifyTimer = nil
        hasPendingNotify = false
    }

    private func sendNotifyIfPossible() {
        guard let peripheralManager, let notifyCharacteristic, let central = subscribedCentral else { return }
        guard inputState.controllerID != -1 else { return }
        let packet = PacketEncoder.encode(inputState.currentSnapshot())
        let sent = peripheralManager.updateValue(packet, for: notifyCharacteristic, onSubscribedCentrals: [central])
        hasPendingNotify = !sent
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEPeripheralController: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if isSessionActive {
                if isServicePublished {
                    recomputeStatus()
                    if subscribedCentral == nil { startAdvertising() }
                } else {
                    status = .idle
                    publishServiceIfNeeded()
                }
            } else {
                status = .idle
            }
        case .poweredOff:
            handleBluetoothUnavailable(.poweredOff)
        case .unauthorized:
            handleBluetoothUnavailable(.unauthorized)
        case .unsupported:
            handleBluetoothUnavailable(.unsupported)
        case .resetting, .unknown:
            break
        @unknown default:
            break
        }
    }

    private func handleBluetoothUnavailable(_ reason: BluetoothUnavailableReason) {
        teardownGATT()
        status = .bluetoothUnavailable(reason)
    }

    /// Recovers state after iOS kills the app process while backgrounded and relaunches it to
    /// service a Bluetooth event. Only the service/characteristic references and the already-
    /// subscribed central (read back from the characteristic's own `subscribedCentrals`) need
    /// restoring; `identity`, `inputState`, and the rest of this controller's own properties
    /// are reconstructed normally by `ControllerViewModel.init()` on the fresh launch.
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        guard let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] else { return }
        for service in services where service.uuid == CBUUID(nsuuid: identity.serviceUUID) {
            isServicePublished = true
            for characteristic in service.characteristics ?? [] {
                guard let mutableCharacteristic = characteristic as? CBMutableCharacteristic,
                      mutableCharacteristic.uuid == CBUUID(nsuuid: identity.notifyUUID) else { continue }
                notifyCharacteristic = mutableCharacteristic
                if let central = mutableCharacteristic.subscribedCentrals?.first {
                    subscribedCentral = central
                    if shouldSendNotifications { startNotifyTimer() }
                }
            }
        }
        recomputeStatus()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            status = .advertisingFailed(.serviceRegistrationFailed)
            return
        }
        isServicePublished = true
        startAdvertising()
        recomputeStatus()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            status = .advertisingFailed(.systemError(error.localizedDescription))
        } else {
            recomputeStatus()
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == CBUUID(nsuuid: identity.notifyUUID) else { return }
        guard subscribedCentral == nil || subscribedCentral == central else { return }
        subscribedCentral = central
        peripheral.stopAdvertising()
        if shouldSendNotifications { startNotifyTimer() }
        recomputeStatus()
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        guard subscribedCentral == central else { return }
        subscribedCentral = nil
        stopNotifyTimer()
        inputState.updateControllerID(-1)
        recomputeStatus()
        startAdvertising()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        switch request.characteristic.uuid {
        case CBUUID(nsuuid: identity.readWriteUUID):
            request.value = PacketEncoder.encodeControllerID(inputState.controllerID)
            peripheral.respond(to: request, withResult: .success)
        case CBUUID(nsuuid: identity.notifyUUID):
            request.value = PacketEncoder.encode(inputState.currentSnapshot())
            peripheral.respond(to: request, withResult: .success)
        default:
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == CBUUID(nsuuid: identity.readWriteUUID),
               let value = request.value,
               let id = PacketEncoder.decodeControllerID(value) {
                inputState.updateControllerID(id)
            }
            // Writes of any length other than 4 bytes are accepted but ignored, matching the
            // Android behavior of always responding success without changing the ID.
            peripheral.respond(to: request, withResult: .success)
        }
        recomputeStatus()
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if hasPendingNotify {
            sendNotifyIfPossible()
        }
    }
}
