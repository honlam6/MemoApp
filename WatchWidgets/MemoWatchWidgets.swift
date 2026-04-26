import SwiftUI
import WidgetKit

struct MemoWidgetEntry: TimelineEntry {
    let date: Date
    let noteCount: Int
}

struct MemoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoWidgetEntry {
        MemoWidgetEntry(date: .now, noteCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> MemoWidgetEntry {
        MemoWidgetEntry(date: .now, noteCount: NoteStorage.loadNotes().count)
    }
}

struct MemoAccessoryCircularView: View {
    let entry: MemoWidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(min(entry.noteCount, 99))")
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .widgetURL(URL(string: "memoapp-watch://notes"))
    }
}

struct MemoWatchWidget: Widget {
    let kind: String = "MemoWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoWidgetProvider()) { entry in
            MemoAccessoryCircularView(entry: entry)
        }
        .configurationDisplayName("打开备忘录")
        .description("快速打开手表备忘录。")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct MemoWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MemoWatchWidget()
    }
}
