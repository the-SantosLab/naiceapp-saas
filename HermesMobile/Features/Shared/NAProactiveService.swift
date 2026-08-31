import Foundation
import SwiftUI

// MARK: - Proactive Suggestion Engine
@MainActor
class NAProactiveService: ObservableObject {
    static let shared = NAProactiveService()

    @Published var suggestions: [NASuggestion] = []
    @Published var briefing: String = ""

    private let rollup = NARollupService.shared
    private let finance = NAFinanceService.shared
    private let calendar = CalendarManager.shared
    private let contacts = NAContactService.shared
    private let waVM = WhatsAppViewModel.shared
    
    @Published var archivedIDs: [String] = [] {
        didSet { UserDefaults.standard.set(archivedIDs, forKey: "na_archived_suggestions") }
    }
    
    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: "na_archived_suggestions") {
            archivedIDs = saved
        }
    }
    
    var archivedSuggestions: [NASuggestion] {
        suggestions.filter { archivedIDs.contains($0.archiveId) }
    }
    var activeSuggestions: [NASuggestion] {
        suggestions.filter { !archivedIDs.contains($0.archiveId) }
    }
    
    func archiveSuggestion(_ id: String) {
        if !archivedIDs.contains(id) {
            archivedIDs.append(id)
        }
    }
    
    func unarchiveSuggestion(_ id: String) {
        archivedIDs.removeAll { $0 == id }
    }
    
    func generate() {
        var newSuggestions: [NASuggestion] = []
        let now = Date()

        // 1. Calendar: upcoming events
        for event in calendar.upcomingEvents.prefix(2) {
            let timeUntil = event.startDate.timeIntervalSince(now)
            if timeUntil > 0 && timeUntil < 86400 { // within 24h
                newSuggestions.append(NASuggestion(
                    icon: "calendar.badge.clock",
                    title: "Termin: \(event.title)",
                    subtitle: "\(event.startDate.formatted(date: .numeric, time: .shortened))",
                    action: "erinnern",
                    priority: .high,
                archiveId: "sug_erinnern",
                ))
            }
        }

        // 2. WhatsApp: unreplied
        let unread = waVM.unrepliedChats.prefix(3)
        for chat in unread {
            newSuggestions.append(NASuggestion(
                icon: "message.fill",
                title: "\(chat.contact) schreibt",
                subtitle: chat.lastIncomingText ?? "Nachricht gelesen?",
                action: "whatsapp_\(chat.id)",
                priority: chat.urgency == .red ? .high : .medium,
                archiveId: "sug_wa_\(chat.id)"
            ))
        }

        // 3. Contacts: reachout due
        let due = contacts.reachoutDue.prefix(3)
        for contact in due {
            if let days = contact.daysSinceContacted {
                newSuggestions.append(NASuggestion(
                    icon: "bell.fill",
                    title: "\(contact.fullName) vermisst dich",
                    subtitle: "\(days) Tage kein Kontakt",
                    action: "contact_\(contact.id)",
                    priority: days > 30 ? .high : .medium,
                archiveId: "sug_contact_\(contact.id)"
                ))
            }
        }

        // 4. Finance: budget warning
        for (cat, spent, limit, pct) in finance.categorySpending {
            if pct > 85 && limit > 0 {
                newSuggestions.append(NASuggestion(
                    icon: "exclamationmark.triangle.fill",
                    title: "Budget \(NAFinanceService.categoryLabel(cat)) fast aufgebraucht",
                    subtitle: "\(Int(spent))/\(Int(limit))€ (\(Int(pct))%)",
                    action: "budget_\(cat)",
                    priority: pct > 95 ? .high : .medium,
                archiveId: "sug_budget_\(cat)"
                ))
            }
        }

        // 5. Finance: income detected
        let recentIncome = finance.incomeEntries.prefix(1)
        if let income = recentIncome.first {
            newSuggestions.append(NASuggestion(
                icon: "arrow.down.circle.fill",
                title: "Zahlung eingegangen: \(Int(income.amount))€",
                subtitle: income.note,
                action: "income",
                priority: .medium,
                archiveId: "sug_income"
            ))
        }

        // 6. Health: low recovery
        if let whoop = rollup.whoop, let rec = whoop.recovery, rec.score ?? 0 < 40 {
            newSuggestions.append(NASuggestion(
                icon: "heart.fill",
                title: "Heute schonen! Recovery nur \(rec.score ?? 0)%",
                subtitle: "HRV: \(rec.hrv ?? 0) ms · RHR: \(rec.rhr ?? 0) bpm",
                action: "health",
                priority: .high,
                archiveId: "sug_health"
            ))
        }

        // 7. Journal: no entry today
        let weekCount = rollup.journal?.this_week ?? 0
        if weekCount == 0 {
            newSuggestions.append(NASuggestion(
                icon: "pencil",
                title: "Kein Journal-Eintrag heute",
                subtitle: "Kurze Reflexion: Was war gut?",
                action: "journal",
                priority: .low,
                archiveId: "sug_journal"
            ))
        }

        // 8. Birthday upcoming
        let bdays = contacts.upcomingBirthdays.prefix(2)
        for (contact, days, _) in bdays {
            newSuggestions.append(NASuggestion(
                icon: "star.fill",
                title: "\(contact.fullName) hat bald Geburtstag",
                subtitle: days == 0 ? "Heute!" : "in \(days) Tagen",
                action: "birthday_\(contact.id)",
                priority: days <= 3 ? .high : .medium,
                archiveId: "sug_birthday_\(contact.id)"
            ))
        }

        suggestions = newSuggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    func generateBriefing() -> String {
        var parts: [String] = []
        let now = Date()

        // Weather
        if let w = NAWeatherService.shared.weather {
            parts.append("\(Int(w.temperature))°C · \(w.condition)")
        }

        // Events
        let eventCount = calendar.todayEvents.count
        if eventCount > 0 {
            parts.append("\(eventCount) Termin(e) heute")
        } else {
            parts.append("Keine Termine heute")
        }

        // Tasks
        if let tasks = rollup.tasks, tasks.active > 0 {
            parts.append("\(tasks.active) Aufgabe(n) offen")
        }

        // Health
        let health = HealthManager.shared
        if health.steps > 0 {
            parts.append("\(health.steps) Schritte")
        }
        if let whoop = rollup.whoop, let rec = whoop.recovery {
            parts.append("Recovery \(rec.score ?? 0)%")
        }

        // WhatsApp
        let unread = waVM.unrepliedChats.count
        if unread > 0 {
            parts.append("\(unread) WhatsApp offen")
        }

        briefing = parts.joined(separator: " · ")
        return briefing
    }

    func scheduleBriefing() {
        // Schedule local notification for 7:00
        var components = DateComponents()
        components.hour = 7
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "☀️ Guten Morgen, Johannes"
        content.body = generateBriefing()
        content.sound = .default
        content.userInfo = ["type": "briefing"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "naice_morning_briefing", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Proactive] Briefing schedule failed: \(error.localizedDescription)")
            } else {
                print("[Proactive] Morning briefing scheduled for 7:00 daily")
            }
        }
    }
}

// MARK: - Suggestion Model
struct NASuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let action: String
    let priority: SuggestionPriority
    let archiveId: String
}

enum SuggestionPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: SuggestionPriority, rhs: SuggestionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Suggestion Card View
struct NASuggestionCard: View {
    let suggestion: NASuggestion
    var onTap: (() -> Void)?
    var onArchive: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorForPriority.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: suggestion.icon)
                    .font(.system(size: 12))
                    .foregroundColor(colorForPriority)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                Text(suggestion.subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            if let onArchive = onArchive {
                Button {
                    onArchive()
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }

            priorityDot
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        .onTapGesture { onTap?() }
    }

    private var colorForPriority: Color {
        switch suggestion.priority {
        case .high: return .ncRose
        case .medium: return .ncAmber
        case .low: return .ncCyan
        }
    }

    private var priorityDot: some View {
        Circle()
            .fill(colorForPriority)
            .frame(width: 6, height: 6)
    }
}