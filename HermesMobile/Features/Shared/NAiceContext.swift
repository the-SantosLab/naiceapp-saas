import Foundation
import SwiftUI

// MARK: - nAIce Neural Core – zentraler Kontext-Manager
@MainActor
class NAiceContext: ObservableObject {
    static let shared = NAiceContext()

    // Alle Dienste
    let health = HealthManager.shared
    let calendar = CalendarManager.shared
    let contacts = NAContactService.shared
    let rollup = NARollupService.shared
    let journal = NAJournalService.shared
    let weather = NAWeatherService.shared
    let routines = NARoutineService.shared
    let waVM = WhatsAppViewModel.shared

    // Status
    var lastRefresh: Date = .distantPast
    var isLoading = false

    // MARK: - Verknüpfte Erkenntnisse
    var morningBriefing: String {
        var parts: [String] = []

        // Schlaf
        if let w = rollup.whoop?.sleep {
            let h = w.net_hours
            if h < 5 { parts.append("😴 Nur \(String(format: "%.1f", h))h Schlaf – heute ruhiger?") }
            else if h < 7 { parts.append("😴 \(String(format: "%.1f", h))h Schlaf – okay, aber mehr wäre gut.") }
            else { parts.append("😴 \(String(format: "%.1f", h))h Schlaf – gut erholt!") }
        }

        // Wetter
        if let w = weather.weather {
            parts.append("\(w.iconName) \(Int(w.temperature))°C, \(w.condition) in \(w.locationName)")
        }

        // Termine
        let eventCount = calendar.upcomingEvents.count
        if eventCount > 0 {
            let next = calendar.upcomingEvents.first!
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            parts.append("📅 \(eventCount) Termin(e) – nächstes: \(next.title) um \(fmt.string(from: next.startDate))")
        } else {
            parts.append("📅Keine Termine heute")
        }

        // WhatsApp
        let waCount = waVM.totalUnread
        if waCount > 0 {
            parts.append("💬 \(waCount) unbeantwortete WhatsApp-Nachrichten")
        }

        // Erinnerungen
        let reminderCount = CalendarManager.shared.remindersCount
        if reminderCount > 0 {
            parts.append("⚠️ \(reminderCount) überfällige Erinnerungen")
        }

        return parts.joined(separator: "\n")
    }

    var lifeBalanceScore: Int {
        var score = 50

        // Schlaf (0-20 Punkte)
        if let sleep = rollup.whoop?.sleep {
            let h = sleep.net_hours
            if h >= 8 { score += 20 }
            else if h >= 7 { score += 15 }
            else if h >= 6 { score += 10 }
            else if h >= 5 { score += 5 }
        }

        // Schritte (0-15 Punkte)
        let steps = health.steps
        if steps > 8000 { score += 15 }
        else if steps > 5000 { score += 10 }
        else if steps > 2000 { score += 5 }

        // Routinen (0-15 Punkte)
        let rCount = routines.completedToday
        let rTotal = routines.routines.count
        if rTotal > 0 {
            score += Int((Double(rCount) / Double(rTotal)) * 15)
        }

        // Workouts (0-10 Punkte)
        if let w = rollup.whoop?.workouts, !w.isEmpty {
            if w.count >= 3 { score += 10 }
            else if w.count >= 1 { score += 5 }
        }

        // WhatsApp erledigt (0-10 Punkte)
        if waVM.totalUnread == 0 { score += 10 }

        return min(max(score, 0), 100)
    }

    var crossInsights: [String] {
        var insights: [String] = []

        // Schlaf + Termine
        if let sleep = rollup.whoop?.sleep, sleep.net_hours < 6 && !calendar.upcomingEvents.isEmpty {
            insights.append("Wenig Schlaf + voller Kalender – heute priorisieren!")
        }

        // Scritte + Wetter
        if let w = weather.weather, health.steps < 2000, w.weatherCode < 30 {
            insights.append("Nur \(health.steps) Schritte bei schönem Wetter – rausgehen?")
        }

        // Gebutstage
        let bdays = contacts.upcomingBirthdays
        for (contact, days, _) in bdays.prefix(2) {
            if days == 0 { insights.append("🎂 \(contact.fullName) hat HEUTE Geburtstag!") }
            else { insights.append("🎂 \(contact.fullName) in \(days) Tagen") }
        }

        // WhatsApp
        if waVM.totalUnread > 0 {
            let names = waVM.unrepliedChats.prefix(3).map { $0.contact }.joined(separator: ", ")
            insights.append("💬 \(waVM.totalUnread) unbeantwortet: \(names)")
        }

        // Routinen
        if routines.completedToday == 0 && !routines.routines.isEmpty {
            insights.append("Heute noch keine Routine erledigt.")
        }

        return insights
    }

    var agentSuggestions: [AgentSuggestion] {
        var suggestions: [AgentSuggestion] = []

        // Schlaf schlecht
        if let sleep = rollup.whoop?.sleep, sleep.net_hours < 5 {
            suggestions.append(AgentSuggestion(
                icon: "moon.zzz.fill",
                title: "Wenig Schlaf",
                text: "Nur \(String(format: "%.1f", sleep.net_hours))h – heute ruhiger angehen lassen?",
                action: .scheduleDowntime
            ))
        }

        // Viele offene WhatsApp
        if waVM.totalUnread > 2 {
            suggestions.append(AgentSuggestion(
                icon: "message.fill",
                title: "WhatsApp-Rückstand",
                text: "\(waVM.totalUnread) Nachrichten unbeantwortet",
                action: .openWhatsApp
            ))
        }

        // Keine Bewegung
        if health.steps < 1000 && Date().hour >= 14 {
            suggestions.append(AgentSuggestion(
                icon: "figure.walk",
                title: "Bewegung?",
                text: "Nur \(health.steps) Schritte – kurzer Spaziergang?",
                action: .suggestWalk
            ))
        }

        // Geburtstag heute
        for (contact, days, _) in contacts.upcomingBirthdays {
            if days == 0 {
                suggestions.append(AgentSuggestion(
                    icon: "gift.fill",
                    title: "🎂 \(contact.fullName)",
                    text: "Heute Geburtstag! Kurze Nachricht schicken?",
                    action: .celebrateBirthday(contactId: contact.id)
                ))
            }
        }

        return suggestions
    }
}

// MARK: - Agent Suggestion Model
struct AgentSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let action: AgentAction
}

enum AgentAction {
    case scheduleDowntime
    case openWhatsApp
    case suggestWalk
    case celebrateBirthday(contactId: String)
    case openJournal
    case checkCalendar
}

// MARK: - Date Helper
extension Date {
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }
}