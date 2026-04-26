import SwiftUI

class WatchNoteStore: ObservableObject {
    @Published var notes: [Note] = []

    init() {
        notes = NoteStorage.loadNotes()
        WatchSyncManager.shared.onNotesReceived = { [weak self] receivedNotes in
            DispatchQueue.main.async {
                self?.notes = receivedNotes
                NoteStorage.saveNotes(receivedNotes)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.requestSync(reason: "init")
        }
    }

    func requestSync(reason: String = "manual") {
        WatchSyncManager.shared.requestSyncFromWatch(reason: reason)
    }
}

struct WatchContentView: View {
    @EnvironmentObject var store: WatchNoteStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if store.notes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("等待同步")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("请在 iPhone 上导入笔记")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            } else {
                NavigationStack(path: $path) {
                    List {
                        ForEach(store.notes) { note in
                            NavigationLink(value: note.id) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(2)
                                    Text(note.lastModified, style: .relative)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .listStyle(.carousel)
                    .navigationTitle("备忘录")
                    .navigationDestination(for: UUID.self) { noteId in
                        if let note = store.notes.first(where: { $0.id == noteId }) {
                            NoteReaderView(note: note)
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                store.requestSync(reason: "foreground")
            }
        }
        .onOpenURL { url in
            guard url.scheme == "memoapp-watch" else { return }

            if let host = url.host(), host == "note",
               let noteIDString = url.pathComponents.dropFirst().first,
               let noteID = UUID(uuidString: noteIDString),
               store.notes.contains(where: { $0.id == noteID }) {
                path = NavigationPath()
                path.append(noteID)
            }
        }
    }
}
