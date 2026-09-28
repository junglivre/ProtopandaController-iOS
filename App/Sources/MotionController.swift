import Combine
import CoreMotion
import ProtopandaControllerCore

/// Reads raw accelerometer and gyroscope samples and converts them into packet units,
/// matching `MainActivity.onSensorChanged` in the Android app 1:1 (see `MotionScaler`).
///
/// Uses `startAccelerometerUpdates`/`startGyroUpdates` (raw sensor data), not device motion:
/// Android's `TYPE_ACCELEROMETER`/`TYPE_GYROSCOPE` are raw, gravity-inclusive readings, and
/// device motion's gravity-compensated user acceleration would not match that reference.
@MainActor
final class MotionController: ObservableObject {
    @Published private(set) var isAccelerometerAvailable: Bool
    @Published private(set) var isGyroscopeAvailable: Bool
    @Published private(set) var displayAccel: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var displayGyro: (x: Double, y: Double, z: Double) = (0, 0, 0)

    private let motionManager = CMMotionManager()
    private var filteredAccel: (x: Double, y: Double, z: Double) = (0, 0, 0)
    private let updateInterval: TimeInterval = 1.0 / 60.0

    private let inputState: ControllerInputState

    init(inputState: ControllerInputState) {
        self.inputState = inputState
        isAccelerometerAvailable = false
        isGyroscopeAvailable = false
    }

    func start() {
        isAccelerometerAvailable = motionManager.isAccelerometerAvailable
        isGyroscopeAvailable = motionManager.isGyroAvailable

        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = updateInterval
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.handleAccelerometer(data)
            }
        }
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = updateInterval
            motionManager.startGyroUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.handleGyro(data)
            }
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
    }

    private func handleAccelerometer(_ data: CMAccelerometerData) {
        // CMAccelerometerData reports acceleration in g's; Android reports m/s² directly.
        let rawX = data.acceleration.x * MotionScaler.standardGravity
        let rawY = data.acceleration.y * MotionScaler.standardGravity
        let rawZ = data.acceleration.z * MotionScaler.standardGravity

        filteredAccel.x = MotionScaler.filteredAccel(previous: filteredAccel.x, raw: rawX)
        filteredAccel.y = MotionScaler.filteredAccel(previous: filteredAccel.y, raw: rawY)
        filteredAccel.z = MotionScaler.filteredAccel(previous: filteredAccel.z, raw: rawZ)

        inputState.updateAccel(
            x: MotionScaler.accelToInt16(metersPerSecondSquared: filteredAccel.x),
            y: MotionScaler.accelToInt16(metersPerSecondSquared: filteredAccel.y),
            z: MotionScaler.accelToInt16(metersPerSecondSquared: filteredAccel.z)
        )
        displayAccel = filteredAccel
    }

    private func handleGyro(_ data: CMGyroData) {
        let degX = MotionScaler.degreesPerSecond(radiansPerSecond: data.rotationRate.x)
        let degY = MotionScaler.degreesPerSecond(radiansPerSecond: data.rotationRate.y)
        let degZ = MotionScaler.degreesPerSecond(radiansPerSecond: data.rotationRate.z)

        inputState.updateGyro(
            x: MotionScaler.gyroToInt16(degreesPerSecond: degX),
            y: MotionScaler.gyroToInt16(degreesPerSecond: degY),
            z: MotionScaler.gyroToInt16(degreesPerSecond: degZ)
        )
        displayGyro = (degX, degY, degZ)
    }
}
