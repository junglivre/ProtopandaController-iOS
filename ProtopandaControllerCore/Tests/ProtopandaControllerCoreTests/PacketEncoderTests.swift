import XCTest
@testable import ProtopandaControllerCore

final class PacketEncoderTests: XCTestCase {

    func testPacketLengthIsTwentyThreeBytes() {
        XCTAssertEqual(PacketEncoder.encode(ControllerSnapshot()).count, PacketEncoder.packetLength)
        XCTAssertEqual(PacketEncoder.packetLength, 23)
    }

    func testFieldOrderAndEndianness() {
        let snapshot = ControllerSnapshot(
            accX: 0x0102, accY: 0x0304, accZ: 0x0506,
            gyroX: 0x0708, gyroY: 0x090A, gyroZ: 0x0B0C,
            controllerID: 7,
            buttonsPressed: [.right, .up, .r1]
        )
        let bytes = [UInt8](PacketEncoder.encode(snapshot))

        // accZ, accX, accY (little-endian Int16 each)
        XCTAssertEqual(Array(bytes[0...1]), [0x06, 0x05])
        XCTAssertEqual(Array(bytes[2...3]), [0x02, 0x01])
        XCTAssertEqual(Array(bytes[4...5]), [0x04, 0x03])
        // gyroZ, gyroX, gyroY
        XCTAssertEqual(Array(bytes[6...7]), [0x0C, 0x0B])
        XCTAssertEqual(Array(bytes[8...9]), [0x08, 0x07])
        XCTAssertEqual(Array(bytes[10...11]), [0x0A, 0x09])
        // temperature placeholder, always zero
        XCTAssertEqual(Array(bytes[12...13]), [0x00, 0x00])
        // controller ID low byte
        XCTAssertEqual(bytes[14], 7)
        // buttons: right(0)=1, down(1)=0, left(2)=0, up(3)=1, ok(4)=0, back(5)=0, l1(6)=0, r1(7)=1
        XCTAssertEqual(Array(bytes[15...22]), [1, 0, 0, 1, 0, 0, 0, 1])
    }

    func testControllerIdEncodesOnlyLowByteIntoPacket() {
        let snapshot = ControllerSnapshot(controllerID: 0x1FF) // 511 -> low byte 0xFF
        let bytes = [UInt8](PacketEncoder.encode(snapshot))
        XCTAssertEqual(bytes[14], 0xFF)
    }

    func testNegativeControllerIdEncodesAsUnsignedByte() {
        let snapshot = ControllerSnapshot(controllerID: -1) // all bits set -> low byte 0xFF
        let bytes = [UInt8](PacketEncoder.encode(snapshot))
        XCTAssertEqual(bytes[14], 0xFF)
    }

    func testNoButtonsPressedEncodesAllZeroBytes() {
        let bytes = [UInt8](PacketEncoder.encode(ControllerSnapshot()))
        XCTAssertEqual(Array(bytes[15...22]), Array(repeating: 0, count: 8))
    }

    func testEncodeControllerIdRoundTripsThroughDecode() {
        let ids: [Int32] = [0, 1, -1, 42, Int32.min, Int32.max]
        for id in ids {
            let encoded = PacketEncoder.encodeControllerID(id)
            XCTAssertEqual(encoded.count, 4)
            XCTAssertEqual(PacketEncoder.decodeControllerID(encoded), id)
        }
    }

    func testDecodeControllerIdRejectsWrongLength() {
        XCTAssertNil(PacketEncoder.decodeControllerID(Data([0, 0, 0])))
        XCTAssertNil(PacketEncoder.decodeControllerID(Data([0, 0, 0, 0, 0])))
        XCTAssertNil(PacketEncoder.decodeControllerID(Data()))
    }
}
