import SwiftUI

// MARK: - Amelia Bar (schwebende Kontextleiste)
struct AmeliaBar: View {
    @ObservedObject private var context = AmeliaContextProvider.shared
    @Binding var showSlideUp: Bool

    var body: some View {
        Button {
            showSlideUp = true
        } label: {
            HStack(spacing: 10) {
                // Brain icon
                ZStack {
                    Circle()
                        .fill(Color.ncCyan.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10))
                        .foregroundColor(.ncCyan)
                }

                // Context fact
                Text(context.currentFact)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer(minLength: 0)

                // Context badge
                Text(context.slideUpContext)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.ncCyan.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ncCyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))

                Image(systemName: "chevron.up")
                    .font(.system(size: 8))
                    .foregroundColor(.ncCyan.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.04, green: 0.04, blue: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.ncCyan.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}