import Foundation

/// Pure motion-to-packet scaling math, ported 1:1 from `MainActivity.onSensorChanged` in the
/// Android app so both clients agree on IMU units with the Protopanda receiver firmware.
public enum MotionScaler {
    /// Low-pass filter weight applied to raw accelerometer samples (Android: `alpha = 0.8f`).
    public static let accelFilterAlpha: Double = 0.8

    /// Scales m/s² onto the firmware's configured accelerometer range (±4 g across an Int16).
    public static let accelScale: Double = 32768.0 / 4.0

    /// Scales °/s onto the firmware's configured gyroscope range (±2000 °/s across an Int16).
    public static let gyroScale: Double = 32768.0 / 2000.0

    /// Standard gravity used to convert between g and m/s², matching Android's `/ 9.81f`.
    public static let standardGravity: Double = 9.81

    /// One step of the exponential moving-average filter: `alpha*previous + (1-alpha)*raw`.
    public static func filteredAccel(previous: Double, raw: Double) -> Double {
        accelFilterAlpha * previous + (1 - accelFilterAlpha) * raw
    }

    /// Converts a filtered acceleration sample (m/s²) into the packet's Int16 units.
    public static func accelToInt16(metersPerSecondSquared value: Double) -> Int16 {
        clampToInt16(value / standardGravity * accelScale)
    }

    /// Converts a raw gyroscope sample (rad/s) into degrees per second, matching
    /// Android's `Math.toDegrees`.
    public static func degreesPerSecond(radiansPerSecond value: Double) -> Double {
        value * 180.0 / Double.pi
    }

    /// Converts a gyroscope sample already in °/s into the packet's Int16 units.
    public static func gyroToInt16(degreesPerSecond value: Double) -> Int16 {
        clampToInt16(value * gyroScale)
    }

    /// Clamps to the Int16 range and truncates toward zero, matching Kotlin's
    /// `Float.toInt().coerceIn(-32768, 32767)`.
    private static func clampToInt16(_ value: Double) -> Int16 {
        let clamped = min(max(value, Double(Int16.min)), Double(Int16.max))
        return Int16(clamped.rounded(.towardZero))
    }
}
