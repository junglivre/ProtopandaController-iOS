import CoreGraphics
import ProtopandaControllerCore

/// Fractional (0...1) layout of the D-pad/face buttons within their container, mirroring the
/// arrangement from Android's `activity_main.xml`: UP above OK, LEFT/RIGHT flanking OK, DOWN
/// below OK, BACK below DOWN, and L1/R1 flanking BACK at the same vertical band. The exact
/// percentages are a cosmetic choice for iOS, not part of the wire protocol.
enum DPadLayout {
    static let regions: [(button: ButtonIndex, rect: CGRect)] = [
        (.up,    CGRect(x: 0.35, y: 0.06, width: 0.30, height: 0.16)),
        (.left,  CGRect(x: 0.06, y: 0.24, width: 0.28, height: 0.16)),
        (.ok,    CGRect(x: 0.35, y: 0.24, width: 0.30, height: 0.16)),
        (.right, CGRect(x: 0.66, y: 0.24, width: 0.28, height: 0.16)),
        (.down,  CGRect(x: 0.35, y: 0.42, width: 0.30, height: 0.16)),
        (.l1,    CGRect(x: 0.02, y: 0.62, width: 0.28, height: 0.16)),
        (.back,  CGRect(x: 0.35, y: 0.62, width: 0.30, height: 0.16)),
        (.r1,    CGRect(x: 0.70, y: 0.62, width: 0.28, height: 0.16))
    ]

    static func labelText(for button: ButtonIndex) -> String {
        switch button {
        case .up: return "▲"
        case .down: return "▼"
        case .left: return "◀"
        case .right: return "▶"
        case .ok: return "OK"
        case .back: return "BACK"
        case .l1: return "L1"
        case .r1: return "R1"
        }
    }
}
