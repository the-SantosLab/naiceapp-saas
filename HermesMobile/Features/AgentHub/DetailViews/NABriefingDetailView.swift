import SwiftUI

// MARK: - Briefing Detail View (Sci-Fi Style)
struct NABriefingDetailView: View {
    let briefing: NABriefing
    @Binding var requestedNewChat: NewChatRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(periodColor.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: periodIcon)
                                .font(.title3)
                                .foregroundColor(periodColor)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(briefing.title ?? "Briefing")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.ncWhite)
                                .lineLimit(2)
                            Text(periodLabel)
                                .font(.caption)
                                .foregroundColor(.ncGray)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ncSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient(gradient: Gradient(colors: [.white.opacity(0.1), .white.opacity(0.02), .clear]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )

                // Body
                VStack(alignment: .leading, spacing: 12) {
                    Text(briefing.body ?? "")
                        .font(.body)
                        .foregroundColor(.ncWhite.opacity(0.85))
                        .textSelection(.enabled)
                        .lineSpacing(6)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ncSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )

                // Actions
                VStack(spacing: 12) {
                    Button {
                        shareBriefing()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Teilen")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.ncCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.ncCyan.opacity(0.3), lineWidth: 1)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.ncCyan.opacity(0.06))
                        )
                    }

                    Button {
                        let context = "Ich habe gerade mein Briefing gelesen: \(briefing.title ?? "")\n\n\(briefing.body ?? "")\n\nWas denkst du dazu?"
                        requestedNewChat = NewChatRequest(
                            profileName: "santos-copilot",
                            initialDraft: context
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                            Text("Mit Amelia chatten")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.ncCyan, Color.ncCyan.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Briefing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var periodIcon: String {
        switch briefing.period {
        case "morning": return "sunrise.fill"
        case "midday": return "sun.max.fill"
        case "evening": return "moon.stars.fill"
        default: return "doc.text"
        }
    }

    private var periodColor: Color {
        switch briefing.period {
        case "morning": return .ncAmber
        case "midday": return .ncNeonGreen
        case "evening": return .ncCyan
        default: return .ncGray
        }
    }

    private var periodLabel: String {
        switch briefing.period {
        case "morning": return "Morgen-Briefing"
        case "midday": return "Mittags-Update"
        case "evening": return "Abend-Briefing"
        default: return "Briefing"
        }
    }

    private func shareBriefing() {
        let text = "\(briefing.title ?? "")\n\n\(briefing.body ?? "")"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let root = window.rootViewController {
            root.present(av, animated: true)
        }
    }
}