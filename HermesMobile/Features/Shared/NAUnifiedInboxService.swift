import Foundation
import SwiftUI

// MARK: - Unified Inbox Models
struct NAUnifiedInboxItem: Identifiable, Codable {
    var id = UUID().uuidString
    let source: String // "whatsapp", "imessage", "telegram", "system"
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

        // Sort by date descending
        allItems.sort { $0.date > $1.date }
        items = allItems
        isLoading = false
    }

    func markRead(_ id: String) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isRead = true
        }
    }

    func sendReply(to item: NAUnifiedInboxItem, text: String) -> Bool {
        switch item.source {
        case "whatsapp":
            // Open WhatsApp
            let urlStr = "https://wa.me/\(item.contactName)"
            if let url = URL(string: urlStr) {
                UIApplication.shared.open(url)
                return true
            }
        case "imessage":
            if let url = URL(string: "sms:") {
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
        let urgent = items.filter { $0.urgency == "high" && !$0.isRead }.count

        var parts: [String] = []
        if wa > 0 { parts.append("\(wa) WhatsApp") }
        if im > 0 { parts.append("\(im) iMessage") }
        if urgent > 0 { parts.append("\(urgent) dringend") }

        return parts.isEmpty ? "Keine neuen Nachrichten" : parts.joined(separator: " · ")
    }
}