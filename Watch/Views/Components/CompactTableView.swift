import SwiftUI

struct CompactTableView: View {
    let headers: [String]
    let rows: [[String]]
    let fontSize: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TableRowView(cells: headers, fontSize: fontSize, isHeader: true)

                Rectangle()
                    .fill(.secondary.opacity(0.3))
                    .frame(height: 0.5)

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    TableRowView(cells: row, fontSize: fontSize, isHeader: false)
                    if row != rows.last {
                        Rectangle()
                            .fill(.secondary.opacity(0.15))
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(2)
        .background(.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct TableRowView: View {
    let cells: [String]
    let fontSize: CGFloat
    let isHeader: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                InlineMathTextView(
                    text: cell,
                    textFont: .system(size: fontSize, weight: isHeader ? .semibold : .regular),
                    mathSize: min(max(fontSize, 7), 11),
                    markdownEnabled: true,
                    platform: .watch
                )
                    .frame(minWidth: 30, alignment: .leading)
            }
        }
        .padding(.vertical, 1)
    }
}
