import Foundation

/// A rectangular hit region for one button, in whatever coordinate space the caller uses
/// (the app passes view-local points; this type intentionally avoids CoreGraphics so it
/// stays testable on any platform).
public struct PressableRegion: Equatable, Sendable {
    public let button: ButtonIndex
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double

    public init(button: ButtonIndex, minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.button = button
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public func contains(x: Double, y: Double) -> Bool {
        x >= minX && x < maxX && y >= minY && y < maxY
    }
}

/// Pure hit-testing for the multitouch D-pad, ported from
/// `MainActivity.setupMultiTouchButtons` in the Android app: a button stays pressed as long as
/// ANY active touch point is over its region, so several buttons can be held down at once.
public enum MultiTouchButtonMapper {
    /// Returns the set of buttons under at least one of the given touch points.
    public static func pressedButtons(
        regions: [PressableRegion],
        touchPoints: [(x: Double, y: Double)]
    ) -> Set<ButtonIndex> {
        var pressed = Set<ButtonIndex>()
        for region in regions where touchPoints.contains(where: { region.contains(x: $0.x, y: $0.y) }) {
            pressed.insert(region.button)
        }
        return pressed
    }
}
