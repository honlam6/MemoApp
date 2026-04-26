import SwiftUI

class NoteStore: ObservableObject {
    @Published var notes: [Note] = [] {
        didSet {
            NoteStorage.saveNotes(notes)
            scheduleSync()
        }
    }

    private var syncWorkItem: DispatchWorkItem?

    init() {
        notes = NoteStorage.loadNotes()
        WatchSyncManager.shared.notesProvider = { [weak self] in
            let count = self?.notes.count ?? 0
            print("[Sync][iPhone] notesProvider 被调用，返回 \(count) 条笔记")
            return self?.notes ?? []
        }
        WatchSyncManager.shared.onNotesReceived = { [weak self] receivedNotes in
            DispatchQueue.main.async {
                print("[Sync][iPhone] onNotesReceived: 收到 \(receivedNotes.count) 条笔记")
                self?.notes = receivedNotes
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("[Sync][iPhone] didBecomeActive: 主动同步 \(self.notes.count) 条笔记到 Watch")
            WatchSyncManager.shared.sendNotes(self.notes)
        }
    }

    func addNote(from content: String) {
        let title = Note.titleFromContent(content)
        let note = Note(title: title, content: content)
        notes.insert(note, at: 0)
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
    }

    func updateNote(_ note: Note, content: String) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].content = content
            notes[idx].title = Note.titleFromContent(content)
            notes[idx].lastModified = Date()
        }
    }

    private func scheduleSync() {
        syncWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            WatchSyncManager.shared.sendNotes(self.notes)
        }
        syncWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }
}

struct NoteListView: View {
    @EnvironmentObject var store: NoteStore

    var body: some View {
        Group {
            if store.notes.isEmpty {
                ContentUnavailableView {
                    Label("还没有笔记", systemImage: "doc.text")
                } description: {
                    Text("点击右上角 + 导入 Markdown 文件")
                }
            } else {
                List {
                    ForEach(store.notes) { note in
                        NavigationLink {
                            NoteEditorView(note: note)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(note.lastModified, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.deleteNote(store.notes[index])
                        }
                    }
                }
            }
        }
    }
}
