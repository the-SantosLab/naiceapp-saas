import SwiftUI

// MARK: - Briefing Placeholder (Sci-Fi Style)
struct BriefingPlaceholder: View {
    @Binding var requestedNewChat: NewChatRequest?
    @ObservedObject private var rollup = NARollupService.shared
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.ncCyan.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkle")
                    .font(.title2)
                    .foregroundColor(.ncCyan)
            }

            VStack(spacing: 6) {
                Text("Amelia meldet sich bald")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("Morgen-, Mittags- und Abend-Briefings erscheinen hier, sobald Amelia sie fur dich erstellt.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.ncCyan)
                    Text("Erstelle Briefing...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Button {
                    Task { await generateBriefing() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption)
                        Text("Jetzt Briefing anfordern")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.ncCyan)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.ncCyan.opacity(0.3), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.ncCyan.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }

            if let err = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.ncRose)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.ncRose)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            .clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func generateBriefing() async {
        isGenerating = true
        errorMessage = nil
        do {
            guard let url = URL(string: "https://health.santoslab.de/api/crm/briefing/generate") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["period": "morning"]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode < 400 else {
                throw URLError(.badServerResponse)
            }
            await rollup.fetch()
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
        }
        isGenerating = false
    }
}