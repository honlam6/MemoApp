import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var showSyncToast = false
    @State private var syncToastMessage = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                NoteListView()
                    .navigationTitle("备忘录")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(spacing: 16) {
                                Button {
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
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.title3)
                                }
                                NavigationLink {
                                    FileImportView()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                }
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
}
