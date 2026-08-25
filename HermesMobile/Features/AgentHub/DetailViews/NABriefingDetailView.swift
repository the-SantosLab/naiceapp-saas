import SwiftUI

// MARK: - Briefing Detail View
struct NABriefingDetailView: View {
    let briefing: NABriefing
    @Binding var requestedNewChat: NewChatRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: periodIcon)
                            .font(.title2)
                            .foregroundColor(periodColor)
                        Text(briefing.title ?? "Briefing")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.ncDark)
                    }
                    Text(periodLabel)
                        .font(.caption)
                        .foregroundColor(.ncMuted)
                }.warmCard()

                // Body
                VStack(alignment: .leading, spacing: 12) {
                    Text(briefing.body ?? "")
                        .font(.body)
                        .foregroundColor(.ncDark)
                        .textSelection(.enabled)
                }.warmCard()

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
                        .foregroundColor(.ncGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.ncGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ncGreen.opacity(0.15)))
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
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.ncGreen, in: RoundedRectangle(cornerRadius: 12))
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
        case "morning": return .ncGold
        case "midday": return .ncGreen
        case "evening": return .ncSage
        default: return .ncMuted
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