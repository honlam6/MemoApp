import Foundation

/// Markdown 解析器 — 将原始 markdown 文本解析为结构化 block 数组
enum MarkdownParser {
    private static let cache: NSCache<NSString, CachedBlocks> = {
        let cache = NSCache<NSString, CachedBlocks>()
        cache.countLimit = 64
        cache.totalCostLimit = 2 * 1024 * 1024 // 2 MB
        return cache
    }()


    enum Block: Equatable {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case bulletList(items: [String])
        case numberedList(items: [String])
        case table(headers: [String], rows: [[String]])
        case horizontalRule
        case codeBlock(language: String, code: String)
        case mathBlock(formula: String)
    }

    /// 在后台队列解析 markdown，返回时已在调用 actor 上
    static func parseBackground(_ markdown: String) async -> [Block] {
        let key = markdown as NSString
        if let cached = cache.object(forKey: key) {
            return cached.blocks
        }
        return await Task.detached(priority: .userInitiated) {
            parse(markdown)
        }.value
    }

    static func parse(_ markdown: String) -> [Block] {
        let key = markdown as NSString
        if let cached = cache.object(forKey: key) {
            return cached.blocks
        }

        var blocks: [Block] = []
        let lines = markdown.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 空行跳过
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // 水平分割线
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // 标题
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                i += 1
                continue
            }

            // 代码块
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                i += 1
                continue
            }

            // 块级公式：\[...\]
            if trimmed == #"\\["# || trimmed == #"\["# {
                var formulaLines: [String] = []
                i += 1
                while i < lines.count {
                    let current = lines[i].trimmingCharacters(in: .whitespaces)
                    if current == #"\\]"# || current == #"\]"# {
                        break
                    }
                    formulaLines.append(lines[i])
                    i += 1
                }
                blocks.append(.mathBlock(formula: formulaLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                if i < lines.count { i += 1 }
                continue
            }

            // 块级公式：$$...$$
            if let parsedMath = parseDollarMathBlock(lines: lines, startIndex: i) {
                blocks.append(parsedMath.block)
                i = parsedMath.nextIndex
                continue
            }

            // 表格
            if trimmed.contains("|") && trimmed.hasPrefix("|") {
                var tableLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).contains("|") {
                    tableLines.append(lines[i])
                    i += 1
                }
                if let table = parseTable(tableLines) {
                    blocks.append(table)
                }
                continue
            }

            // 无序列表
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var items: [String] = []
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    if lt.hasPrefix("- ") || lt.hasPrefix("* ") || lt.hasPrefix("+ ") {
                        items.append(String(lt.dropFirst(2)))
                        i += 1
                    } else if lt.hasPrefix("  ") && !lt.isEmpty {
                        // 继续上一个列表项（缩进）
                        if !items.isEmpty {
                            items[items.count - 1] += " " + lt
                        }
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.bulletList(items: items))
                continue
            }

            // 普通段落
            var paraLines: [(text: String, hardBreak: Bool)] = [(trimmed, false)]
            i += 1
            while i < lines.count {
                let raw = lines[i]
                let next = raw.trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("- ") || next.hasPrefix("* ") || next.hasPrefix("**") || next.hasPrefix("|") || next.hasPrefix("```") || next == "---" || next.hasPrefix("$$") || next == #"\["# {
                    break
                }
                let hardBreak = raw.hasSuffix("  ")
                paraLines.append((next, hardBreak))
                i += 1
            }
            var paraText = ""
            for (idx, item) in paraLines.enumerated() {
                if idx > 0 {
                    paraText += paraLines[idx - 1].hardBreak ? "  \n" : " "
                }
                paraText += item.text
            }
            blocks.append(.paragraph(text: paraText))
        }

        cache.setObject(CachedBlocks(blocks), forKey: key, cost: markdown.utf8.count)
        return blocks
    }

    // MARK: - Private

    private static func parseHeading(_ line: String) -> Block? {
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        if level > 0 && level <= 6 && line.count > level {
            let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            // 去除 HTML 锚点
            let cleanText = text.replacingOccurrences(of: #"<a id="[^"]*"></a>"#, with: "", options: .regularExpression)
            return .heading(level: level, text: cleanText)
        }
        return nil
    }

    private static func parseDollarMathBlock(lines: [String], startIndex: Int) -> (block: Block, nextIndex: Int)? {
        guard startIndex < lines.count else { return nil }

        let openingLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard openingLine.hasPrefix("$$") else { return nil }

        let firstFormulaLine = String(openingLine.dropFirst(2))
        if let closingRange = firstFormulaLine.range(of: "$$") {
            let formula = String(firstFormulaLine[..<closingRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (.mathBlock(formula: formula), startIndex + 1)
        }

        var formulaLines: [String] = []
        if !firstFormulaLine.isEmpty {
            formulaLines.append(firstFormulaLine)
        }

        var i = startIndex + 1
        while i < lines.count {
            let currentLine = lines[i]
            if let closingRange = currentLine.range(of: "$$") {
                let beforeClosing = String(currentLine[..<closingRange.lowerBound])
                if !beforeClosing.isEmpty {
                    formulaLines.append(beforeClosing)
                }
                let formula = formulaLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (.mathBlock(formula: formula), i + 1)
            }

            formulaLines.append(currentLine)
            i += 1
        }

        return nil
    }

    private static func parseTable(_ lines: [String]) -> Block? {
        guard lines.count >= 2 else { return nil }

        func splitRow(_ line: String) -> [String] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var cells: [String] = []
            var current = ""
            var index = trimmed.startIndex
            var dollarMathDelimiter: String?
            var isParenMath = false
            var isBacktick = false

            while index < trimmed.endIndex {
                if !isBacktick && !isParenMath && starts("$$", in: trimmed, at: index), !isEscaped(in: trimmed, at: index) {
                    if dollarMathDelimiter == "$$" {
                        dollarMathDelimiter = nil
                    } else if dollarMathDelimiter == nil {
                        dollarMathDelimiter = "$$"
                    }
                    current += "$$"
                    index = trimmed.index(index, offsetBy: 2)
                    continue
                }

                let character = trimmed[index]

                if character == "`", dollarMathDelimiter == nil, !isParenMath, !isEscaped(in: trimmed, at: index) {
                    isBacktick.toggle()
                    current.append(character)
                    index = trimmed.index(after: index)
                    continue
                }

                if !isBacktick && !isParenMath && character == "$", !isEscaped(in: trimmed, at: index) {
                    if dollarMathDelimiter == "$" {
                        dollarMathDelimiter = nil
                    } else if dollarMathDelimiter == nil {
                        dollarMathDelimiter = "$"
                    }
                    current.append(character)
                    index = trimmed.index(after: index)
                    continue
                }

                if !isBacktick && dollarMathDelimiter == nil && starts(#"\("#, in: trimmed, at: index), !isEscaped(in: trimmed, at: index) {
                    isParenMath = true
                    current += #"\("#
                    index = trimmed.index(index, offsetBy: 2)
                    continue
                }

                if !isBacktick && dollarMathDelimiter == nil && isParenMath && starts(#"\)"#, in: trimmed, at: index), !isEscaped(in: trimmed, at: index) {
                    isParenMath = false
                    current += #"\)"#
                    index = trimmed.index(index, offsetBy: 2)
                    continue
                }

                if character == "|", dollarMathDelimiter == nil, !isParenMath, !isBacktick, !isEscaped(in: trimmed, at: index) {
                    cells.append(current)
                    current.removeAll(keepingCapacity: true)
                } else {
                    current.append(character)
                }

                index = trimmed.index(after: index)
            }

            cells.append(current)
            // 去掉首尾空元素（因为 | 在两端）
            if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                cells.removeFirst()
            }
            if cells.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                cells.removeLast()
            }
            return cells.map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let headers = splitRow(lines[0])

        // 检查第二行是否为分隔行 (|---|---|)
        let secondLine = lines[1].trimmingCharacters(in: .whitespaces)
        let isSeparator = secondLine.allSatisfy { $0 == "|" || $0 == "-" || $0 == " " || $0 == ":" }

        var dataLines: [String]
        if isSeparator {
            dataLines = Array(lines.dropFirst(2))
        } else {
            dataLines = Array(lines.dropFirst(1))
        }

        let rows = dataLines.map { splitRow($0) }
        return .table(headers: headers, rows: rows)
    }

    private static func starts(_ token: String, in text: String, at index: String.Index) -> Bool {
        guard let end = text.index(index, offsetBy: token.count, limitedBy: text.endIndex) else {
            return false
        }
        return text[index..<end] == token
    }

    private static func isEscaped(in text: String, at index: String.Index) -> Bool {
        guard index > text.startIndex else { return false }
        var slashCount = 0
        var current = text.index(before: index)
        while text[current] == "\\" {
            slashCount += 1
            if current == text.startIndex { break }
            current = text.index(before: current)
        }
        return slashCount % 2 == 1
    }
}

private final class CachedBlocks: NSObject {
    let blocks: [MarkdownParser.Block]

    init(_ blocks: [MarkdownParser.Block]) {
        self.blocks = blocks
    }
}
