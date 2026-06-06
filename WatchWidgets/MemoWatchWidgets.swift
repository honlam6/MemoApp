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

struct MemoWatchWidgetEntryView: View {
    let entry: MemoWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(count: entry.noteCount)
        default:
            AccessoryCircularView(count: entry.noteCount)
        }
    }
}

private struct AccessoryCircularView: View {
    let count: Int

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
        }
    }
}

struct MemoWatchWidget: Widget {
    let kind: String = "MemoWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoWidgetProvider()) { entry in
            MemoWatchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("备忘录")
        .description("显示备忘录数量")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct MemoWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MemoWatchWidget()
    }
}
