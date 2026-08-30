import SwiftUI

struct BriefingView: View {
    @EnvironmentObject var dataStore: WatchDataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Greeting
                Text(dataStore.briefing?.greeting ?? "nAIce")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)

                // Recovery Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: CGFloat(dataStore.whoop.recoveryScore) / 100)
                        .stroke(recoveryColor(dataStore.whoop.recoveryScore),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(dataStore.whoop.recoveryScore)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                        Text("%")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)

                // Stats
                VStack(spacing: 6) {
                    statRow("❤️", "HRV", "\(Int(dataStore.whoop.hrv))", .pink)
                    statRow("💓", "RHR", "\(dataStore.whoop.rhr)", .red)
                    statRow("🌙", "Schlaf", String(format: "%.1fh", dataStore.whoop.sleepHours), .blue)
                    statRow("⚡", "Strain", String(format: "%.1f", dataStore.whoop.strain), .orange)
                }

                Divider().background(.gray.opacity(0.3))

                // Tasks & Habits
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(dataStore.briefing?.tasksOpen ?? 0)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.cyan)
                        Text("Tasks").font(.caption2).foregroundColor(.gray)
                    }
                    VStack(spacing: 4) {
                        Text("\(dataStore.briefing?.habitsUndone ?? 0)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.orange)
                        Text("Habits").font(.caption2).foregroundColor(.gray)
                    }
                    VStack(spacing: 4) {
                        Text("\(dataStore.briefing?.dealsActive ?? 0)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.green)
                        Text("Deals").font(.caption2).foregroundColor(.gray)
                    }
                }

                if let suggestion = dataStore.briefing?.suggestion {
                    Text(suggestion)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                Text("Stand: \(dataStore.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "–")")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }

    private func statRow(_ icon: String, _ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(icon).font(.caption)
            Text(label).font(.caption).foregroundColor(.gray)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundColor(color)
        }
    }

    private func recoveryColor(_ score: Int) -> Color {
        if score >= 67 { return .green }
        if score >= 34 { return .orange }
        return .red
    }
}