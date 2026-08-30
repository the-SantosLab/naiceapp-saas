import WidgetKit
import SwiftUI

// MARK: - Complication Timeline Provider
struct NAiceComplicationTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NAiceComplicationEntry {
        NAiceComplicationEntry(date: Date(), recovery: 57, hrv: 78, rhr: 62, sleep: 5.3, strain: 7.2)
    }

    func getSnapshot(in context: Context, completion: @escaping (NAiceComplicationEntry) -> Void) {
        let ds = WatchDataStore.shared
        let entry = NAiceComplicationEntry(
            date: Date(),
            recovery: ds.whoop.recoveryScore,
            hrv: ds.whoop.hrv,
            rhr: ds.whoop.rhr,
            sleep: ds.whoop.sleepHours,
            strain: ds.whoop.strain
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NAiceComplicationEntry>) -> Void) {
        let ds = WatchDataStore.shared
        let entry = NAiceComplicationEntry(
            date: Date(),
            recovery: ds.whoop.recoveryScore,
            hrv: ds.whoop.hrv,
            rhr: ds.whoop.rhr,
            sleep: ds.whoop.sleepHours,
            strain: ds.whoop.strain
        )
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Complication Entry
struct NAiceComplicationEntry: TimelineEntry {
    let date: Date
    let recovery: Int
    let hrv: Double
    let rhr: Int
    let sleep: Double
    let strain: Double
}

// MARK: - Recovery Complication Widget
struct NAiceRecoveryComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "pro.naice.app.watch.complication.recovery",
            provider: NAiceComplicationTimelineProvider()
        ) { entry in
            NAiceComplicationView(entry: entry)
        }
        .configurationDisplayName("Recovery")
        .description("Zeigt deine WHOOP Recovery")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - Complication Views
struct NAiceComplicationView: View {
    let entry: NAiceComplicationEntry

    var body: some View {
        Group {
            if #available(watchOS 10.0, *) {
                ViewThatFits {
                    circularView
                    rectangularView
                    inlineView
                }
            } else {
                circularView
            }
        }
    }

    private var circularView: some View {
        Gauge(
            value: Double(entry.recovery),
            in: 0...100,
            label: { Text("") },
            currentValueLabel: {
                Text("\(entry.recovery)")
                    .font(.headline)
                    .foregroundColor(recoveryColor)
            },
            minimumValueLabel: { Text("0").font(.system(size: 6)).foregroundColor(.red) },
            maximumValueLabel: { Text("100").font(.system(size: 6)).foregroundColor(.green) }
        )
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.red, .orange, .green]))
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundColor(recoveryColor)
                Text("nAIce Recovery")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            HStack(spacing: 8) {
                Label("\(entry.recovery)%", systemImage: "heart.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(recoveryColor)
                Text("❤️\(Int(entry.hrv))")
                    .font(.system(size: 10))
                    .foregroundColor(.pink)
                Text("💓\(entry.rhr)")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
    }

    private var inlineView: some View {
        Text("🫀 \(entry.recovery)% · ❤️\(Int(entry.hrv)) · 💓\(entry.rhr)")
            .font(.system(size: 12))
            .foregroundColor(.white)
    }

    private var recoveryColor: Color {
        if entry.recovery >= 67 { return .green }
        if entry.recovery >= 34 { return .orange }
        return .red
    }
}

// MARK: - Complication Registration
struct NAiceComplicationBundle: WidgetBundle {
    var body: some Widget {
        NAiceRecoveryComplication()
    }
}