import Foundation
import ProtopandaControllerCore

/// Persists the BLE identity in `UserDefaults`, mirroring Android's `BleIdentity.load`/`save`.
enum BLEIdentityStore {
    private static let suiteName = "ble_identity"
    private static let serviceKey = "service_uuid"
    private static let readWriteKey = "read_write_uuid"
    private static let notifyKey = "notify_uuid"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func load() -> BLEIdentity {
        let store = defaults
        let serviceUUID = BLEIdentityParsing.parse(store.string(forKey: serviceKey))
            ?? BLEIdentity.default.serviceUUID
        let readWriteUUID = BLEIdentityParsing.parse(store.string(forKey: readWriteKey))
            ?? BLEIdentity.default.readWriteUUID
        let notifyUUID = BLEIdentityParsing.parse(store.string(forKey: notifyKey))
            ?? BLEIdentity.default.notifyUUID
        return BLEIdentity(serviceUUID: serviceUUID, readWriteUUID: readWriteUUID, notifyUUID: notifyUUID)
    }

    static func save(_ identity: BLEIdentity) {
        let store = defaults
        store.set(identity.serviceUUID.uuidString, forKey: serviceKey)
        store.set(identity.readWriteUUID.uuidString, forKey: readWriteKey)
        store.set(identity.notifyUUID.uuidString, forKey: notifyKey)
    }
}
