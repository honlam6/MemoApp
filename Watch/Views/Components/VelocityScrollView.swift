import SwiftUI

/// Digital Crown 旋转越快滚动越快的加速滚动容器，同时支持手指滑动。
struct VelocityScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    @State private var crownValue: Double = 0
    @State private var lastCrownValue: Double = 0
    @State private var lastCrownTime: Date = .distantPast
    @State private var smoothedRate: Double = 0
    @State private var lastSign: Double = 0

    @State private var isRecenterBounce = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { outerProxy in
            content
                .background(
                    GeometryReader { innerProxy in
                        Color.clear
                            .onAppear {
                                let h = innerProxy.size.height
                                if h > contentHeight { contentHeight = h }
                            }
                            .onChange(of: innerProxy.size.height) { _, h in
                                if h > contentHeight {
                                    contentHeight = h
                                    clampScrollOffset()
                                }
                            }
                    }
                )
                .offset(y: clampedVisibleOffset)
                .onAppear { viewportHeight = outerProxy.size.height }
                .onChange(of: outerProxy.size.height) { _, h in
                    viewportHeight = h
                    clampScrollOffset()
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in dragOffset = value.translation.height }
                        .onEnded { value in
                            scrollOffset += value.translation.height
                            dragOffset = 0
                            clampScrollOffset()
                        }
                )
        }
        .clipped()
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: 200_000,
            sensitivity: .medium,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            handleCrownChange(newValue)
        }
    }

    // MARK: - 滚动逻辑

    private var clampedVisibleOffset: CGFloat {
        let total = scrollOffset + dragOffset
        let maxO = maxContentOffset
        guard maxO > 0 else { return 0 }
        return max(-maxO, min(0, total))
    }

    private var maxContentOffset: CGFloat {
        max(0, contentHeight - viewportHeight)
    }

    private func clampScrollOffset() {
        let maxO = maxContentOffset
        guard maxO > 0 else { scrollOffset = 0; return }
        scrollOffset = max(-maxO, min(0, scrollOffset))
    }

    private func handleCrownChange(_ newValue: Double) {
        if isRecenterBounce {
            isRecenterBounce = false
            lastCrownValue = newValue
            return
        }

        let now = Date.now
        let dt = now.timeIntervalSince(lastCrownTime)
        let rawDelta = newValue - lastCrownValue

        if dt >= 0.6 {
            smoothedRate = 0
            lastSign = 0
            lastCrownValue = newValue
            lastCrownTime = now
            tryRecenter(newValue)
            return
        }

        if dt > 0, abs(rawDelta) > 0, maxContentOffset > 0 {
            let sign = rawDelta > 0 ? 1.0 : -1.0
            if lastSign != 0, sign != lastSign {
                smoothedRate = 0
            }
            lastSign = sign

            let rate = abs(rawDelta) / dt
            if rate > smoothedRate * 0.3 {
                smoothedRate = smoothedRate * 0.5 + rate * 0.5
            } else {
                smoothedRate *= 0.92
            }

            let multiplier = 10.0 + min(smoothedRate * 0.5, 40.0)
            var d = CGFloat(rawDelta) * CGFloat(multiplier)
            let maxFrame = min(maxContentOffset * 0.25, max(viewportHeight * 0.5, 20))
            d = max(-maxFrame, min(maxFrame, d))

            scrollOffset = max(-maxContentOffset, min(0, scrollOffset - d))
        }

        lastCrownValue = newValue
        lastCrownTime = now
    }

    private func tryRecenter(_ value: Double) {
        let margin = 5_000.0
        guard value >= 200_000 - margin || value <= margin else { return }

        let mid = 100_000.0
        lastCrownValue = mid - (value - lastCrownValue)
        isRecenterBounce = true
        crownValue = mid
    }
}
