import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct FireDoorLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var remaining: Int { entry.snapshot.remaining }
    private var total: Int { entry.snapshot.totalEntries }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Fire doors", systemImage: remaining == 0 ? "checkmark.seal.fill" : "door.left.hand.closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(remaining == 0 ? .green : .orange)

            Spacer(minLength: 0)

            if total == 0 {
                Text("Add your first register")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if remaining == 0 {
                Text("All current")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("\(total) openings")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("\(remaining)")
                    .font(.system(size: family == .systemSmall ? 38 : 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("of \(total) still to inspect")
                    .font(.caption2).foregroundStyle(.secondary)
                if family != .systemSmall, let note = entry.snapshot.lastEntryTitle {
                    Text(note).font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct FireDoorLogWidget: Widget {
    let kind = "FireDoorLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            FireDoorLogWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("\(AppConfig.entryNounPlural) this week and your latest one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FireDoorLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        FireDoorLogWidget()
    }
}
