import Foundation
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Dynamic Island / Live Activity
struct NAiceActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
        var statusIcon: String
        var progressValue: Double
        var balanceScore: Int
    }
    var title: String
}

// MARK: - Live Activity View
struct NAiceLiveActivityView: View {
    let context: ActivityViewContext<NAiceActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.state.statusIcon)
                .font(.title2).foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.headline.weight(.semibold)).foregroundColor(.primary)
                Text(context.state.statusText)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                ZStack {
                    Circle().stroke(Color.green.opacity(0.2), lineWidth: 3).frame(width: 28, height: 28)
                    Circle().trim(from: 0, to: CGFloat(context.state.balanceScore) / 100)
                        .stroke(Color.green, lineWidth: 3).frame(width: 28, height: 28).rotationEffect(.degrees(-90))
                    Text("\(context.state.balanceScore)").font(.system(size: 9, weight: .bold)).foregroundColor(.primary)
                }
                Text("Balance").font(.system(size: 8)).foregroundColor(.secondary)
            }
            if context.state.progressValue > 0 {
                ProgressView(value: context.state.progressValue).tint(.green).frame(width: 30)
            }
        }
        .padding(.horizontal, 12)
        .activityBackgroundTint(Color(.systemBackground).opacity(0.8))
    }
}

// MARK: - Live Activity Widget
struct NAiceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NAiceActivityAttributes.self) { context in
            NAiceLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.statusIcon).foregroundColor(.green).font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ZStack {
                        Circle().stroke(Color.green.opacity(0.2), lineWidth: 3).frame(width: 28, height: 28)
                        Circle().trim(from: 0, to: CGFloat(context.state.balanceScore) / 100)
                            .stroke(Color.green, lineWidth: 3).frame(width: 28, height: 28).rotationEffect(.degrees(-90))
                        Text("\(context.state.balanceScore)").font(.system(size: 9, weight: .bold))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(.headline).foregroundColor(.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.statusText).font(.caption).foregroundColor(.secondary)
                        if context.state.progressValue > 0 {
                            ProgressView(value: context.state.progressValue).tint(.green)
                        }
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Image(systemName: context.state.statusIcon).foregroundColor(.green).font(.caption)
            } compactTrailing: {
                Text(String(context.state.statusText.prefix(15))).font(.caption2)
            } minimal: {
                Image(systemName: context.state.statusIcon).foregroundColor(.green)
            }
        }
        .configurationDisplayName("nAIce Agent")
        .description("Agent-Status auf Sperrbildschirm und Dynamic Island.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Activity Manager
@MainActor
class NAiceActivityManager {
    static let shared = NAiceActivityManager()
    private var current: Activity<NAiceActivityAttributes>?

    func start(title: String = "nAIce") {
        let attrs = NAiceActivityAttributes(title: title)
        let state = NAiceActivityAttributes.ContentState(statusText: "Bereit", statusIcon: "n.square.fill", progressValue: 0, balanceScore: 72)
        do {
            current = try Activity.request(attributes: attrs, contentState: state, pushType: nil)
        } catch {
            print("[Activity] Start error: \(error.localizedDescription)")
        }
    }

    func update(text: String, icon: String, progress: Double = 0, balance: Int = 72) {
        Task {
            let state = NAiceActivityAttributes.ContentState(statusText: text, statusIcon: icon, progressValue: progress, balanceScore: balance)
            await current?.update(using: state)
        }
    }

    func end() {
        Task { await current?.end(dismissalPolicy: .immediate); current = nil }
    }

    var isActive: Bool { current != nil }
}