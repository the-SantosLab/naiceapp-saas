import Foundation
import SwiftUI
import MessageUI

// MARK: - Email Model
struct NAEmailItem: Identifiable, Codable {
    var id: String
    let subject: String
    let sender: String
    let preview: String
    let date: Date
    var isRead: Bool
    let urgency: String

    enum CodingKeys: String, CodingKey {
        case id, subject, sender, preview, date, isRead, urgency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        subject = try container.decode(String.self, forKey: .subject)
        sender = try container.decode(String.self, forKey: .sender)
        preview = try container.decode(String.self, forKey: .preview)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        urgency = try container.decodeIfPresent(String.self, forKey: .urgency) ?? "low"

        // Parse ISO date
        let dateStr = try container.decode(String.self, forKey: .date)
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: dateStr) {
            date = d
        } else {
            fmt.formatOptions = [.withInternetDateTime]
            if let d = fmt.date(from: dateStr) {
                date = d
            } else {
                let f2 = DateFormatter()
                f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f2.locale = Locale(identifier: "en_US_POSIX")
                date = f2.date(from: dateStr) ?? Date()
            }
        }
    }

    init(id: String, subject: String, sender: String, preview: String, date: Date, isRead: Bool, urgency: String) {
        self.id = id
        self.subject = subject
        self.sender = sender
        self.preview = preview
        self.date = date
        self.isRead = isRead
        self.urgency = urgency
    }
}

// MARK: - Email Inbox Response
struct NAEmailInbox: Codable {
    let emails: [NAEmailItem]
    let fetched_at: String?
    let is_mock: Bool?
}

// MARK: - Email Service
@MainActor
class NAEmailService: ObservableObject {
    static let shared = NAEmailService()

    @Published var emails: [NAEmailItem] = []
    @Published var isLoading = false
    @Published var isConfigured = false
    @Published var lastError: String?

    private let serverURL = "https://health.santoslab.de/api/naice/emails"

    func fetchEmails() async {
        guard let url = URL(string: serverURL) else { return }
        isLoading = true

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let inbox = try JSONDecoder().decode(NAEmailInbox.self, from: data)
            emails = inbox.emails
            isConfigured = !(inbox.is_mock ?? true)
            isLoading = false
        } catch {
            print("[Email] Fetch error: \(error)")
            isLoading = false
            lastError = error.localizedDescription
        }
    }

    func markRead(_ id: String) {
        if let idx = emails.firstIndex(where: { $0.id == id }) {
            emails[idx].isRead = true
        }
    }

    var unreadCount: Int {
        emails.filter { !$0.isRead }.count
    }

    func openMailApp() {
        if let url = URL(string: "message://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Email Account Config View
struct NAEmailConfigView: View {
    @State private var server = "imap.ionos.de"
    @State private var username = ""
    @State private var password = ""
    @State private var isSaving = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("IMAP-Server")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.gray)
                        TextField("z.B. imap.gmx.net", text: $server)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("E-Mail-Adresse")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.gray)
                        TextField("z.B. johannes@naice.app", text: $username)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(12)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Passwort")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.gray)
                        SecureField("IMAP-Passwort", text: $password)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    }
                }
                .padding(.horizontal, 20)

                Button {
                    saveConfig()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving { ProgressView().scaleEffect(0.6).tint(.white) }
                        Text(isSaving ? "Speichern..." : "Speichern & Testen")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(username.isEmpty || password.isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(username.isEmpty || password.isEmpty || isSaving)
                .padding(.horizontal, 20)

                if saved {
                    Text("✅ Gespeichert. E-Mails werden alle 15 Minuten abgerufen.")
                        .font(.caption)
                        .foregroundColor(.ncNeonGreen)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .padding(.top, 24)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("E-Mail-Konto")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func saveConfig() {
        isSaving = true
        guard let url = URL(string: "https://health.santoslab.de/api/naice/email-config") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["server": server, "port": 993, "username": username, "password": password]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { _, _, error in
            DispatchQueue.main.async {
                isSaving = false
                saved = error == nil
                if error != nil {
                    print("[EmailConfig] Error: \(error!.localizedDescription)")
                }
            }
        }.resume()
    }
}