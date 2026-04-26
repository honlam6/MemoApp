import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject var store: NoteStore
    let note: Note
    @State private var content: String = ""
    @State private var hasChanges = false
    @State private var showPreview = false
    @State private var showSyncToast = false
    @State private var syncToastMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if showPreview {
                MarkdownPreviewView(content: content)
            } else {
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .onChange(of: content) { _, newValue in
                        hasChanges = (newValue != note.content)
                    }
            }
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showPreview.toggle()
                } label: {
                    Image(systemName: showPreview ? "pencil" : "eye")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if hasChanges {
                        Button("保存") {
                            store.updateNote(note, content: content)
                            hasChanges = false
                            triggerSync()
                        }
                        .bold()
                    }
                    Button {
                        triggerSync()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSyncToast {
                Text(syncToastMessage)
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            content = note.content
        }
        .onDisappear {
            if hasChanges {
                store.updateNote(note, content: content)
            }
        }
    }

    private func triggerSync() {
        let result = WatchSyncManager.shared.sendNotes(store.notes)
        syncToastMessage = result.message
        withAnimation {
            showSyncToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSyncToast = false
            }
        }
    }
}
