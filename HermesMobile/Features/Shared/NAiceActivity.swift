import Foundation
import ActivityKit
import SwiftUI

// MARK: - Dynamic Island / Live Activity Attributes
struct NAiceActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
        var statusIcon: String
        var progressValue: Double // 0.0 - 1.0
    }

    var title: String
}

// MARK: - Live Activity / Dynamic Island View
struct NAiceActivityView: View {
    let context: ActivityViewContext<NAiceActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.state.statusIcon)
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(context.state.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if context.state.progressValue > 0 {
                ProgressView(value: context.state.progressValue)
                    .tint(.green)
                    .frame(width: 40)
            }
        }
        .padding(.horizontal, 8)
        .activityBackgroundTint(Color(.systemBackground).opacity(0.7))
    }
}

// MARK: - Dynamic Island Presentation
struct NAiceActivityDynamicIsland: DynamicIsland {
    var context: ActivityViewContext<NAiceActivityAttributes>

    var body: DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
            Image(systemName: context.state.statusIcon)
                .foregroundColor(.green)
        }
        DynamicIslandExpandedRegion(.trailing) {
            Text(context.state.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        DynamicIslandExpandedRegion(.center) {
            Text(context.attributes.title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        DynamicIslandExpandedRegion(.bottom) {
            if context.state.progressValue > 0 {
                ProgressView(value: context.state.progressValue)
                    .tint(.green)
                    .padding(.horizontal)
            }
        }
        DynamicIslandCompactRegion {
            HStack {
                Image(systemName: context.state.statusIcon)
                    .foregroundColor(.green)
                Text(context.state.statusText.prefix(20))
                    .font(.caption2)
            }
        }
        DynamicIslandMinimalRegion {
            Image(systemName: context.state.statusIcon)
                .foregroundColor(.green)
        }
    }
}

// MARK: - Activity Manager
@MainActor
class NAiceActivityManager {
    static let shared = NAiceActivityManager()

    private var currentActivity: Activity<NAiceActivityAttributes>?

    func startAgentActivity(title: String = "nAIce Agent") {
        let attributes = NAiceActivityAttributes(title: title)
        let state = NAiceActivityAttributes.ContentState(
            statusText: "Bereit",
            statusIcon: "n.square.fill",
            progressValue: 0
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("[Activity] Start error: \(error.localizedDescription)")
        }
    }

    func update(statusText: String, icon: String, progress: Double = 0) {
        Task {
            let state = NAiceActivityAttributes.ContentState(
                statusText: statusText,
                statusIcon: icon,
                progressValue: progress
            )
            await currentActivity?.update(using: state)
        }
    }

    func end() {
        Task {
            await currentActivity?.end(dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }

    var isRunning: Bool { currentActivity != nil }
}