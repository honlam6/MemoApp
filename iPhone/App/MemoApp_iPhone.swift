import SwiftUI

@main
struct MemoApp_iPhone: App {
    @StateObject private var noteStore = NoteStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteStore)
                .onOpenURL { url in
                    noteStore.handleOpenURL(url)
                }
        }
    }
}
