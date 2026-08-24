import WidgetKit
import SwiftUI

// MARK: - Widget Data Models (server-driven)
struct NAiceWidgetData: Codable {
    let cardType: String
    let cardTitle: String
    let cardMessage: String
    let cardIcon: String
    let balanceScore: Int
    let recoveryScore: Int
    let sleepHours: Double
    let nextEvent: String
    let unreadWA: Int
    let actions: [NAiceWidgetAction]

    static var empty: NAiceWidgetData {
        NAiceWidgetData(
            cardType: "morning", cardTitle: "☀️ Guten Morgen",
            cardMessage: "nAIce ist bereit.", cardIcon: "n.square.fill",
            balanceScore: 70, recoveryScore: 0, sleepHours: 0,
            nextEvent: "", unreadWA: 0,
            actions: [
                NAiceWidgetAction(id: "mood", icon: "face.smiling", label: "Stimmung", url: "naice://log/mood"),
                NAiceWidgetAction(id: "chat", icon: "message", label: "Agent", url: "naice://chat"),
            ]
        )
    }

    static func fetch() async -> NAiceWidgetData {
        guard let url = URL(string: "https://health.santoslab.de/api/naice/widget-data") else { return .empty }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(NAiceWidgetData.self, from: data)
        } catch {
            return .empty
        }
    }
}

struct NAiceWidgetAction: Codable {
    let id: String
    let icon: String
    let label: String
    let url: String
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NAiceEntry {
        NAiceEntry(date: Date(), data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (NAiceEntry) -> Void) {
        Task { let data = await NAiceWidgetData.fetch(); completion(NAiceEntry(date: Date(), data: data)) }
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

// MARK: - Small Widget – Cards of the Moment
struct NAiceWidgetEntryView: View {
    var entry: Provider.Entry
    var d: NAiceWidgetData { entry.data }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "n.square.fill").font(.caption).foregroundColor(.green)
                Text("nAIce").font(.caption.weight(.bold)).foregroundColor(.primary)
                Spacer()
                Text(entry.date, style: .time).font(.system(size: 8)).foregroundColor(.secondary)
            }

            // Cards of the Moment – context-aware card
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: d.cardIcon).font(.title3).foregroundColor(.green)
                    Text(d.cardTitle).font(.caption.weight(.semibold)).foregroundColor(.primary)
                }
                Text(d.cardMessage).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)

                // Mini health row
                HStack(spacing: 6) {
                    if d.recoveryScore > 0 {
                        HStack(spacing: 2) {
                            Circle().fill(d.recoveryScore > 60 ? Color.green : .orange).frame(width: 6, height: 6)
                            Text("\(d.recoveryScore)%").font(.system(size: 8)).foregroundColor(.secondary)
                        }
                    }
                    if d.sleepHours > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "moon.fill").font(.system(size: 6)).foregroundColor(.indigo)
                            Text("\(d.sleepHours, specifier: "%.1f")h").font(.system(size: 8)).foregroundColor(.secondary)
                        }
                    }
                    if d.unreadWA > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "message.fill").font(.system(size: 6)).foregroundColor(.green)
                            Text("\(d.unreadWA)").font(.system(size: 8)).foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            Spacer(minLength: 0)

            // Quick Action Buttons
            HStack(spacing: 4) {
                ForEach(d.actions.prefix(3), id: \.id) { action in
                    Link(destination: URL(string: action.url)!) {
                        VStack(spacing: 2) {
                            Image(systemName: action.icon).font(.system(size: 10)).foregroundColor(.green)
                            Text(action.label).font(.system(size: 7)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(10)
        .containerBackground(Color(.systemBackground).opacity(0.95), for: .widget)
    }
}

// MARK: - Medium Widget – Full Cards + Actions
struct NAiceWidgetMediumView: View {
    var entry: Provider.Entry
    var d: NAiceWidgetData { entry.data }

    var body: some View {
        HStack(spacing: 12) {
            // Left: Cards of the Moment
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "n.square.fill").font(.caption).foregroundColor(.green)
                    Text("nAIce").font(.caption.weight(.bold)).foregroundColor(.primary)
                    Spacer()
                    Text(entry.date, style: .time).font(.system(size: 8)).foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: d.cardIcon).font(.title3).foregroundColor(.green)
                        Text(d.cardTitle).font(.caption.weight(.semibold)).foregroundColor(.primary)
                    }
                    Text(d.cardMessage).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
                }
                .padding(8)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 0)

                // Health row
                HStack(spacing: 8) {
                    if d.recoveryScore > 0 { Label("\(d.recoveryScore)%", systemImage: "heart.fill").font(.system(size: 9)).foregroundColor(.secondary) }
                    if d.sleepHours > 0 { Label("\(d.sleepHours, specifier: "%.1f")h", systemImage: "moon.fill").font(.system(size: 9)).foregroundColor(.secondary) }
                    if d.unreadWA > 0 { Label("\(d.unreadWA) WA", systemImage: "message.fill").font(.system(size: 9)).foregroundColor(.orange) }
                }
            }

            Divider()

            // Right: Quick Actions + Balance
            VStack(spacing: 8) {
                // Balance ring
                ZStack {
                    Circle().stroke(Color.green.opacity(0.2), lineWidth: 4).frame(width: 40, height: 40)
                    Circle().trim(from: 0, to: CGFloat(d.balanceScore) / 100)
                        .stroke(Color.green, lineWidth: 4).frame(width: 40, height: 40).rotationEffect(.degrees(-90))
                    Text("\(d.balanceScore)").font(.system(size: 12, weight: .bold)).foregroundColor(.primary)
                }

                // Action buttons
                VStack(spacing: 4) {
                    ForEach(d.actions.prefix(3), id: \.id) { action in
                        Link(destination: URL(string: action.url)!) {
                            HStack(spacing: 6) {
                                Image(systemName: action.icon).font(.system(size: 9)).foregroundColor(.green).frame(width: 16)
                                Text(action.label).font(.system(size: 9)).foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            }
            .frame(width: 90)
        }
        .padding(12)
        .containerBackground(Color(.systemBackground).opacity(0.95), for: .widget)
    }
}

// MARK: - Lock Screen Widget
struct NAiceLockScreenWidgetView: View {
    var entry: Provider.Entry
    var d: NAiceWidgetData { entry.data }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: d.cardIcon).font(.caption).foregroundColor(.green)
            Text(d.cardMessage.prefix(30)).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
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
        .configurationDisplayName("nAIce Cards")
        .description("Kontext-Karten + Quick Actions.")
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
        .description("Kurznachricht vom Agent.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}