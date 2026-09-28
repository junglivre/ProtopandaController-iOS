import Foundation

/// BLE GATT identity: the three UUIDs that make up the Protopanda protocol contract.
/// Mirrors `gay.protopanda.controller.BleIdentity` from the Android app.
public struct BLEIdentity: Equatable, Sendable {
    public var serviceUUID: UUID
    public var readWriteUUID: UUID
    public var notifyUUID: UUID

    public init(serviceUUID: UUID, readWriteUUID: UUID, notifyUUID: UUID) {
        self.serviceUUID = serviceUUID
        self.readWriteUUID = readWriteUUID
        self.notifyUUID = notifyUUID
    }

    /// CCCD (Client Characteristic Configuration Descriptor) UUID, fixed by the Bluetooth SIG.
    public static let cccdUUID = UUID(uuidString: "00002902-0000-1000-8000-00805F9B34FB")!

    /// Default identity matching the Protopanda receiver firmware.
    public static let `default` = BLEIdentity(
        serviceUUID: UUID(uuidString: "D4D31337-C4C1-C2C3-B4B3-B2B1A4A3A2A1")!,
        readWriteUUID: UUID(uuidString: "D4D3FAFB-C4C1-C2C3-B4B3-B2B1A4A3A2A1")!,
        notifyUUID: UUID(uuidString: "D4D3AFAF-C4C1-C2C3-B4B3-B2B1A4A3A2A1")!
    )

    /// The protocol requires all three UUIDs to be distinct from each other.
    public var hasDistinctUUIDs: Bool {
        Set([serviceUUID, readWriteUUID, notifyUUID]).count == 3
    }
}

/// Parsing helpers shared by the Settings screen, mirroring
/// `SettingsActivity.parseUuid` from the Android app.
public enum BLEIdentityParsing {
    /// Parses a UUID from user-entered text, trimming surrounding whitespace.
    /// Returns `nil` for empty or malformed input instead of throwing.
    public static func parse(_ text: String?) -> UUID? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return UUID(uuidString: trimmed)
    }
}
