import Foundation

/// Index of each D-pad / face button inside the BLE packet's button byte-block.
/// Mirrors the Android `MainActivity.setupButtons()` mapping exactly: right=0, down=1,
/// left=2, up=3, ok=4, back=5, l1=6, r1=7.
public enum ButtonIndex: Int, CaseIterable, Sendable {
    case right = 0
    case down  = 1
    case left  = 2
    case up    = 3
    case ok    = 4
    case back  = 5
    case l1    = 6
    case r1    = 7
}

/// One point-in-time snapshot of everything the BLE notify packet encodes.
public struct ControllerSnapshot: Equatable, Sendable {
    public var accX: Int16
    public var accY: Int16
    public var accZ: Int16
    public var gyroX: Int16
    public var gyroY: Int16
    public var gyroZ: Int16
    public var controllerID: Int32
    public var buttonsPressed: Set<ButtonIndex>

    public init(
        accX: Int16 = 0, accY: Int16 = 0, accZ: Int16 = 0,
        gyroX: Int16 = 0, gyroY: Int16 = 0, gyroZ: Int16 = 0,
        controllerID: Int32 = -1,
        buttonsPressed: Set<ButtonIndex> = []
    ) {
        self.accX = accX
        self.accY = accY
        self.accZ = accZ
        self.gyroX = gyroX
        self.gyroY = gyroY
        self.gyroZ = gyroZ
        self.controllerID = controllerID
        self.buttonsPressed = buttonsPressed
    }
}

/// Encodes/decodes the 23-byte little-endian packet shared with the Android app and the
/// Protopanda receiver firmware. See `docs/ios-foreground-port.md` §5 for the byte layout.
public enum PacketEncoder {
    /// Total packet length in bytes. Never change without a matching firmware update.
    public static let packetLength = 23

    /// Encodes a snapshot into the 23-byte notify/read payload:
    /// accZ, accX, accY, gyroZ, gyroX, gyroY, temperature(0), controllerID low byte,
    /// then one byte per `ButtonIndex` in ascending order.
    public static func encode(_ snapshot: ControllerSnapshot) -> Data {
        var data = Data(capacity: packetLength)
        appendInt16LE(snapshot.accZ, to: &data)
        appendInt16LE(snapshot.accX, to: &data)
        appendInt16LE(snapshot.accY, to: &data)
        appendInt16LE(snapshot.gyroZ, to: &data)
        appendInt16LE(snapshot.gyroX, to: &data)
        appendInt16LE(snapshot.gyroY, to: &data)
        appendInt16LE(0, to: &data) // temperature placeholder, always zero
        data.append(UInt8(truncatingIfNeeded: snapshot.controllerID))
        for button in ButtonIndex.allCases {
            data.append(snapshot.buttonsPressed.contains(button) ? 1 : 0)
        }
        return data
    }

    /// Encodes the controller ID as a little-endian `Int32`, matching what the read/write
    /// characteristic returns on a read request.
    public static func encodeControllerID(_ id: Int32) -> Data {
        var data = Data(capacity: 4)
        appendInt32LE(id, to: &data)
        return data
    }

    /// Decodes a controller-ID write payload. Returns `nil` unless the payload is exactly
    /// 4 bytes; the caller should still acknowledge the write, matching the Android behavior
    /// of accepting (but ignoring) writes of any other length.
    public static func decodeControllerID(_ data: Data) -> Int32? {
        guard data.count == 4 else { return nil }
        let bytes = [UInt8](data)
        let unsigned = UInt32(bytes[0])
            | UInt32(bytes[1]) << 8
            | UInt32(bytes[2]) << 16
            | UInt32(bytes[3]) << 24
        return Int32(bitPattern: unsigned)
    }

    private static func appendInt16LE(_ value: Int16, to data: inout Data) {
        let unsigned = UInt16(bitPattern: value)
        data.append(UInt8(truncatingIfNeeded: unsigned))
        data.append(UInt8(truncatingIfNeeded: unsigned >> 8))
    }

    private static func appendInt32LE(_ value: Int32, to data: inout Data) {
        let unsigned = UInt32(bitPattern: value)
        data.append(UInt8(truncatingIfNeeded: unsigned))
        data.append(UInt8(truncatingIfNeeded: unsigned >> 8))
        data.append(UInt8(truncatingIfNeeded: unsigned >> 16))
        data.append(UInt8(truncatingIfNeeded: unsigned >> 24))
    }
}
