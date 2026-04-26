import SwiftUI

/// 单个 Markdown 文本节点渲染（支持粗体/斜体）
struct MarkdownTextView: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        InlineMathTextView(
            text: text,
            textFont: .system(size: fontSize),
            mathSize: min(max(fontSize, 7), 12),
            markdownEnabled: true,
            platform: .watch
        )
    }
}
