import Foundation

@main
struct HorizontalDragBoundsTests {
    static func main() {
        assertEqual(
            Double(HorizontalDragBounds.clampedOffset(proposed: -80, contentWidth: 300, viewportWidth: 180)),
            -80,
            "Keeps offsets inside the scrollable range"
        )

        assertEqual(
            Double(HorizontalDragBounds.clampedOffset(proposed: -180, contentWidth: 300, viewportWidth: 180)),
            -120,
            "Clamps offsets at the left edge"
        )

        assertEqual(
            Double(HorizontalDragBounds.clampedOffset(proposed: 40, contentWidth: 300, viewportWidth: 180)),
            0,
            "Clamps offsets at the right edge"
        )

        assertEqual(
            Double(HorizontalDragBounds.clampedOffset(proposed: -40, contentWidth: 120, viewportWidth: 180)),
            0,
            "Does not scroll when the content fits"
        )

        print("HorizontalDragBoundsTests passed")
    }

    private static func assertEqual(_ actual: Double, _ expected: Double, _ message: String) {
        guard abs(actual - expected) < 0.0001 else {
            fatalError("\(message): expected \(expected), got \(actual)")
        }
    }
}
