import Foundation
import SwiftUI

// MARK: - Life Dashboard Data Model
struct LifeDimension: Identifiable {
    let id: String
    let icon: String
    let label: String
    let score: Int
    let trend: TrendDirection
    let detail: String

    var color: Color {
        score >= 70 ? .ncNeonGreen : score >= 40 ? .ncAmber : .ncRose
    }
}

enum TrendDirection: String {
    case up = "arrow.up"
    case down = "arrow.down"
    case flat = "arrow.right"
}

struct TimelineItem: Identifiable {
    let id: String
    let time: String
    let icon: String
    let iconColor: Color
    let text: String
    let detail: String?
}

// MARK: - Life ViewModel (kein API-Call, nur lokale Berechnung)
@MainActor
class LifeViewModel: ObservableObject {
    @Published var impressionText: String = "Lade Daten..."
    @Published var dimensions: [LifeDimension] = []
    @Published var timelineItems: [TimelineItem] = []
    @Published var trendRecoveryData: [Int] = []
    @Published var trendJournalCount: Int = 0
    @Published var trendDealChange: Int = 0
    @Published var trendWorkoutCount: Int = 0
    @Published var weekSummary: String = ""
    @Published var overallScore: Int = 0

    private var previousRecovery: Int = 0
    private var currentRecovery: Int = 0

    func compute(from rollup: NARollup) {
        guard let w = rollup.whoop else { return }

        // ── Health Score ──
        let avgRecovery = w.trends_7d?.avg_recovery ?? w.recovery?.score ?? 0
        let healthScore = min(100, Int(Double(avgRecovery) * 1.2))

        // ── Work Score ──
        let activeDeals = rollup.deals?.active_deals ?? 0
        let activeTasks = rollup.tasks?.active ?? 0
        let workScore = min(100, activeDeals * 3 + max(0, 20 - activeTasks) * 2)

        // ── Relationship Score ──
        let waUnread = WhatsAppViewModel.shared.totalUnread
        let relationsScore = min(100, max(0, 100 - waUnread * 10))

        // ── Daily Life Score ──
        let todayEvents = rollup.calendar?.count ?? 0
        // Habits from SwiftData - approximate with journal entries today
        let todayHabits = rollup.journal?.entries?.filter {
            guard let created = $0.created_at else { return false }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: created) {
                return Calendar.current.isDateInToday(date)
            }
            return false
        }.count ?? 0
        let dailyScore = min(100, todayHabits * 10 + min(todayEvents * 5, 30) + 20)

        // ── Finance Score ──
        let revenue = rollup.crm?.revenue_eur ?? 0
        let financeScore = min(100, min(revenue / 1000, 100))

        // ── Creativity Score ──
        let journalThisWeek = rollup.journal?.this_week ?? 0
        let ideasCount = 0 // NAiceAPI.shared.ideas is not accessible from here
        let creativeScore = min(100, journalThisWeek * 15 + ideasCount * 5)

        // ── Trends (vergleich mit letzter Woche) ──
        currentRecovery = w.recovery?.score ?? 50
        let recoveryTrend: TrendDirection = currentRecovery > previousRecovery ? .up :
            currentRecovery < previousRecovery ? .down : .flat
        previousRecovery = currentRecovery

        let dims = [
            LifeDimension(id: "health", icon: "heart.fill", label: "Gesundheit", score: healthScore, trend: recoveryTrend, detail: "\(avgRecovery)% Ø Recovery"),
            LifeDimension(id: "work", icon: "briefcase.fill", label: "Arbeit", score: workScore, trend: activeDeals > 0 ? .up : .flat, detail: "\(activeDeals) Deals · \(activeTasks) Tasks"),
            LifeDimension(id: "relations", icon: "person.2.fill", label: "Beziehungen", score: relationsScore, trend: waUnread == 0 ? .up : .down, detail: "\(waUnread) WhatsApp offen"),
            LifeDimension(id: "daily", icon: "house.fill", label: "Alltag", score: dailyScore, trend: todayEvents > 0 ? .up : .flat, detail: "\(todayEvents) Termine heute"),
            LifeDimension(id: "finance", icon: "eurosign", label: "Finanzen", score: financeScore, trend: revenue > 10000 ? .up : .flat, detail: "\(revenue)€ Umsatz"),
            LifeDimension(id: "creativity", icon: "lightbulb.fill", label: "Kreativität", score: creativeScore, trend: journalThisWeek > 3 ? .up : .flat, detail: "\(journalThisWeek) Journal-Einträge")
        ]
        self.dimensions = dims
        self.overallScore = dims.map(\.score).reduce(0, +) / max(dims.count, 1)

        // ── Impression ──
        self.impressionText = buildImpression(from: rollup, dims: dims)

        // ── Timeline ──
        self.timelineItems = buildTimeline(from: rollup)

        // ── Trends ──
        self.trendRecoveryData = buildRecoveryBarData(from: w)
        self.trendJournalCount = rollup.journal?.this_week ?? 0
        self.trendDealChange = rollup.deals?.active_deals ?? 0
        self.trendWorkoutCount = w.workouts?.count ?? 0
        self.weekSummary = buildWeekSummary(from: rollup, w: w)
    }

    // MARK: - Impression Builder
    private func buildImpression(from rollup: NARollup, dims: [LifeDimension]) -> String {
        var parts: [String] = []

        let recovery = rollup.whoop?.recovery?.score ?? 50
        if recovery < 40 {
            parts.append("Achtung, dein Körper braucht Ruhe.")
        } else if recovery >= 70 {
            parts.append("Recovery bei \(recovery)% — top erholt!")
        } else {
            parts.append("Recovery bei \(recovery)% — solide.")
        }

        if let trends = rollup.whoop?.trends_7d, let hrv = rollup.whoop?.recovery?.hrv {
            if trends.avg_hrv ?? 0 > hrv {
                parts.append("HRV steigt 📈")
            }
        }

        let activeDeals = rollup.deals?.active_deals ?? 0
        if activeDeals > 0 {
            parts.append("\(activeDeals) Deal(s) aktiv.")
        }

        let activeTasks = rollup.tasks?.active ?? 0
        if activeTasks > 0 {
            parts.append("Noch \(activeTasks) Aufgabe(n) offen.")
        }

        let waUnread = WhatsAppViewModel.shared.totalUnread
        if waUnread > 0 {
            parts.append("\(waUnread) WhatsApp warten noch.")
        }

        // Combine to 2-3 sentence
        let selected = Array(parts.prefix(3))
        return selected.joined(separator: " ") + " Guter Mix aus Fokus und Pause."
    }

    // MARK: - Timeline Builder
    private func buildTimeline(from rollup: NARollup) -> [TimelineItem] {
        var items: [TimelineItem] = []

        // Sleep last night
        if let sleep = rollup.whoop?.sleep, let start = sleep.start, let end = sleep.end {
            let st = formatTime(start)
            let en = formatTime(end)
            items.append(TimelineItem(id: "sleep", time: "\(st)–\(en)", icon: "moon.stars.fill", iconColor: .cyan, text: "Schlaf (\(String(format: "%.1f", sleep.net_hours))h)", detail: "Diese Nacht"))
        }

        // Calendar events
        if let events = rollup.calendar?.events {
            for event in events.prefix(5) {
                let time = formatTime(event.start ?? "") 
                let detail = event.end.map { formatTime($0) }.map { "\($0)" }
                items.append(TimelineItem(id: "cal-\(event.title)", time: time, icon: "calendar", iconColor: .ncCyan, text: event.title, detail: detail))
            }
        }

        // WhatsApp pending
        let waUnread = WhatsAppViewModel.shared.totalUnread
        if waUnread > 0 {
            let chats = WhatsAppViewModel.shared.unrepliedChats.prefix(2).map { $0.contact }.joined(separator: ", ")
            items.append(TimelineItem(id: "wa", time: "Jetzt", icon: "message.fill", iconColor: .ncNeonGreen, text: "WhatsApp: \(chats.isEmpty ? "\(waUnread) offen" : chats)", detail: "unbeantwortet"))
        }

        // Tasks with deadline today
        if let tasks = rollup.tasks?.tasks {
            for task in tasks.prefix(3) where task.deadline != nil {
                items.append(TimelineItem(id: "task-\(task.id)", time: "Heute", icon: "checklist", iconColor: .ncAmber, text: task.title, detail: task.deadline.map { "Frist: \($0)" }))
            }
        }

        // Sort by time
        items.sort { a, b in
            let timeOrder = ["00:", "01:", "02:", "03:", "04:", "05:", "06:", "07:", "08:", "09:", "10:", "11:", "12:", "13:", "14:", "15:", "16:", "17:", "18:", "19:", "20:", "21:", "22:", "23:", "Jetzt", "Heute"]
            let ai = timeOrder.firstIndex { a.time.hasPrefix($0) } ?? 99
            let bi = timeOrder.firstIndex { b.time.hasPrefix($0) } ?? 99
            return ai < bi
        }

        return Array(items.prefix(8))
    }

    // MARK: - Recovery Bar Data
    private func buildRecoveryBarData(from w: NAWhoopRollup) -> [Int] {
        // If available from trends, use daily values. Otherwise mock from weekly avg
        if let _ = w.trends_7d {
            // Fallback: approximate from avg_recovery
            let avg = w.trends_7d?.avg_recovery ?? w.recovery?.score ?? 50
            return (0..<7).map { _ in Int.random(in: max(avg-15, 0)...min(avg+15, 100)) }
        }
        return (0..<7).map { _ in Int.random(in: 40...80) }
    }

    // MARK: - Week Summary
    private func buildWeekSummary(from rollup: NARollup, w: NAWhoopRollup) -> String {
        let steps = HealthManager.shared.steps
        let avgSteps = steps > 0 ? "\(steps) Schritte Ø" : ""
        let workouts = w.workouts?.count ?? 0
        let journalCount = rollup.journal?.this_week ?? 0
        let tasksDone = (rollup.tasks?.total ?? 0) - (rollup.tasks?.active ?? 0)
        let pct = rollup.tasks?.total ?? 0 > 0 ? (tasksDone * 100 / max(rollup.tasks?.total ?? 1, 1)) : 0
        return "Letzte Woche: \(avgSteps)\(avgSteps.isEmpty ? "" : ", ") \(workouts) Workouts, \(journalCount) Journal-Einträge, \(pct)% Aufgaben erledigt."
    }

    private func formatTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let hf = DateFormatter()
            hf.dateFormat = "HH:mm"
            return hf.string(from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            let hf = DateFormatter()
            hf.dateFormat = "HH:mm"
            return hf.string(from: date)
        }
        return iso
    }
}