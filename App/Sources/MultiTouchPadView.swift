import SwiftUI
import UIKit
import ProtopandaControllerCore

/// Captures every simultaneous finger over the D-pad area and reports the full set of pressed
/// buttons, mirroring `MainActivity.setupMultiTouchButtons` in the Android app: a button stays
/// pressed as long as ANY active touch is over its region, so several buttons can be held
/// together (e.g. a direction plus `L1`).
///
/// Plain SwiftUI gestures only track one touch stream per recognizer, so this uses a
/// `UIViewRepresentable` overlay that reads `UITouch` directly, the same way the Android
/// version reads `MotionEvent` pointers directly instead of per-button click listeners.
struct MultiTouchPadView: UIViewRepresentable {
    let onPressedButtonsChanged: (Set<ButtonIndex>) -> Void

    func makeUIView(context: Context) -> TouchTrackingView {
        let view = TouchTrackingView()
        view.onPressedButtonsChanged = onPressedButtonsChanged
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        return view
    }

    func updateUIView(_ uiView: TouchTrackingView, context: Context) {
        uiView.onPressedButtonsChanged = onPressedButtonsChanged
    }
}

/// Plain `UIView` that turns every active touch into fractional coordinates and asks
/// `MultiTouchButtonMapper` which buttons they land on.
final class TouchTrackingView: UIView {
    var onPressedButtonsChanged: ((Set<ButtonIndex>) -> Void)?

    private var activeTouches = Set<UITouch>()

    private var regions: [PressableRegion] {
        DPadLayout.regions.map { button, unitRect in
            PressableRegion(
                button: button,
                minX: unitRect.minX * bounds.width,
                minY: unitRect.minY * bounds.height,
                maxX: unitRect.maxX * bounds.width,
                maxY: unitRect.maxY * bounds.height
            )
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.formUnion(touches)
        reportPressedButtons()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        reportPressedButtons()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        reportPressedButtons()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        reportPressedButtons()
    }

    private func reportPressedButtons() {
        let points = activeTouches.map { touch -> (x: Double, y: Double) in
            let point = touch.location(in: self)
            return (Double(point.x), Double(point.y))
        }
        let pressed = MultiTouchButtonMapper.pressedButtons(regions: regions, touchPoints: points)
        onPressedButtonsChanged?(pressed)
    }
}
