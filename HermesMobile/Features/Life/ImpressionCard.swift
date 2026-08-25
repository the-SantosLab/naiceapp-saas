import SwiftUI

// MARK: - Amelias Tages-Impression
struct ImpressionCard: View {
    let text: String
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.ncCyan.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkle")
                        .font(.system(size: 12))
                        .foregroundColor(.ncCyan)
                }
                Text("Amelias Impression")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7).tint(.ncCyan)
                    Text("Analysiere deine Daten...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                    .lineLimit(4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.ncCyan.opacity(0.15), .white.opacity(0.03), .clear]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}