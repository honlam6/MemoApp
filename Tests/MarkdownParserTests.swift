import Foundation

@main
struct MarkdownParserTests {
    static func main() {
        parsesSingleLineDollarMathAsMathBlock()
        parsesMultilineDollarMathWithInlineDelimiters()
        keepsPipesInsideInlineMathWithinTableCells()

        print("MarkdownParserTests passed")
    }

    private static func parsesSingleLineDollarMathAsMathBlock() {
        let blocks = MarkdownParser.parse("Before\n$$X\\sim B(n,p)$$\nAfter")

        assertEqual(blocks.count, 3, "single-line math block count")
        assertEqual(blocks[1], .mathBlock(formula: "X\\sim B(n,p)"), "single-line math block")
    }

    private static func parsesMultilineDollarMathWithInlineDelimiters() {
        let markdown = """
        $$E(X)=n\\frac{K}{N},\\qquad V(X)=n\\frac{K}{N}\\left(1-\\frac{K}{N}
        \\right)\\frac{N-n}{N-1}$$
        """

        let blocks = MarkdownParser.parse(markdown)

        assertEqual(blocks.count, 1, "multiline math block count")
        assertEqual(
            blocks[0],
            .mathBlock(formula: "E(X)=n\\frac{K}{N},\\qquad V(X)=n\\frac{K}{N}\\left(1-\\frac{K}{N}\n\\right)\\frac{N-n}{N-1}"),
            "multiline math block"
        )
    }

    private static func keepsPipesInsideInlineMathWithinTableCells() {
        let markdown = """
        | id | formula | note |
        |---|---|---|
        | 1 | $P(A|B)=P(A\\cap B)/P(B)$ | conditional |
        """

        let blocks = MarkdownParser.parse(markdown)

        guard case .table(let headers, let rows) = blocks.first else {
            fatalError("Expected a table block")
        }
        assertEqual(headers.count, 3, "table header column count")
        assertEqual(rows[0].count, 3, "table row column count")
        assertEqual(rows[0][1], "$P(A|B)=P(A\\cap B)/P(B)$", "table math pipe cell")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message): expected \(expected), got \(actual)")
        }
    }
}
