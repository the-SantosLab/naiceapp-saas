import SwiftUI

struct ChatView: View {
    @State private var message = ""
    @State private var response: String?
    @State private var isLoading = false
    @State private var showResponse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Agent fragen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                // Quick Actions
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    quickButton("Recovery", "heart.fill", .pink) {
                        sendMessage("Wie ist meine Recovery?")
                    }
                    quickButton("Briefing", "sun.max.fill", .orange) {
                        sendMessage("Was ist mein Status heute?")
                    }
                    quickButton("Tasks", "checklist", .cyan) {
                        sendMessage("Welche Tasks sind offen?")
                    }
                    quickButton("Journal", "note.text", .green) {
                        sendMessage("Schreib einen Journal-Eintrag: Heute war...")
                    }
                }

                // Microphone input
                if !isLoading {
                    HStack(spacing: 8) {
                        TextField("Sag was...", text: $message)
                            .font(.system(size: 12))
                            .padding(10)
                            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                        Button {
                            let msg = message
                            message = ""
                            sendMessage(msg)
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(message.isEmpty ? .gray : .cyan)
                        }
                        .buttonStyle(.plain)
                        .disabled(message.isEmpty)
                    }
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.vertical, 10)
                }

                if let resp = response, showResponse {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text("nAIce").font(.caption2.weight(.semibold)).foregroundColor(.cyan)
                        }
                        Text(resp)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .lineLimit(15)

                        Button("Schließen") {
                            withAnimation { showResponse = false }
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
                }
            }
            .padding()
        }
    }

    private func quickButton(_ label: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        isLoading = true
        response = nil
        showResponse = false

        Task {
            let result = await WatchConnectivityManager.shared.sendChatMessage(text)
            await MainActor.run {
                isLoading = false
                if let r = result {
                    response = r
                    withAnimation { showResponse = true }
                } else {
                    response = "iPhone nicht verbunden.\nBitte nAIce auf dem iPhone öffnen."
                    withAnimation { showResponse = true }
                }
            }
        }
    }
}