import CoreBluetooth
import Combine
import Foundation
import ProtopandaControllerCore

/// GATT peripheral role implementation: publishes the Protopanda service/characteristics,
/// advertises, accepts a single central, and pushes notify packets while foregrounded.
///
/// Foreground-only by design (see `docs/ios-foreground-port.md` §7): the app does not declare
/// `bluetooth-peripheral` in `UIBackgroundModes`, so this controller is started/stopped
/// explicitly by `ControllerViewModel` on scene-phase transitions rather than relying on
/// Core Bluetooth's background wake-up or state restoration.
///
/// Runs entirely on the main actor. Core Bluetooth requires every peripheral-manager method
/// call to happen on the same queue the manager was created with; passing `queue: nil` means
/// the main queue, so keeping this whole class on the main actor avoids any cross-queue calls.
@MainActor
final class BLEPeripheralController: NSObject, ObservableObject {

    enum Status: Equatable {
        case bluetoothUnavailable(String)
        case idle
        case advertising
        case connectedAwaitingID
        case connected(id: Int32)
        case advertisingFailed(String)
    }

    @Published private(set) var status: Status = .idle

    private var peripheralManager: CBPeripheralManager?
    private var identity: BLEIdentity
    private let inputState: ControllerInputState

    private var notifyCharacteristic: CBMutableCharacteristic?
    private var subscribedCentral: CBCentral?
    private var isServicePublished = false
    private var isSessionActive = false

    private var notifyTimer: DispatchSourceTimer?
    private var hasPendingNotify = false

    init(identity: BLEIdentity, inputState: ControllerInputState) {
        self.identity = identity
        self.inputState = inputState
        super.init()
    }

    /// Starts (or resumes) the peripheral session. Safe to call repeatedly.
    func startSession() {
        guard !isSessionActive else { return }
        isSessionActive = true
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        } else if peripheralManager?.state == .poweredOn {
            publishServiceIfNeeded()
        }
    }

    /// Stops advertising, tears down the GATT database, and clears session state. Called
    /// whenever the scene leaves `.active`, or when the user stops the controller.
    func stopSession() {
        isSessionActive = false
        teardownGATT()
        if case .bluetoothUnavailable = status {
            // Keep the "unavailable" banner visible instead of overwriting it with idle.
        } else {
            status = .idle
        }
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
        guard notifyTimer == nil else { return }
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
            handleBluetoothUnavailable("Bluetooth está desligado")
        case .unauthorized:
            handleBluetoothUnavailable("Permissão de Bluetooth negada")
        case .unsupported:
            handleBluetoothUnavailable("Este iPhone não suporta periférico BLE")
        case .resetting, .unknown:
            break
        @unknown default:
            break
        }
    }

    private func handleBluetoothUnavailable(_ message: String) {
        teardownGATT()
        status = .bluetoothUnavailable(message)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            status = .advertisingFailed("Falha ao publicar serviço GATT")
            return
        }
        isServicePublished = true
        startAdvertising()
        recomputeStatus()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            status = .advertisingFailed(error.localizedDescription)
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
        startNotifyTimer()
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
