import Foundation

@main
struct NoteDataFlowTests {
    static func main() {
        skipsLeadingDisplayMathWhenDerivingFallbackTitle()
        preservesLatexContentAcrossJSONRoundTrip()

        print("NoteDataFlowTests passed")
    }

    private static func skipsLeadingDisplayMathWhenDerivingFallbackTitle() {
        let content = """
        $$E(X)=n\\frac{K}{N}$$

        超几何分布期望与方差
        """

        let title = Note.titleFromContent(content)

        assertEqual(title, "超几何分布期望与方差", "fallback title should skip leading display math")
    }

    private static func preservesLatexContentAcrossJSONRoundTrip() {
        let content = """
        # 条件概率

        第一行
        第二行

        $$P(A\\mid B)=\\frac{P(B\\mid A)P(A)}{P(B)}$$

        $E(X)=\\sum_{i=1}^{n}x_i p_i + \\frac{a+b+c+d+e+f+g+h+i+j}{k+l+m+n+o+p+q+r+s+t}$
        """
        let note = Note(title: Note.titleFromContent(content), content: content)

        let encoded = tryOrFail { try JSONEncoder().encode([note]) }
        let decoded = tryOrFail { try JSONDecoder().decode([Note].self, from: encoded) }

        assertEqual(decoded.count, 1, "decoded note count")
        assertEqual(decoded[0].content, content, "LaTeX content and line breaks should survive JSON round trip")
    }

    private static func tryOrFail<T>(_ work: () throws -> T) -> T {
        do {
            return try work()
        } catch {
            fatalError("Unexpected thrown error: \(error)")
        }
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message): expected \(expected), got \(actual)")
        }
    }
}
