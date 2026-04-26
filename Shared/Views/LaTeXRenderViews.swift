import SwiftUI
import SwiftUIMath

enum LaTeXDisplayPlatform {
    case iPhone
    case watch
}

struct LaTeXBlockView: View {
    let formula: String
    let fontSize: CGFloat
    let platform: LaTeXDisplayPlatform

    private var prepared: PreparedFormula {
        LaTeXFormulaPreprocessor.prepare(formula)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: platform == .watch ? 2 : 4) {
            if prepared.shouldFallbackToPlainText {
                fallbackFormulaText
            } else if platform == .watch {
                #if os(watchOS)
                WatchCrownMathView(
                    formula: prepared.math,
                    fontSize: resolvedFontSize
                )
                    .padding(.vertical, 1)
                #else
                scrollingMathContent(verticalPadding: 1)
                #endif
            } else {
                scrollingMathContent(verticalPadding: 3)
            }

            if let annotation = prepared.annotation {
                Text(annotation)
                    .font(.system(size: annotationFontSize))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fallbackFormulaText: some View {
        Text(prepared.math)
            .font(.system(size: resolvedFontSize, design: .monospaced))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, platform == .watch ? 1 : 3)
    }

    private func scrollingMathContent(verticalPadding: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Math(prepared.math)
                .mathTypesettingStyle(.display)
                .mathFont(Math.Font(name: .latinModern, size: resolvedFontSize))
                .fixedSize(horizontal: true, vertical: true)
                .padding(.vertical, verticalPadding)
        }
    }

    private var resolvedFontSize: CGFloat {
        switch platform {
        case .iPhone:
            return fontSize
        case .watch:
            return min(max(fontSize + 1, 8), 13)
        }
    }

    private var annotationFontSize: CGFloat {
        switch platform {
        case .iPhone:
            return max(fontSize - 5, 12)
        case .watch:
            return max(fontSize - 1, 7)
        }
    }
}

#if os(watchOS)
private struct WatchCrownMathView: View {
    let formula: String
    let fontSize: CGFloat

    @State private var settledOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private var needsDrag: Bool {
        contentWidth > viewportWidth && viewportWidth > 0
    }

    private var visibleOffset: CGFloat {
        HorizontalDragBounds.clampedOffset(
            proposed: settledOffset + dragOffset,
            contentWidth: contentWidth,
            viewportWidth: viewportWidth
        )
    }

    var body: some View {
        Group {
            if needsDrag {
                Math(formula)
                    .mathTypesettingStyle(.display)
                    .mathFont(Math.Font(name: .latinModern, size: fontSize))
                    .fixedSize(horizontal: true, vertical: true)
                    .background(contentWidthReader)
                    .offset(x: visibleOffset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(viewportWidthReader)
                    .clipped()
                    .gesture(formulaDragGesture)
            } else {
                Math(formula)
                    .mathTypesettingStyle(.display)
                    .mathFont(Math.Font(name: .latinModern, size: fontSize))
                    .fixedSize(horizontal: true, vertical: true)
                    .background(contentWidthReader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(viewportWidthReader)
                    .clipped()
            }
        }
        .onPreferenceChange(MathContentWidthPreferenceKey.self) { width in
            contentWidth = width
            settledOffset = HorizontalDragBounds.clampedOffset(
                proposed: settledOffset,
                contentWidth: width,
                viewportWidth: viewportWidth
            )
        }
        .onPreferenceChange(MathViewportWidthPreferenceKey.self) { width in
            viewportWidth = width
            settledOffset = HorizontalDragBounds.clampedOffset(
                proposed: settledOffset,
                contentWidth: contentWidth,
                viewportWidth: width
            )
        }
    }

    private var formulaDragGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .updating($dragOffset) { value, state, _ in
                if abs(value.translation.width) > abs(value.translation.height) * 2.0
                   || (abs(value.translation.width) > 5 && state != 0) {
                    state = value.translation.width
                }
            }
            .onEnded { value in
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 2.0
                if isHorizontal {
                    settledOffset = HorizontalDragBounds.clampedOffset(
                        proposed: settledOffset + value.translation.width,
                        contentWidth: contentWidth,
                        viewportWidth: viewportWidth
                    )
                }
            }
    }

    private var contentWidthReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: MathContentWidthPreferenceKey.self, value: proxy.size.width)
        }
    }

    private var viewportWidthReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: MathViewportWidthPreferenceKey.self, value: proxy.size.width)
        }
    }
}

private struct MathContentWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MathViewportWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
#endif

struct InlineMathTextView: View {
    let text: String
    let textFont: Font
    let mathSize: CGFloat
    let markdownEnabled: Bool
    let platform: LaTeXDisplayPlatform

    var body: some View {
        InlineFlowLayout(spacing: platform == .watch ? 2 : 4, lineSpacing: platform == .watch ? 1 : 3) {
            ForEach(Array(MarkdownInlineParser.parse(text).enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let value):
                    Text(attributedText(value))
                        .font(textFont)
                        .fixedSize(horizontal: false, vertical: true)
                case .math(let formula):
                    let prepared = LaTeXFormulaPreprocessor.prepareInlineFormula(formula)
                    if prepared.shouldFallbackToPlainText {
                        Text(prepared.math)
                            .font(.system(size: mathSize, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        #if os(watchOS)
                        AdaptiveInlineMathView(formula: prepared.math, mathSize: mathSize)
                        #else
                        Math(prepared.math)
                            .mathTypesettingStyle(.text)
                            .mathFont(Math.Font(name: .latinModern, size: mathSize))
                            .fixedSize(horizontal: true, vertical: true)
                        #endif
                    }
                }
            }
        }
    }

    private func attributedText(_ value: String) -> AttributedString {
        guard markdownEnabled else { return AttributedString(value) }
        do {
            return try AttributedString(markdown: value)
        } catch {
            return AttributedString(value)
        }
    }
}

#if os(watchOS)
struct AdaptiveInlineMathView: View {
    let formula: String
    let mathSize: CGFloat

    @State private var intrinsicSize: CGSize = .zero

    private var maxWidth: CGFloat {
        WKInterfaceDevice.current().screenBounds.width - 8
    }

    var body: some View {
        Math(LaTeXFormulaPreprocessor.prepareInlineFormula(formula).math)
            .mathTypesettingStyle(.text)
            .mathFont(Math.Font(name: .latinModern, size: mathSize))
            .fixedSize()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: MathIntrinsicSizeKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(MathIntrinsicSizeKey.self) { size in
                intrinsicSize = size
            }
            .scaleEffect(scaleFactor, anchor: .leading)
            .frame(width: layoutWidth, height: layoutHeight, alignment: .leading)
            .clipped()
    }

    private var scaleFactor: CGFloat {
        guard intrinsicSize.width > 0, intrinsicSize.width > maxWidth else { return 1 }
        return max(0.5, maxWidth / intrinsicSize.width)
    }

    private var layoutWidth: CGFloat? {
        guard intrinsicSize.width > 0 else { return nil }
        return intrinsicSize.width > maxWidth ? maxWidth : intrinsicSize.width
    }

    private var layoutHeight: CGFloat? {
        guard intrinsicSize.width > 0 else { return nil }
        return intrinsicSize.height * scaleFactor
    }
}

private struct MathIntrinsicSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
#endif

private struct PreparedFormula {
    let math: String
    let annotation: String?
    let shouldFallbackToPlainText: Bool
}

private final class CachedPreparedFormula: NSObject {
    let value: PreparedFormula

    init(_ value: PreparedFormula) {
        self.value = value
    }
}

private enum LaTeXFormulaPreprocessor {
    private static let blockCache: NSCache<NSString, CachedPreparedFormula> = {
        let cache = NSCache<NSString, CachedPreparedFormula>()
        cache.countLimit = 256
        return cache
    }()

    private static let inlineCache: NSCache<NSString, CachedPreparedFormula> = {
        let cache = NSCache<NSString, CachedPreparedFormula>()
        cache.countLimit = 512
        return cache
    }()

    static func prepare(_ formula: String) -> PreparedFormula {
        let key = formula as NSString
        if let cached = blockCache.object(forKey: key) {
            return cached.value
        }

        let trimmed = sanitizeFormula(formula)
        let shouldFallback = shouldFallbackToPlainText(trimmed)
        let prepared: PreparedFormula
        if let split = splitTrailingTextAnnotation(trimmed) {
            prepared = PreparedFormula(math: split.math, annotation: split.annotation, shouldFallbackToPlainText: shouldFallback)
        } else {
            prepared = PreparedFormula(math: normalizeUnicodeSubscripts(trimmed), annotation: nil, shouldFallbackToPlainText: shouldFallback)
        }
        blockCache.setObject(CachedPreparedFormula(prepared), forKey: key)
        return prepared
    }

    static func prepareInlineFormula(_ formula: String) -> PreparedFormula {
        let key = formula as NSString
        if let cached = inlineCache.object(forKey: key) {
            return cached.value
        }

        let sanitized = normalizeUnicodeSubscripts(sanitizeFormula(formula))
        let prepared = PreparedFormula(math: sanitized, annotation: nil, shouldFallbackToPlainText: shouldFallbackToPlainText(sanitized))
        inlineCache.setObject(CachedPreparedFormula(prepared), forKey: key)
        return prepared
    }

    private static func splitTrailingTextAnnotation(_ formula: String) -> (math: String, annotation: String)? {
        guard formula.hasSuffix("}") else { return nil }
        guard let textStart = formula.range(of: #"\\text\{"#, options: [.regularExpression, .backwards]) else { return nil }

        let annotationStart = textStart.upperBound
        guard let annotationEnd = matchingBraceEnd(in: formula, contentStart: annotationStart) else { return nil }
        let suffix = formula[annotationEnd...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard suffix.isEmpty else { return nil }

        let prefix = formula[..<textStart.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        guard prefix.hasSuffix(#"\quad"#) || prefix.hasSuffix(#"\;"#) || prefix.hasSuffix(#"\,"#) else { return nil }

        let cleanedPrefix = prefix
            .replacingOccurrences(of: #"\quad"#, with: "")
            .replacingOccurrences(of: #"\;"#, with: "")
            .replacingOccurrences(of: #"\,"#, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let annotation = String(formula[annotationStart..<formula.index(before: annotationEnd)])
        return (normalizeUnicodeSubscripts(cleanedPrefix), annotation)
    }

    private static func matchingBraceEnd(in formula: String, contentStart: String.Index) -> String.Index? {
        var depth = 1
        var index = contentStart
        while index < formula.endIndex {
            if formula[index] == "{" {
                depth += 1
            } else if formula[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return formula.index(after: index)
                }
            }
            index = formula.index(after: index)
        }
        return nil
    }

    private static func sanitizeFormula(_ formula: String) -> String {
        var cleaned = formula.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: #"(?<!\\)\n+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"([,;:])\s*([+\-])"#, with: #"$1 {}$2"#, options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s+([+\-=*/<>])"#, with: #"$1"#, options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"([({\[,;:])\s+"#, with: #"$1"#, options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s+([)}\],;:])"#, with: #"$1"#, options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return cleaned
    }

    private static func normalizeUnicodeSubscripts(_ formula: String) -> String {
        formula.replacingOccurrences(
            of: #"_\{([^{}\x00-\x7F]+)\}"#,
            with: #"_{\text{$1}}"#,
            options: .regularExpression
        )
    }

    private static func shouldFallbackToPlainText(_ formula: String) -> Bool {
        formula.range(of: #"[,;:]\s*\\quad\s*[+\-]"#, options: .regularExpression) != nil ||
        formula.range(of: #"[,;:]\s*[+\-](?:\\infty|[A-Za-z\\])"#, options: .regularExpression) != nil ||
        formula.range(of: #"[,;:]\{\}[+\-]"#, options: .regularExpression) != nil
    }
}

private struct InlineFlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let itemY = y + (row.height - item.size.height) / 2
                let clampedX = min(x, bounds.maxX - item.size.width)
                let clampedY = min(itemY, bounds.maxY - item.size.height)
                let placementX = max(bounds.minX, clampedX)
                let placementY = max(bounds.minY, clampedY)

                let widthProposal = item.isFlexible ? item.proposedWidth : item.proposedWidth
                let heightProposal: CGFloat? = item.isFlexible ? nil : item.size.height
                subviews[item.index].place(
                    at: CGPoint(x: placementX, y: placementY),
                    proposal: ProposedViewSize(width: widthProposal, height: heightProposal)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let intrinsicSize = subviews[index].sizeThatFits(.unspecified)
            let constrainedSize = subviews[index].sizeThatFits(
                ProposedViewSize(width: maxWidth, height: nil)
            )
            let isFlexible = constrainedSize.height > intrinsicSize.height + 1

            if isFlexible {
                arrangeFlexible(
                    index: index, subviews: subviews,
                    intrinsicSize: intrinsicSize, constrainedSize: constrainedSize,
                    maxWidth: maxWidth, current: &current, rows: &rows
                )
            } else {
                arrangeRigid(
                    index: index, intrinsicSize: intrinsicSize,
                    maxWidth: maxWidth, current: &current, rows: &rows
                )
            }
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private func arrangeFlexible(
        index: Int,
        subviews: Subviews,
        intrinsicSize: CGSize,
        constrainedSize: CGSize,
        maxWidth: CGFloat,
        current: inout Row,
        rows: inout [Row]
    ) {
        if current.items.isEmpty {
            let measureWidth = intrinsicSize.width <= maxWidth ? intrinsicSize.width : maxWidth
            let measured = intrinsicSize.width <= maxWidth
                ? intrinsicSize
                : subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            current.append(
                Item(index: index, size: measured, proposedWidth: measureWidth, isFlexible: true),
                spacing: spacing
            )
        } else {
            let remainingWidth = maxWidth - current.width - spacing
            if remainingWidth >= 20 {
                let constrained = subviews[index].sizeThatFits(
                    ProposedViewSize(width: remainingWidth, height: nil)
                )
                if constrained.width <= remainingWidth {
                    current.append(
                        Item(index: index, size: constrained, proposedWidth: remainingWidth, isFlexible: true),
                        spacing: spacing
                    )
                } else {
                    rows.append(current)
                    current = Row()
                    let measured = subviews[index].sizeThatFits(
                        ProposedViewSize(width: maxWidth, height: nil)
                    )
                    current.append(
                        Item(index: index, size: measured, proposedWidth: maxWidth, isFlexible: true),
                        spacing: spacing
                    )
                }
            } else {
                rows.append(current)
                current = Row()
                let measured = subviews[index].sizeThatFits(
                    ProposedViewSize(width: maxWidth, height: nil)
                )
                current.append(
                    Item(index: index, size: measured, proposedWidth: maxWidth, isFlexible: true),
                    spacing: spacing
                )
            }
        }
    }

    private func arrangeRigid(
        index: Int,
        intrinsicSize: CGSize,
        maxWidth: CGFloat,
        current: inout Row,
        rows: inout [Row]
    ) {
        if current.items.isEmpty {
            let proposedWidth = min(intrinsicSize.width, maxWidth)
            current.append(
                Item(index: index, size: intrinsicSize, proposedWidth: proposedWidth, isFlexible: false),
                spacing: spacing
            )
        } else {
            let nextWidth = current.width + spacing + intrinsicSize.width
            if nextWidth <= maxWidth {
                current.append(
                    Item(index: index, size: intrinsicSize, proposedWidth: intrinsicSize.width, isFlexible: false),
                    spacing: spacing
                )
            } else {
                rows.append(current)
                current = Row()
                let proposedWidth = min(intrinsicSize.width, maxWidth)
                current.append(
                    Item(index: index, size: intrinsicSize, proposedWidth: proposedWidth, isFlexible: false),
                    spacing: spacing
                )
            }
        }
    }

    private struct Item {
        let index: Int
        let size: CGSize
        let proposedWidth: CGFloat
        let isFlexible: Bool
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(_ item: Item, spacing: CGFloat) {
            width += items.isEmpty ? item.size.width : spacing + item.size.width
            height = max(height, item.size.height)
            items.append(item)
        }
    }
}
