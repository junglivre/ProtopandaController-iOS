import XCTest
@testable import ProtopandaControllerCore

final class BLEIdentityTests: XCTestCase {

    func testDefaultIdentityMatchesFirmwareUUIDs() {
        XCTAssertEqual(BLEIdentity.default.serviceUUID.uuidString, "D4D31337-C4C1-C2C3-B4B3-B2B1A4A3A2A1")
        XCTAssertEqual(BLEIdentity.default.readWriteUUID.uuidString, "D4D3FAFB-C4C1-C2C3-B4B3-B2B1A4A3A2A1")
        XCTAssertEqual(BLEIdentity.default.notifyUUID.uuidString, "D4D3AFAF-C4C1-C2C3-B4B3-B2B1A4A3A2A1")
    }

    func testDefaultIdentityHasDistinctUUIDs() {
        XCTAssertTrue(BLEIdentity.default.hasDistinctUUIDs)
    }

    func testDuplicateUUIDsAreRejected() {
        let shared = UUID()
        let identity = BLEIdentity(serviceUUID: shared, readWriteUUID: shared, notifyUUID: UUID())
        XCTAssertFalse(identity.hasDistinctUUIDs)
    }

    func testParsingRejectsInvalidOrEmptyText() {
        XCTAssertNil(BLEIdentityParsing.parse("not-a-uuid"))
        XCTAssertNil(BLEIdentityParsing.parse(nil))
        XCTAssertNil(BLEIdentityParsing.parse(""))
        XCTAssertNil(BLEIdentityParsing.parse("   "))
    }

    func testParsingTrimsWhitespaceAndAcceptsValidUuid() {
        let parsed = BLEIdentityParsing.parse("  d4d31337-c4c1-c2c3-b4b3-b2b1a4a3a2a1  ")
        XCTAssertEqual(parsed, BLEIdentity.default.serviceUUID)
    }
}
