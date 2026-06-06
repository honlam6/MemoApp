import Foundation

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var lastModified: Date

    init(id: UUID = UUID(), title: String, content: String, lastModified: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.lastModified = lastModified
    }

    /// 从 markdown 内容自动提取标题（第一个 # 行，或前20字符）
    static func titleFromContent(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }

        if let fallback = firstReadableFallbackTitleLine(in: lines) {
            return String(fallback.prefix(30))
        }

        return "公式笔记"
    }

    private static func firstReadableFallbackTitleLine(in lines: [String]) -> String? {
        var insideDollarMath = false
        var insideBracketMath = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if insideDollarMath {
                if trimmed.contains("$$") {
                    insideDollarMath = false
                }
                continue
            }

            if insideBracketMath {
                if trimmed.contains(#"\]"#) || trimmed.contains(#"\\]"#) {
                    insideBracketMath = false
                }
                continue
            }

            if trimmed.hasPrefix("$$") {
                if !String(trimmed.dropFirst(2)).contains("$$") {
                    insideDollarMath = true
                }
                continue
            }

            if trimmed.hasPrefix(#"\["#) || trimmed.hasPrefix(#"\\["#) {
                if !trimmed.contains(#"\]"#) && !trimmed.contains(#"\\]"#) {
                    insideBracketMath = true
                }
                continue
            }

            if isStandaloneInlineMath(trimmed) {
                continue
            }

            return trimmed
        }

        return nil
    }

    private static func isStandaloneInlineMath(_ line: String) -> Bool {
        // \(...\) 格式
        if line.hasPrefix(#"\("#) && line.hasSuffix(#"\)"#) && line.count > 4 {
            return true
        }
        // $...$ 格式：确保只有一个开头 $ 和一个结尾 $，中间无其他 $
        guard line.hasPrefix("$"), line.hasSuffix("$"), !line.hasPrefix("$$"), line.count > 2 else {
            return false
        }
        let inner = String(line.dropFirst().dropLast())
        // 内部不应再有未转义的 $，否则不是独立行内公式
        return !inner.contains("$")
    }
}
