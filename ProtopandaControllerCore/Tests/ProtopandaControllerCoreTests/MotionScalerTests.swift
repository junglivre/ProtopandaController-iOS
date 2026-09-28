import XCTest
@testable import ProtopandaControllerCore

final class MotionScalerTests: XCTestCase {

    func testFilteredAccelAppliesExponentialMovingAverage() {
        // alpha=0.8: 0.8*10 + 0.2*0 = 8.0
        XCTAssertEqual(MotionScaler.filteredAccel(previous: 10.0, raw: 0.0), 8.0, accuracy: 1e-9)
    }

    func testAccelToInt16MatchesOneGReference() {
        // 9.81 m/s^2 (1g) lands exactly on ACCEL_SCALE = 32768/4 = 8192
        XCTAssertEqual(MotionScaler.accelToInt16(metersPerSecondSquared: 9.81), 8192)
    }

    func testAccelToInt16SaturatesAtBounds() {
        XCTAssertEqual(MotionScaler.accelToInt16(metersPerSecondSquared: 1000), Int16.max)
        XCTAssertEqual(MotionScaler.accelToInt16(metersPerSecondSquared: -1000), Int16.min)
    }

    func testDegreesPerSecondConvertsRadians() {
        XCTAssertEqual(MotionScaler.degreesPerSecond(radiansPerSecond: .pi), 180.0, accuracy: 1e-9)
    }

    func testGyroToInt16MatchesReferenceRange() {
        // 2000 deg/s * (32768/2000) = 32768.0, saturating down to Int16.max just like
        // Android's `coerceIn(-32768, 32767)` on the truncated Int.
        XCTAssertEqual(MotionScaler.gyroToInt16(degreesPerSecond: 2000), Int16.max)
    }

    func testGyroToInt16SaturatesAtBounds() {
        XCTAssertEqual(MotionScaler.gyroToInt16(degreesPerSecond: 100_000), Int16.max)
        XCTAssertEqual(MotionScaler.gyroToInt16(degreesPerSecond: -100_000), Int16.min)
    }
}
