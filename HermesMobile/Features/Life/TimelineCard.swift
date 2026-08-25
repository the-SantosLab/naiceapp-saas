import SwiftUI

// MARK: - Nächste 24h Timeline
struct TimelineCard: View {
    let items: [TimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("Nächste 24h")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(items.isEmpty ? "Keine Einträge" : "\(items.count) Einträge")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if items.isEmpty {
                Text("Keine anstehenden Termine oder Aufgaben in den nächsten 24 Stunden.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        // Time column
                        VStack(spacing: 4) {
                            Text(item.time)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 60, alignment: .trailing)
                            if item.detail != nil {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 1, height: 20)
                            }
                        }

                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.iconColor.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: item.icon)
                                .font(.system(size: 11))
                                .foregroundColor(item.iconColor)
                        }

                        // Text
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.text)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if let d = item.detail {
                                Text(d)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
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
}