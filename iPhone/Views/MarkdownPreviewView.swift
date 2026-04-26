import SwiftUI

/// iPhone 端 Markdown 预览渲染器
struct MarkdownPreviewView: View {
    let content: String
    @State private var blocks: [MarkdownParser.Block] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    iPhoneBlockView(block: block)
                }
            }
            .padding()
        }
        .onAppear {
            blocks = MarkdownParser.parse(content)
        }
        .onChange(of: content) { _, newValue in
            blocks = MarkdownParser.parse(newValue)
        }
    }
}

struct iPhoneBlockView: View {
    let block: MarkdownParser.Block

    var body: some View {
        switch block {
        case .heading(let level, let text):
            InlineMathTextView(
                text: text,
                textFont: .system(size: headingSize(level), weight: .bold),
                mathSize: headingSize(level),
                markdownEnabled: true,
                platform: .iPhone
            )
                .padding(.top, level <= 2 ? 8 : 4)

        case .paragraph(let text):
            InlineMathTextView(
                text: text,
                textFont: .body,
                mathSize: 17,
                markdownEnabled: true,
                platform: .iPhone
            )

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        InlineMathTextView(
                            text: item,
                            textFont: .body,
                            mathSize: 17,
                            markdownEnabled: true,
                            platform: .iPhone
                        )
                    }
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        InlineMathTextView(
                            text: item,
                            textFont: .body,
                            mathSize: 17,
                            markdownEnabled: true,
                            platform: .iPhone
                        )
                    }
                }
            }

        case .table(let headers, let rows):
            iPhoneTableView(headers: headers, rows: rows)

        case .mathBlock(let formula):
            LaTeXBlockView(formula: formula, fontSize: 22, platform: .iPhone)
                .padding(.vertical, 4)

        case .horizontalRule:
            Divider()
                .padding(.vertical, 6)

        case .codeBlock(_, let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 28
        case 2: return 24
        case 3: return 20
        case 4: return 18
        default: return 16
        }
    }

}

/// iPhone 端表格
struct iPhoneTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 表头
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                        InlineMathTextView(
                            text: h,
                            textFont: .caption.bold(),
                            mathSize: 12,
                            markdownEnabled: true,
                            platform: .iPhone
                        )
                            .frame(minWidth: 80, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                }
                .background(.blue.opacity(0.1))

                Divider()

                // 数据行
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            InlineMathTextView(
                                text: cell,
                                textFont: .caption,
                                mathSize: 12,
                                markdownEnabled: true,
                                platform: .iPhone
                            )
                                .frame(minWidth: 80, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                    }
                    Divider()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.gray.opacity(0.3), lineWidth: 0.5))
    }
}
