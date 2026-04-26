import Foundation

enum MarkdownInline: Equatable {
    case text(String)
    case math(String)
}

enum MarkdownInlineParser {
    private static let cache: NSCache<NSString, CachedInlineParts> = {
        let cache = NSCache<NSString, CachedInlineParts>()
        cache.countLimit = 256
        return cache
    }()

    static func parse(_ text: String) -> [MarkdownInline] {
        let key = text as NSString
        if let cached = cache.object(forKey: key) {
            return cached.parts
        }

        var parts: [MarkdownInline] = []
        var buffer = ""
        var index = text.startIndex

        func flushText() {
            guard !buffer.isEmpty else { return }
            parts.append(.text(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        while index < text.endIndex {
            if startsMathParen(in: text, at: index), let end = findClosingMathParen(in: text, after: text.index(index, offsetBy: 2)) {
                flushText()
                let start = text.index(index, offsetBy: 2)
                parts.append(.math(String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)))
                index = text.index(end, offsetBy: 2)
                continue
            }

            if text[index] == "$", !isEscaped(in: text, at: index), !isDoubleDollar(in: text, at: index), let end = findClosingDollar(in: text, after: text.index(after: index)) {
                flushText()
                let start = text.index(after: index)
                parts.append(.math(String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)))
                index = text.index(after: end)
                continue
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }

        flushText()
        cache.setObject(CachedInlineParts(parts), forKey: key)
        return parts
    }

    private static func startsMathParen(in text: String, at index: String.Index) -> Bool {
        guard text[index] == "\\" else { return false }
        let next = text.index(after: index)
        return next < text.endIndex && text[next] == "("
    }

    private static func findClosingMathParen(in text: String, after start: String.Index) -> String.Index? {
        var index = start
        while index < text.endIndex {
            if text[index] == "\\" {
                let next = text.index(after: index)
                if next < text.endIndex && text[next] == ")" {
                    return index
                }
                index = next
            } else {
                index = text.index(after: index)
            }
        }
        return nil
    }

    private static func findClosingDollar(in text: String, after start: String.Index) -> String.Index? {
        var index = start
        while index < text.endIndex {
            if text[index] == "$", !isEscaped(in: text, at: index), !isDoubleDollar(in: text, at: index) {
                return index
            }
            index = text.index(after: index)
        }
        return nil
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

    private static func isDoubleDollar(in text: String, at index: String.Index) -> Bool {
        let next = text.index(after: index)
        if next < text.endIndex && text[next] == "$" {
            return true
        }
        if index > text.startIndex {
            let previous = text.index(before: index)
            return text[previous] == "$"
        }
        return false
    }
}

private final class CachedInlineParts: NSObject {
    let parts: [MarkdownInline]

    init(_ parts: [MarkdownInline]) {
        self.parts = parts
    }
}
