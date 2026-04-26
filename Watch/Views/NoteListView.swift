import SwiftUI

// NoteListView is integrated into WatchContentView above
// This file provides a standalone version if needed

struct WatchNoteListView: View {
    let notes: [Note]
    var body: some View {
        List(notes) { note in
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Text(note.lastModified, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
