import WidgetKit
import SwiftUI

// MARK: - Widget Data (server-fetched)
struct NAiceWidgetData: Codable {
    let balanceScore: Int
    let unreadWA: Int
    let nextEvent: String
    let sleepHours: Double
    let recoveryScore: Int
    let healthText: String

    static var empty: NAiceWidgetData {
        NAiceWidgetData(balanceScore: 70, unreadWA: 0, nextEvent: "Keine Termine", sleepHours: 0, recoveryScore: 0, healthText: "nAIce")
    }

    static func fetch() async -> NAiceWidgetData {
        let url = URL(string: "https://health.santoslab.de/api/naice/widget-data")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            return try decoder.decode(NAiceWidgetData.self, from: data)
        } catch {
            return .empty
        }
    }
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NAiceEntry {
        NAiceEntry(date: Date(), data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (NAiceEntry) -> Void) {
        Task {
            let data = await NAiceWidgetData.fetch()
            completion(NAiceEntry(date: Date(), data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NAiceEntry>) -> Void) {
        Task {
            let data = await NAiceWidgetData.fetch()
            let entry = NAiceEntry(date: Date(), data: data)
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct NAiceEntry: TimelineEntry {
    let date: Date
    let data: NAiceWidgetData
}

// MARK: - Small Widget
struct NAiceWidgetEntryView: View {
    var entry: Provider.Entry
    var data: NAiceWidgetData { entry.data }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "n.square.fill").font(.caption).foregroundColor(.green)
                Text("nAIce").font(.caption.weight(.bold)).foregroundColor(.primary)
                Spacer()
                Text(entry.date, style: .time).font(.system(size: 8)).foregroundColor(.secondary)
            }

            Spacer(minLength: 4)

            // Balance
            HStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Color.green.opacity(0.2), lineWidth: 3).frame(width: 28, height: 28)
                    Circle().trim(from: 0, to: CGFloat(data.balanceScore) / 100)
                        .stroke(Color.green, lineWidth: 3).frame(width: 28, height: 28).rotationEffect(.degrees(-90))
                    Text("\(data.balanceScore)").font(.system(size: 9, weight: .bold)).foregroundColor(.primary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Balance").font(.system(size: 8)).foregroundColor(.secondary)
                    Text(data.balanceScore > 70 ? "Gut" : data.balanceScore > 40 ? "OK" : "Erholung")
                        .font(.system(size: 9, weight: .semibold)).foregroundColor(data.balanceScore > 70 ? .green : .orange)
                }
            }

            // Recovery
            if data.recoveryScore > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").font(.system(size: 8)).foregroundColor(.red)
                    Text("Recovery \(data.recoveryScore)%").font(.system(size: 8)).foregroundColor(.secondary)
                }
            }

            // Sleep
            if data.sleepHours > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill").font(.system(size: 8)).foregroundColor(.indigo)
                    Text("\(data.sleepHours, specifier: "%.1f")h").font(.system(size: 8)).foregroundColor(.secondary)
                }
            }

            // Next event
            if data.nextEvent != "Keine Termine" {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 8)).foregroundColor(.blue)
                    Text(data.nextEvent).font(.system(size: 8)).foregroundColor(.secondary).lineLimit(1)
                }
            }

            // WhatsApp
            if data.unreadWA > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "message.fill").font(.system(size: 8)).foregroundColor(.green)
                    Text("\(data.unreadWA) offen").font(.system(size: 8)).foregroundColor(.orange)
                }
            }
        }
        .padding(10)
        .containerBackground(Color(.systemBackground).opacity(0.95), for: .widget)
    }
}

// MARK: - Medium Widget
struct NAiceWidgetMediumView: View {
    var entry: Provider.Entry
    var data: NAiceWidgetData { entry.data }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "n.square.fill").font(.caption).foregroundColor(.green)
                    Text("nAIce").font(.caption.weight(.bold)).foregroundColor(.primary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    ZStack {
                        Circle().stroke(Color.green.opacity(0.2), lineWidth: 4).frame(width: 36, height: 36)
                        Circle().trim(from: 0, to: CGFloat(data.balanceScore) / 100)
                            .stroke(Color.green, lineWidth: 4).frame(width: 36, height: 36).rotationEffect(.degrees(-90))
                        Text("\(data.balanceScore)").font(.system(size: 12, weight: .bold)).foregroundColor(.primary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Life Balance").font(.caption2).foregroundColor(.secondary)
                        Text(data.balanceScore > 70 ? "Gut im Flow!" : data.balanceScore > 40 ? "Ausgeglichen" : "Erholung fallig")
                            .font(.caption.weight(.semibold)).foregroundColor(data.balanceScore > 70 ? .green : .orange)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                if data.recoveryScore > 0 {
                    Label("Recovery \(data.recoveryScore)%", systemImage: "heart.fill").font(.caption2).foregroundColor(.secondary)
                }
                if data.sleepHours > 0 {
                    Label("\(data.sleepHours, specifier: "%.1f")h Schlaf", systemImage: "moon.fill").font(.caption2).foregroundColor(.secondary)
                }
                if data.nextEvent != "Keine Termine" {
                    Label(data.nextEvent, systemImage: "calendar").font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
                if data.unreadWA > 0 {
                    Label("\(data.unreadWA) WhatsApp", systemImage: "message.fill").font(.caption2).foregroundColor(.orange)
                }
            }
        }
        .padding(14)
        .containerBackground(Color(.systemBackground).opacity(0.95), for: .widget)
    }
}

// MARK: - Lock Screen Widget
struct NAiceLockScreenWidgetView: View {
    var entry: Provider.Entry
    var data: NAiceWidgetData { entry.data }

    var body: some View {
        HStack {
            ZStack {
                Circle().stroke(Color.green.opacity(0.2), lineWidth: 3).frame(width: 24, height: 24)
                Circle().trim(from: 0, to: CGFloat(data.balanceScore) / 100)
                    .stroke(Color.green, lineWidth: 3).frame(width: 24, height: 24).rotationEffect(.degrees(-90))
                Text("\(data.balanceScore)").font(.system(size: 8, weight: .bold)).foregroundColor(.primary)
            }
            Text("\(data.recoveryScore)% Recovery").font(.caption2).foregroundColor(.secondary)
        }
        .padding(8)
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

// MARK: - Widget Configs
struct NAiceWidget: Widget {
    let kind = "com.santoslab.naice.widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NAiceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("nAIce Balance")
        .description("Life Balance, Gesundheit & Termine.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NAiceLockScreenWidget: Widget {
    let kind = "com.santoslab.naice.lockscreen"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NAiceLockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("nAIce Lock Screen")
        .description("Gesundheit auf einen Blick.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}