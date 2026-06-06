import Foundation

@main
struct SharedNoteImportTests {
    static func main() {
        importsMarkdownContentAsNewestNote()
        rejectsBlankSharedContent()

        print("SharedNoteImportTests passed")
    }

    private static func importsMarkdownContentAsNewestNote() {
        let existing = Note(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "旧笔记",
            content: "旧内容",
            lastModified: Date(timeIntervalSince1970: 100)
        )
        let content = """
        # 分享来的 Markdown

        $$P(A\\mid B)=\\frac{P(B\\mid A)P(A)}{P(B)}$$
        """
        let importedAt = Date(timeIntervalSince1970: 200)

        let notes = tryOrFail {
            try NoteImportService.importMarkdown(content, into: [existing], importedAt: importedAt)
        }

        assertEqual(notes.count, 2, "imported notes count")
        assertEqual(notes[0].title, "分享来的 Markdown", "imported note title")
        assertEqual(notes[0].content, content, "imported markdown content")
        assertEqual(notes[0].lastModified, importedAt, "imported note timestamp")
        assertEqual(notes[1], existing, "existing note should remain after imported note")
    }

    private static func rejectsBlankSharedContent() {
        do {
            _ = try NoteImportService.importMarkdown(" \n\t ", into: [], importedAt: Date())
            fatalError("blank shared content should be rejected")
        } catch NoteImportService.ImportError.emptyContent {
            return
        } catch {
            fatalError("blank shared content should throw emptyContent, got \(error)")
        }
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
