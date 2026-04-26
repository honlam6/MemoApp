import SwiftUI

@main
struct MemoApp_Watch: App {
    @StateObject private var noteStore = WatchNoteStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(noteStore)
        }
    }
}
