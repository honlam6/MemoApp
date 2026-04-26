import CoreGraphics

enum HorizontalDragBounds {
    static func clampedOffset(proposed: CGFloat, contentWidth: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        guard contentWidth > viewportWidth else { return 0 }

        let minimumOffset = viewportWidth - contentWidth
        return min(0, max(minimumOffset, proposed))
    }
}
