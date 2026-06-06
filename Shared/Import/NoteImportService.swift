import Foundation

enum NoteImportService {
    enum ImportError: Error, Equatable {
        case emptyContent
    }

    static func importMarkdown(
        _ content: String,
        into existingNotes: [Note],
        importedAt: Date = Date()
    ) throws -> [Note] {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.emptyContent
        }

        let note = Note(
            title: Note.titleFromContent(content),
            content: content,
            lastModified: importedAt
        )
        return [note] + existingNotes
    }
}
