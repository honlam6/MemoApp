import SwiftUI

struct NoteReaderView: View {
    let note: Note
    @State private var blocks: [MarkdownParser.Block] = []
    @State private var fontSize: CGFloat = NoteReaderView.initialFontSize
    @State private var prefetchedBlockCount = 0
    @State private var prefetchTask: Task<Void, Never>?

    private let initialPrefetchCount = 10
    private let prefetchBatchSize = 8
    private let prefetchIntervalNanoseconds: UInt64 = 120_000_000

    private static var availableFontSizes: [CGFloat] {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        if screenWidth < 160 {
            return [8, 9, 10, 11, 12, 13]
        }
        return [7, 8, 9, 10, 11, 12, 13]
    }

    private static var initialFontSize: CGFloat {
        let saved = UserDefaults.standard.double(forKey: "watch_font_size")
        let sizes = availableFontSizes
        if saved == 0 { return 9 }
        if let minimum = sizes.first, saved < minimum { return minimum }
        if sizes.contains(saved) { return saved }
        return 9
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    DeferredWatchBlockView(
                        block: block,
                        fontSize: fontSize,
                        isPrefetched: index < prefetchedBlockCount
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .ignoresSafeArea(edges: .bottom)
        .id(note.id)
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    cycleFontSize()
                } label: {
                    Text("\(Int(fontSize))pt")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            }
        }
        .onAppear {
            refreshBlocks()
        }
        .onChange(of: note.id) { _, _ in
            refreshBlocks()
        }
        .onChange(of: fontSize) { _, _ in
            refreshBlocks()
        }
    }

    private func refreshBlocks() {
        prefetchTask?.cancel()
        Task {
            let parsed = await MarkdownParser.parseBackground(note.content)
            blocks = parsed
            prefetchedBlockCount = min(initialPrefetchCount, blocks.count)
            startPrefetchingRemainingBlocks(expectedCount: blocks.count)
        }
    }

    private func cycleFontSize() {
        let sizes = Self.availableFontSizes
        if let idx = sizes.firstIndex(of: fontSize) {
            fontSize = sizes[(idx + 1) % sizes.count]
        } else {
            fontSize = 9
        }
        UserDefaults.standard.set(fontSize, forKey: "watch_font_size")
    }

    private func startPrefetchingRemainingBlocks(expectedCount: Int) {
        guard prefetchedBlockCount < expectedCount else { return }

        prefetchTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: prefetchIntervalNanoseconds)
                guard !Task.isCancelled else { break }
                let shouldContinue = await MainActor.run { () -> Bool in
                    guard blocks.count == expectedCount, prefetchedBlockCount < expectedCount else {
                        return false
                    }
                    prefetchedBlockCount = min(prefetchedBlockCount + prefetchBatchSize, expectedCount)
                    return prefetchedBlockCount < expectedCount
                }
                if !shouldContinue { break }
            }
        }
    }
}

struct DeferredWatchBlockView: View {
    let block: MarkdownParser.Block
    let fontSize: CGFloat
    let isPrefetched: Bool

    @State private var isVisible = false

    var body: some View {
        switch block {
        case .mathBlock, .table:
            if isVisible || isPrefetched {
                WatchBlockView(block: block, fontSize: fontSize)
            } else {
                expensivePlaceholder
                    .onAppear { isVisible = true }
            }
        default:
            WatchBlockView(block: block, fontSize: fontSize)
        }
    }

    @ViewBuilder
    private var expensivePlaceholder: some View {
        switch block {
        case .mathBlock:
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.1))
                .frame(height: 26)
                .padding(.vertical, 2)
        case .table:
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.08))
                .frame(height: 44)
                .padding(.vertical, 2)
        default:
            EmptyView()
        }
    }
}

struct WatchBlockView: View {
    let block: MarkdownParser.Block
    let fontSize: CGFloat

    var body: some View {
        switch block {
        case .heading(let level, let text):
            InlineMathTextView(
                text: text,
                textFont: .system(size: headingSize(level), weight: .bold),
                mathSize: headingSize(level),
                markdownEnabled: true,
                platform: .watch
            )
                .padding(.top, level <= 2 ? 5 : 2)

        case .paragraph(let text):
            InlineMathTextView(
                text: text,
                textFont: .system(size: fontSize),
                mathSize: min(max(fontSize, 7), 12),
                markdownEnabled: true,
                platform: .watch
            )

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 3) {
                        Text("•")
                            .font(.system(size: fontSize))
                            .foregroundStyle(.secondary)
                        InlineMathTextView(
                            text: item,
                            textFont: .system(size: fontSize),
                            mathSize: min(max(fontSize, 7), 12),
                            markdownEnabled: true,
                            platform: .watch
                        )
                    }
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 3) {
                        Text("\(idx + 1).")
                            .font(.system(size: fontSize))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, alignment: .trailing)
                        InlineMathTextView(
                            text: item,
                            textFont: .system(size: fontSize),
                            mathSize: min(max(fontSize, 7), 12),
                            markdownEnabled: true,
                            platform: .watch
                        )
                    }
                }
            }

        case .table(let headers, let rows):
            CompactTableView(headers: headers, rows: rows, fontSize: max(fontSize - 2, 7))

        case .mathBlock(let formula):
            LaTeXBlockView(
                formula: formula,
                fontSize: fontSize,
                platform: .watch
            )
                .padding(.vertical, 2)

        case .horizontalRule:
            Divider()
                .padding(.vertical, 3)

        case .codeBlock(_, let code):
            Text(code)
                .font(.system(size: max(fontSize - 1, 7), design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .padding(3)
                .background(.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return fontSize + 5
        case 2: return fontSize + 3
        case 3: return fontSize + 2
        default: return fontSize + 1
        }
    }
}
