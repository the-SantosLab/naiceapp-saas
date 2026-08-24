import WidgetKit
import SwiftUI

// MARK: - nAIce Home Screen Widget
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), balanceScore: 72, unreadWA: 3, nextEvent: "Meeting mit Max")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), balanceScore: NAiceContext.shared.lifeBalanceScore,
                                unreadWA: WhatsAppViewModel.shared.totalUnread,
                                nextEvent: CalendarManager.shared.upcomingEvents.first?.title ?? "Keine Termine")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date(), balanceScore: NAiceContext.shared.lifeBalanceScore,
                                unreadWA: WhatsAppViewModel.shared.totalUnread,
                                nextEvent: CalendarManager.shared.upcomingEvents.first?.title ?? "Keine Termine")
        let nextUpdate = Date().addingTimeInterval(15 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let balanceScore: Int
    let unreadWA: Int
    let nextEvent: String
}

struct NAiceWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "n.square.fill").font(.title3).foregroundColor(.green)
                Text("nAIce").font(.headline.weight(.bold)).foregroundColor(.primary)
                Spacer()
            }

            HStack {
                ZStack {
                    Circle().stroke(Color.green.opacity(0.3), lineWidth: 3).frame(width: 32, height: 32)
                    Circle().trim(from: 0, to: CGFloat(entry.balanceScore) / 100)
                        .stroke(Color.green, lineWidth: 3).frame(width: 32, height: 32).rotationEffect(.degrees(-90))
                    Text("\(entry.balanceScore)").font(.system(size: 10, weight: .bold)).foregroundColor(.primary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Life Balance").font(.caption2).foregroundColor(.secondary)
                    Text(entry.balanceScore > 70 ? "Gut im Flow" : "Ausgeglichen").font(.caption).foregroundColor(.green)
                }
            }

            if entry.unreadWA > 0 {
                Label("\(entry.unreadWA) WhatsApp", systemImage: "message.fill")
                    .font(.caption2).foregroundColor(.orange)
            }

            if !entry.nextEvent.isEmpty && entry.nextEvent != "Keine Termine" {
                Label(entry.nextEvent, systemImage: "calendar")
                    .font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }

            Text(entry.date, style: .time).font(.caption2).foregroundColor(.secondary)
        }
        .padding(12)
        .containerBackground(Color(.systemBackground).opacity(0.9), for: .widget)
    }
}

struct NAiceWidget: Widget {
    let kind: String = "com.santoslab.naice.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NAiceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("nAIce")
        .description("Life Balance, WhatsApp & Termine.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}