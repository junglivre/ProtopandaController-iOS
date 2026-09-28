import Foundation
import ProtopandaControllerCore

/// Thread-safe holder for the latest sensor, button, and controller-ID values. Motion updates
/// arrive on a CoreMotion queue, button updates arrive on the main thread from SwiftUI/UIKit
/// touch handling, and the BLE controller reads a consistent snapshot from its own delegate
/// callbacks — this class is the single point where all three meet.
final class ControllerInputState: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = ControllerSnapshot()

    func updateAccel(x: Int16, y: Int16, z: Int16) {
        lock.lock(); defer { lock.unlock() }
        snapshot.accX = x
        snapshot.accY = y
        snapshot.accZ = z
    }

    func updateGyro(x: Int16, y: Int16, z: Int16) {
        lock.lock(); defer { lock.unlock() }
        snapshot.gyroX = x
        snapshot.gyroY = y
        snapshot.gyroZ = z
    }

    func updateButtons(_ buttons: Set<ButtonIndex>) {
        lock.lock(); defer { lock.unlock() }
        snapshot.buttonsPressed = buttons
    }

    func updateControllerID(_ id: Int32) {
        lock.lock(); defer { lock.unlock() }
        snapshot.controllerID = id
    }

    var controllerID: Int32 {
        lock.lock(); defer { lock.unlock() }
        return snapshot.controllerID
    }

    func currentSnapshot() -> ControllerSnapshot {
        lock.lock(); defer { lock.unlock() }
        return snapshot
    }
}
