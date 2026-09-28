import XCTest
@testable import ProtopandaControllerCore

final class MultiTouchButtonMapperTests: XCTestCase {

    private let regions: [PressableRegion] = [
        PressableRegion(button: .left, minX: 0, minY: 0, maxX: 10, maxY: 10),
        PressableRegion(button: .right, minX: 10, minY: 0, maxX: 20, maxY: 10)
    ]

    func testNoTouchesPressNoButtons() {
        XCTAssertTrue(MultiTouchButtonMapper.pressedButtons(regions: regions, touchPoints: []).isEmpty)
    }

    func testSingleTouchPressesOnlyItsButton() {
        let pressed = MultiTouchButtonMapper.pressedButtons(regions: regions, touchPoints: [(x: 5, y: 5)])
        XCTAssertEqual(pressed, [.left])
    }

    func testTwoSimultaneousTouchesPressBothButtons() {
        let pressed = MultiTouchButtonMapper.pressedButtons(
            regions: regions,
            touchPoints: [(x: 5, y: 5), (x: 15, y: 5)]
        )
        XCTAssertEqual(pressed, [.left, .right])
    }

    func testTouchOutsideAnyRegionPressesNothing() {
        let pressed = MultiTouchButtonMapper.pressedButtons(regions: regions, touchPoints: [(x: 50, y: 50)])
        XCTAssertTrue(pressed.isEmpty)
    }

    func testRegionUpperBoundIsExclusiveToItsNeighbor() {
        // x == 10 belongs to the right region (minX inclusive), not to the left one (maxX exclusive).
        let pressed = MultiTouchButtonMapper.pressedButtons(regions: regions, touchPoints: [(x: 10, y: 5)])
        XCTAssertEqual(pressed, [.right])
    }
}
