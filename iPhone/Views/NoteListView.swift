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
            notes = NoteStorage.loadNotes()
            print("[Sync][iPhone] didBecomeActive: 主动同步 \(self.notes.count) 条笔记到 Watch")
            WatchSyncManager.shared.sendNotes(self.notes)
        }
    }

    @discardableResult
    func addNote(from content: String) -> String? {
        do {
            notes = try NoteImportService.importMarkdown(content, into: notes)
            return nil
        } catch {
            let message = "导入失败: \(error.localizedDescription)"
            print("[Import][iPhone] \(message)")
            return message
        }
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
    }

    func updateNote(_ note: Note, content: String) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = notes[idx]
        updated.content = content
        updated.title = Note.titleFromContent(content)
        updated.lastModified = Date()
        notes[idx] = updated  // 单次赋值，只触发一次 didSet
    }

    func handleOpenURL(_ url: URL) {
        guard url.scheme == "memoapp", url.host == "sync" else { return }
        notes = NoteStorage.loadNotes()
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
    @State private var noteToDelete: Note?

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
                        if let index = indexSet.first {
                            noteToDelete = store.notes[index]
                        }
                    }
                }
            }
        }
        .alert("确认删除", isPresented: Binding(
            get: { noteToDelete != nil },
            set: { if !$0 { noteToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let note = noteToDelete {
                    store.deleteNote(note)
                    noteToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                noteToDelete = nil
            }
        } message: {
            if let note = noteToDelete {
                Text("确定要删除「\(note.title)」吗？此操作无法撤销。")
            }
        }
    }
}
