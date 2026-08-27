import SwiftUI

// MARK: - Chat Message Model
struct NAChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
    let timestamp = Date()
}

// MARK: - nAIce Chat View (Native! Telegram Replacement)
struct NAIceChatView: View {
    @State private var messages: [NAChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var sessionId: String? = nil
    @State private var showScrollButton = false
    @State private var scrollToBottom = false
    @FocusState private var isFocused: Bool

    let serverURL = "http://192.168.178.105:8999/api/naice/chat"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amelia")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                    Text(isLoading ? "Denkt nach..." : "Online")
                        .font(.caption)
                        .foregroundColor(isLoading ? .ncAmber : .ncNeonGreen)
                }
                Spacer()
                if !messages.isEmpty {
                    Button {
                        withAnimation { messages.removeAll(); sessionId = nil }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.02, green: 0.02, blue: 0.04))

            Divider().background(Color.white.opacity(0.06))

            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        if messages.isEmpty {
                            VStack(spacing: 16) {
                                Spacer().frame(height: 60)
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.3))
                                Text("Chatte mit Amelia")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.white)
                                Text("Ich hab Zugriff auf alle deine Daten:\nWHOOP, Kalender, CRM, Business, E-Mails, Mac\n\nFrag mich was du brauchst!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }

                        ForEach(messages) { msg in
                            NAChatBubble(message: msg)
                                .id(msg.id)
                        }

                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.7).tint(.ncCyan)
                                Text("Amelia schreibt...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.leading, 56)
                            .padding(.vertical, 4)
                        }

                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color.black)
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            // Input
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.06))
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10))
                            .foregroundColor(.ncCyan.opacity(0.6))
                        TextField("Nachricht an Amelia...", text: $inputText)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .focused($isFocused)
                            .onSubmit { sendMessage() }
                            .disabled(isLoading)
                    }
                    .padding(10)
                    .background(Color(red: 0.04, green: 0.04, blue: 0.08), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.5))

                    Button { sendMessage() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? .gray : .ncCyan)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.02, green: 0.02, blue: 0.04))
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        messages.append(NAChatMessage(role: "user", content: text))
        inputText = ""
        isLoading = true

        var payload: [String: Any] = ["message": text]
        if let sid = sessionId { payload["session_id"] = sid }

        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        req.timeoutInterval = 180

        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data,
                      let result = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
                    messages.append(NAChatMessage(role: "assistant", content: "Fehler: \(error?.localizedDescription ?? "Keine Antwort vom Server")"))
                    return
                }
                sessionId = result.session_id
                messages.append(NAChatMessage(role: "assistant", content: result.response))
            }
        }.resume()
    }
}

// MARK: - Chat Response
struct ChatResponse: Codable {
    let ok: Bool
    let session_id: String?
    let response: String
}

// MARK: - Chat Bubble
struct NAChatBubble: View {
    let message: NAChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == "assistant" {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.ncCyan.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundColor(.ncCyan)
                }
                .padding(.top, 2)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == "user" ?
                        Color.ncCyan.opacity(0.15) :
                        Color(red: 0.03, green: 0.03, blue: 0.06),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(message.role == "user" ? Color.ncCyan.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 0.5)
                    )

                HStack(spacing: 4) {
                    if message.role == "user" {
                        Text("Du")
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.7))
                    } else {
                        Text("Amelia")
                            .font(.system(size: 8))
                            .foregroundColor(.ncCyan.opacity(0.7))
                    }
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal, 4)
            }

            if message.role == "user" {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.ncNeonGreen.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.ncNeonGreen)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 4)
    }
}