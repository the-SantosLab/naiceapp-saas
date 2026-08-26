import Foundation
import SwiftUI

// MARK: - Unified Inbox Models
struct NAUnifiedInboxItem: Identifiable, Codable {
    var id = UUID().uuidString
    let source: String // "whatsapp", "imessage", "email", "telegram", "system"
    let contactName: String
    let preview: String
    let fullText: String?
    let date: Date
    var isRead: Bool = false
    var isOutgoing: Bool = false
    var urgency: String = "low" // "low", "medium", "high"
}

// MARK: - Unified Inbox Service
@MainActor
class NAUnifiedInboxService: ObservableObject {
    static let shared = NAUnifiedInboxService()

    @Published var items: [NAUnifiedInboxItem] = []
    @Published var isLoading = false

    var unreadCount: Int { items.filter { !$0.isRead }.count }

    private let waVM = WhatsAppViewModel.shared
    private let emailService = NAEmailService.shared

    func refresh() async {
        isLoading = true

        var allItems: [NAUnifiedInboxItem] = []

        // WhatsApp
        let unreplied = waVM.unrepliedChats
        for chat in unreplied {
            let urgency: String
            switch chat.urgency {
            case .red: urgency = "high"
            case .yellow: urgency = "medium"
            default: urgency = "low"
            }
            allItems.append(NAUnifiedInboxItem(
                source: "whatsapp",
                contactName: chat.contact,
                preview: chat.lastIncomingText ?? "Neue Nachricht",
                fullText: chat.lastIncomingText,
                date: Date(),
                isRead: false,
                urgency: urgency
            ))
        }

        // iMessage (mock for now - real integration needs entitlement)
        allItems.append(NAUnifiedInboxItem(
            source: "imessage",
            contactName: "iMessage",
            preview: "\(allItems.count) Nachrichten ausstehend",
            fullText: nil,
            date: Date(),
            isRead: false,
            urgency: "low"
        ))

        // Emails
        await emailService.fetchEmails()
        for email in emailService.emails {
            allItems.append(NAUnifiedInboxItem(
                source: "email",
                contactName: email.sender,
                preview: email.subject + " – " + email.preview,
                fullText: email.preview,
                date: email.date,
                isRead: email.isRead,
                urgency: email.urgency
            ))
        }

        // Sort by date descending
        allItems.sort { $0.date > $1.date }
        items = allItems
        isLoading = false
    }

    func markRead(_ id: String) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isRead = true
            let item = items[idx]
            if item.source == "email" {
                emailService.markRead(item.id)
            }
        }
    }

    func sendReply(to item: NAUnifiedInboxItem, text: String) -> Bool {
        switch item.source {
        case "whatsapp":
            if let url = URL(string: "https://wa.me/\(item.contactName)") {
                UIApplication.shared.open(url)
                return true
            }
        case "imessage":
            if let url = URL(string: "sms:") {
                UIApplication.shared.open(url)
                return true
            }
        case "email":
            if let url = URL(string: "mailto:") {
                UIApplication.shared.open(url)
                return true
            }
        default:
            break
        }
        return false
    }

    func getBriefingSummary() -> String {
        let wa = items.filter { $0.source == "whatsapp" && !$0.isRead }.count
        let im = items.filter { $0.source == "imessage" && !$0.isRead }.count
        let email = items.filter { $0.source == "email" && !$0.isRead }.count
        let urgent = items.filter { $0.urgency == "high" && !$0.isRead }.count

        var parts: [String] = []
        if wa > 0 { parts.append("\(wa) WhatsApp") }
        if im > 0 { parts.append("\(im) iMessage") }
        if email > 0 { parts.append("\(email) E-Mails") }
        if urgent > 0 { parts.append("\(urgent) dringend") }

        return parts.isEmpty ? "Keine neuen Nachrichten" : parts.joined(separator: " · ")
    }
}