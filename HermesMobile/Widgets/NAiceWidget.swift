import WidgetKit
import SwiftUI

// MARK: - Data Models

struct WeatherSnapshot: Codable, Equatable {
    let temperature: Double
    let condition: String
    let sfSymbol: String

    static let placeholder = WeatherSnapshot(
        temperature: 22,
        condition: "Sonnig",
        sfSymbol: "sun.max.fill"
    )
}

struct CalendarEvent: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?

    static let placeholder = CalendarEvent(
        id: "placeholder",
        title: "Team Standup",
        startDate: Date().addingTimeInterval(1800),
        endDate: Date().addingTimeInterval(3600),
        location: "Conference Room A"
    )
}

struct HealthSnapshot: Codable, Equatable {
    let steps: Int
    let heartRate: Double

    static let placeholder = HealthSnapshot(
        steps: 8423,
        heartRate: 72
    )
}

// MARK: - Timeline Entry

struct SimpleEntry: TimelineEntry {
    let date: Date
    let weather: WeatherSnapshot
    let events: [CalendarEvent]
    let health: HealthSnapshot

    /// Placeholder used during widget gallery preview & redaction
    static let placeholder = SimpleEntry(
        date: Date(),
        weather: .placeholder,
        events: [.placeholder],
        health: .placeholder
    )

    /// Empty / loading state when data is unavailable
    static let empty = SimpleEntry(
        date: Date(),
        weather: .placeholder,
        events: [],
        health: .placeholder
    )
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = context.isPreview
            ? SimpleEntry.placeholder
            : SimpleEntry.empty
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        Task {
            let entry = await loadCurrentEntry()
            // Refresh every 15 minutes; also trigger a re-load when the app sends a timeline intent
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date.addingTimeInterval(900)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }

    // MARK: - Data Loading

    /// Ideally reads from shared container (`AppGroup`) written by the main app.
    /// Falls back to placeholder values so the widget always renders.
    private func loadCurrentEntry() async -> SimpleEntry {
        // ── Weather (stub) ────────────────────────────────────────
        let weather: WeatherSnapshot = {
            // TODO: Read from UserDefaults(suiteName: "group.hermesmobile") or a shared model
            WeatherSnapshot(
                temperature: 22,
                condition: "Sonnig",
                sfSymbol: "sun.max.fill"
            )
        }()

        // ── Calendar Events (stub) ────────────────────────────────
        let events: [CalendarEvent] = {
            // TODO: Read from shared container – EventKit or app-synced store
            []
        }()

        // ── Health Data (stub) ────────────────────────────────────
        let health: HealthSnapshot = {
            // TODO: Read from HealthKit data written to shared container
            HealthSnapshot(steps: 8423, heartRate: 72)
        }()

        return SimpleEntry(
            date: Date(),
            weather: weather,
            events: events,
            health: health
        )
    }
}

// MARK: - Dark Theme View

struct NAiceWidgetEntryView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallTodayView
            case .systemMedium:
                mediumTodayView
            case .accessoryRectangular, .accessoryInline, .accessoryCircular:
                lockScreenView
            case .systemLarge, .systemExtraLarge:
                mediumTodayView
            @unknown default:
                smallTodayView
            }
        }
        .containerBackground(for: .widget) {
            Color.black.edgesIgnoringSafeArea(.all)
        }
    }

    // MARK: - Today Widget – Small

    private var smallTodayView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Weather row
            HStack(spacing: 4) {
                Image(systemName: entry.weather.sfSymbol)
                    .foregroundColor(.yellow)
                    .font(.system(size: 14, weight: .medium))
                Text("\(Int(entry.weather.temperature))°")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer(minLength: 0)

            // Next event
            if let next = entry.events.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(next.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(next.startDate, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            } else {
                Text("Keine Termine")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer(minLength: 0)

            // Health row
            HStack(spacing: 10) {
                Label("\(entry.health.steps)", systemImage: "figure.walk")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                Label("\(Int(entry.health.heartRate))", systemImage: "heart.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(12)
    }

    // MARK: – Today Widget – Medium

    private var mediumTodayView: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Weather + Health
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: entry.weather.sfSymbol)
                        .foregroundColor(.yellow)
                        .font(.system(size: 16, weight: .medium))
                    Text("\(Int(entry.weather.temperature))°")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    Label("\(entry.health.steps) Schritte", systemImage: "figure.walk")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                    Label("\(Int(entry.health.heartRate)) bpm", systemImage: "heart.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
            }

            Divider()
                .background(Color.gray.opacity(0.4))

            // Right: Events
            VStack(alignment: .leading, spacing: 6) {
                Text("Termine")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                if entry.events.isEmpty {
                    Text("Keine Termine")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                } else {
                    ForEach(Array(entry.events.prefix(3))) { event in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(event.startDate, style: .time)
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                    if let loc = event.location {
                                        Text("· \(loc)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }

    // MARK: – Lock Screen Widget

    private var lockScreenView: some View {
        HStack(spacing: 12) {
            // Next event
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                if let next = entry.events.first {
                    Text(next.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(next.startDate, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                } else {
                    Text("Keine Termine")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Health data
            VStack(alignment: .leading, spacing: 2) {
                Label("\(entry.health.steps)", systemImage: "figure.walk")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                Label("\(Int(entry.health.heartRate))", systemImage: "heart.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(12)
    }
}

// MARK: - Widget Configuration

struct NAiceWidget: Widget {
    let kind: String = "com.uzairansar.hermesmobile.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
            NAiceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("nAIce")
        .description("Wetter, Termine & Health – immer aktuell.")
        .supportedFamilies([
            // Today Widget variants
            .systemSmall,
            .systemMedium,
            // Lock Screen variants
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
        ])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    NAiceWidget()
} timeline: {
    SimpleEntry.placeholder
    SimpleEntry.empty
}

#Preview(as: .systemMedium) {
    NAiceWidget()
} timeline: {
    SimpleEntry.placeholder
    SimpleEntry.empty
}

#Preview(as: .accessoryRectangular) {
    NAiceWidget()
} timeline: {
    SimpleEntry.placeholder
    SimpleEntry.empty
}