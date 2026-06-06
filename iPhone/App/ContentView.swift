import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var showSyncToast = false
    @State private var syncToastMessage = ""
    @State private var syncToastWorkItem: DispatchWorkItem?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                NoteListView()
                    .navigationTitle("备忘录")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(spacing: 16) {
                                Button {
                                    triggerSync()
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.title3)
                                }
                                .accessibilityLabel("同步到 Apple Watch")
                                NavigationLink {
                                    FileImportView()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                }
                                .accessibilityLabel("导入笔记")
                            }
                        }
                }

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
        }
    }

    private func triggerSync() {
        syncToastWorkItem?.cancel()
        let result = WatchSyncManager.shared.sendNotes(store.notes)
        syncToastMessage = result.message
        withAnimation {
            showSyncToast = true
        }
        let workItem = DispatchWorkItem {
            withAnimation {
                showSyncToast = false
            }
        }
        syncToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }
}
