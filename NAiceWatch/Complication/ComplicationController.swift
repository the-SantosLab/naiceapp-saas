import SwiftUI
import ClockKit

// MARK: - Complication Controller
struct NAiceComplicationController {
    /// Returns the tint color based on recovery score
    static func tintColor(for recovery: Int) -> UIColor {
        if recovery >= 67 { return UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1) }
        if recovery >= 34 { return UIColor(red: 0.961, green: 0.62, blue: 0.043, alpha: 1) }
        return UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
    }

    /// Returns the recovery label
    static func recoveryLabel(_ score: Int) -> String {
        if score >= 67 { return "Gut" }
        if score >= 34 { return "Mittel" }
        return "Niedrig"
    }

    /// Returns the system image name for recovery
    static func systemImage(for recovery: Int) -> String {
        if recovery >= 67 { return "heart.fill" }
        if recovery >= 34 { return "heart" }
        return "heart.slash"
    }
}

// MARK: - Complication Timeline Provider
struct NAiceComplication: ComplicationDataSource {
    func getCurrentTimelineEntry(for complication: CLKComplication) async -> CLKComplicationTimelineEntry? {
        let recovery = WatchDataStore.shared.whoop.recoveryScore
        let hrv = WatchDataStore.shared.whoop.hrv
        let rhr = WatchDataStore.shared.whoop.rhr
        let sleep = WatchDataStore.shared.whoop.sleepHours

        let template: CLKComplicationTemplate

        switch complication.family {
        case .circularSmall:
            template = CLKComplicationTemplateCircularSmallRingText(
                textProvider: CLKSimpleTextProvider(text: "\(recovery)%"),
                fillFraction: Float(recovery) / 100.0,
                ringStyle: .closed
            )

        case .graphicCircular:
            template = CLKComplicationTemplateGraphicCircularClosedGaugeImage(
                gaugeProvider: CLKSimpleGaugeProvider(
                    style: .fill,
                    gaugeColors: [
                        UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1),
                        UIColor(red: 0.961, green: 0.62, blue: 0.043, alpha: 1),
                        UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1)
                    ],
                    gaugeColorLocations: [0.0, 0.34, 0.67],
                    fillFraction: Float(recovery) / 100.0
                ),
                imageProvider: CLKFullColorImageProvider(
                    fullColorImage: UIImage(systemName: "heart.fill")!
                )
            )

        case .graphicRectangular:
            let textProvider = CLKSimpleTextProvider(text: "🫀 \(recovery)% · ❤️ \(Int(hrv)) · 💓 \(rhr)")
            let detailProvider = CLKSimpleTextProvider(text: "🌙 \(String(format: "%.1f", sleep))h · ⚡ \(Int(WatchDataStore.shared.whoop.strain)) Strain")
            template = CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "nAIce Recovery"),
                headerImageProvider: CLKFullColorImageProvider(
                    fullColorImage: UIImage(systemName: "heart.fill")!
                ),
                body1TextProvider: textProvider,
                body2TextProvider: detailProvider
            )

        case .graphicCorner:
            template = CLKComplicationTemplateGraphicCornerGaugeText(
                gaugeProvider: CLKSimpleGaugeProvider(
                    style: .fill,
                    gaugeColors: [
                        UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1),
                        UIColor(red: 0.961, green: 0.62, blue: 0.043, alpha: 1),
                        UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1)
                    ],
                    gaugeColorLocations: [0.0, 0.34, 0.67],
                    fillFraction: Float(recovery) / 100.0
                ),
                outerTextProvider: CLKSimpleTextProvider(text: "\(recovery)%"),
                innerTextProvider: CLKSimpleTextProvider(text: recoveryLabel(recovery))
            )

        case .utilitarianSmall:
            template = CLKComplicationTemplateUtilitarianSmallRingText(
                textProvider: CLKSimpleTextProvider(text: "\(recovery)%"),
                fillFraction: Float(recovery) / 100.0,
                ringStyle: .closed
            )

        case .graphicExtraLarge:
            let textProvider = CLKSimpleTextProvider(text: "\(recovery)%")
            textProvider.tintColor = tintColor(for: recovery)
            template = CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeText(
                gaugeProvider: CLKSimpleGaugeProvider(
                    style: .fill,
                    gaugeColors: [UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)],
                    gaugeColorLocations: [0.0],
                    fillFraction: Float(recovery) / 100.0
                ),
                textProvider: textProvider
            )

        default:
            template = CLKComplicationTemplateCircularSmallRingText(
                textProvider: CLKSimpleTextProvider(text: "\(recovery)%"),
                fillFraction: Float(recovery) / 100.0,
                ringStyle: .closed
            )
        }

        return CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
    }

    func getLocalizableSampleTemplate(for complication: CLKComplication) async -> CLKComplicationTemplate? {
        let recovery = 57
        switch complication.family {
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallRingText(
                textProvider: CLKSimpleTextProvider(text: "\(recovery)%"),
                fillFraction: 0.57,
                ringStyle: .closed
            )
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularClosedGaugeText(
                gaugeProvider: CLKSimpleGaugeProvider(
                    style: .fill,
                    gaugeColors: [UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)],
                    gaugeColorLocations: [0.0],
                    fillFraction: 0.57
                ),
                textProvider: CLKSimpleTextProvider(text: "\(recovery)%")
            )
        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "nAIce Recovery"),
                body1TextProvider: CLKSimpleTextProvider(text: "🫀 57% · ❤️ 78 · 💓 62"),
                body2TextProvider: CLKSimpleTextProvider(text: "🌙 5.3h · ⚡ 7.2 Strain")
            )
        default:
            return CLKComplicationTemplateCircularSmallRingText(
                textProvider: CLKSimpleTextProvider(text: "\(recovery)%"),
                fillFraction: 0.57,
                ringStyle: .closed
            )
        }
    }

    private func tintColor(for recovery: Int) -> UIColor {
        NAiceComplicationController.tintColor(for: recovery)
    }

    private func recoveryLabel(_ score: Int) -> String {
        NAiceComplicationController.recoveryLabel(score)
    }
}

// MARK: - Complication Registration
struct NAiceComplicationRegister: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "pro.naice.app.watch.complication",
            provider: NAiceComplicationProvider()
        ) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("nAIce Recovery")
        .description("Zeigt deine WHOOP Recovery auf dem Zifferblatt")
        .supportedFamilies([
            .circularSmall, .graphicCircular, .graphicRectangular,
            .graphicCorner, .utilitarianSmall, .graphicExtraLarge
        ])
    }
}

struct NAiceComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> NAiceComplicationEntry {
        NAiceComplicationEntry(recovery: 57, hrv: 78, rhr: 62, sleep: 5.3, strain: 7.2)
    }

    func getSnapshot(in context: Context, completion: @escaping (NAiceComplicationEntry) -> Void) {
        let ds = WatchDataStore.shared
        completion(NAiceComplicationEntry(
            recovery: ds.whoop.recoveryScore,
            hrv: ds.whoop.hrv,
            rhr: ds.whoop.rhr,
            sleep: ds.whoop.sleepHours,
            strain: ds.whoop.strain
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NAiceComplicationEntry>) -> Void) {
        let ds = WatchDataStore.shared
        let entry = NAiceComplicationEntry(
            recovery: ds.whoop.recoveryScore,
            hrv: ds.whoop.hrv,
            rhr: ds.whoop.rhr,
            sleep: ds.whoop.sleepHours,
            strain: ds.whoop.strain
        )
        // Refresh every 30 minutes
        let refreshDate = Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct NAiceComplicationEntry: TimelineEntry {
    let date: Date
    let recovery: Int
    let hrv: Double
    let rhr: Int
    let sleep: Double
    let strain: Double

    init(recovery: Int, hrv: Double, rhr: Int, sleep: Double, strain: Double) {
        self.date = Date()
        self.recovery = recovery
        self.hrv = hrv
        self.rhr = rhr
        self.sleep = sleep
        self.strain = strain
    }
}

struct ComplicationView: View {
    let entry: NAiceComplicationEntry

    var body: some View {
        VStack(spacing: 2) {
            Text("\(entry.recovery)%")
                .font(.headline)
                .foregroundColor(recoveryColor(entry.recovery))
            HStack(spacing: 4) {
                Text("❤️\(Int(entry.hrv))")
                    .font(.caption2)
                Text("💓\(entry.rhr)")
                    .font(.caption2)
            }
            .foregroundColor(.gray)
        }
    }

    private func recoveryColor(_ score: Int) -> Color {
        if score >= 67 { return .green }
        if score >= 34 { return .orange }
        return .red
    }
}