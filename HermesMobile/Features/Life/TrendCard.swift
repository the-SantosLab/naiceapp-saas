import SwiftUI

// MARK: - Weekly Trend Section
struct TrendCard: View {
    let recoveryData: [Int]
    let journalCount: Int
    let dealChange: Int
    let workoutCount: Int
    let weekSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("Weekly Trend")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            // 4 Kacheln
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                trendTile(
                    icon: "heart.fill",
                    iconColor: recoveryColor(recoveryData.last ?? 50),
                    value: "Ø \(recoveryData.last ?? 50)%",
                    label: "Recovery",
                    chart: recoveryData
                )
                trendTile(
                    icon: "book.pencil",
                    iconColor: .ncCyan,
                    value: "\(journalCount)",
                    label: "Journal-Einträge",
                    chart: nil
                )
                trendTile(
                    icon: "briefcase.fill",
                    iconColor: .ncAmber,
                    value: "+\(dealChange)",
                    label: "Deals aktiv",
                    chart: nil
                )
                trendTile(
                    icon: "figure.run",
                    iconColor: .ncNeonGreen,
                    value: "\(workoutCount)",
                    label: "Workouts",
                    chart: nil
                )
            }

            // Amelias Wochen-Fazit
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption2)
                    .foregroundColor(.ncCyan.opacity(0.6))
                Text(weekSummary)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineSpacing(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ncCyan.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private func trendTile(icon: String, iconColor: Color, value: String, label: String, chart: [Int]?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                Spacer()
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            if let bars = chart {
                HStack(spacing: 2) {
                    ForEach(bars.indices, id: \.self) { i in
                        let h = max(CGFloat(bars[i]) / 100.0 * 32, 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(recoveryColor(bars[i]).opacity(0.7))
                            .frame(width: 6, height: h)
                    }
                }
                .frame(height: 32, alignment: .bottom)
            }
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.03), lineWidth: 0.5))
    }
}