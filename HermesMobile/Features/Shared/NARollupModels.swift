import Foundation

// MARK: - Rollup Models (console.naice.app/api/v2/rollup)

struct NARollup: Codable {
    let ts: String
    let date: String
    let whoop: NAWhoopRollup?
    let calendar: NACalendarRollup?
    let journal: NAJournalRollup?
    let business: NABusinessRollup?
    let tasks: NATasksRollup?
    let deals: NADealsRollup?
    let summary: NASummary?
    let crm: NARollupCRM?
}

struct NAWhoopRollup: Codable {
    let recovery: NAWhoopRecovery?
    let sleep: NAWhoopSleep?
    let cycle: NAWhoopCycle?
    let trends_7d: NAWhoopTrends?
    let workouts: [NAWhoopWorkout]?
}

struct NAWhoopRecovery: Codable {
    let score: Int
    let hrv: Int
    let rhr: Int
    let spo2: Double?
    let skin_temp: Double?
    let synced_at: String?
}

struct NAWhoopSleep: Codable {
    let performance_pct: Int?
    let efficiency_pct: Double?
    let net_hours: Double
    let net_minutes: Int
    let deep_minutes: Int
    let rem_minutes: Int
    let light_minutes: Int
    let awake_minutes: Int
    let respiratory_rate: Double?
    let start: String?
    let end: String?
}

struct NAWhoopCycle: Codable {
    let strain: Double?
    let kilojoule: Double?
    let kcal: Double?
    let avg_hr: Int?
    let max_hr: Int?
    let start: String?
    let end: String?
}

struct NAWhoopTrends: Codable {
    let avg_recovery: Int?
    let avg_hrv: Int?
    let avg_sleep_hours: Double?
    let avg_strain: Double?
}

struct NAWhoopWorkout: Codable {
    let sport: String
    let strain: Double
    let max_hr: Int?
    let avg_hr: Int?
    let kj: Double?
    let kcal: Double?
    let start: String?
    let end: String?
}

struct NACalendarRollup: Codable {
    let events: [NACalendarEvent]?
    let count: Int
}

struct NACalendarEvent: Codable {
    let title: String
    let start: String?
    let end: String?
    let location: String?
}

struct NAJournalRollup: Codable {
    let entries: [NAJournalEntry]?
    let count: Int
    let this_week: Int?
    let avg_clarity_week: Int?
}

struct NAJournalEntry: Codable, Identifiable {
    let id: String
    let text: String
    let created_at: String?
}

struct NABusinessRollup: Codable {
    let foodloop: NABusinessProject?
    let naice: NABusinessProject?
    let schaffer: NABusinessExtra?
    let parcelmate: NABusinessExtra?
}

struct NABusinessProject: Codable {
    let total: Int
    let statuses: [String: Int]?
    let hot: Int?
    let emails: [String: Int]?
    let pitched_today: Int?
    let replies_week: Int?
}

struct NABusinessExtra: Codable {
    let b2b_leads: Int?
    let pageviews_today: Int?
    let pageviews_week: Int?
    let subscribers: Int?
    let orders: Int?
    let inquiries: Int?
    let users: Int?
    let shipments: Int?
    let newsletter_leads: Int?
}

struct NATasksRollup: Codable {
    let total: Int
    let active: Int
    let tasks: [NATask]?
}

struct NATask: Codable, Identifiable {
    let id: String
    let title: String
    let priority: String?
    let deadline: String?
    let source: String?
    let project: String?
    let status: String?
    let created: String?
}

struct NADealsRollup: Codable {
    let active_deals: Int
    let total_value_eur: Int
    let deals: [NADeal]?
}

struct NADeal: Codable, Identifiable {
    var id: String { clientId ?? name }
    let name: String
    let value: Int
    let status: String?
    let clientId: String?
}

struct NASummary: Codable {
    let recovery: Int?
    let hrv: Int?
    let sleep_hours: Double?
    let sleep_pct: Int?
    let strain: Double?
    let naice_total: Int?
    let naice_pitched_today: Int?
    let events_today: Int?
    let journal_entries_today: Int?
    let flags: [NASummaryFlag]?
}

struct NASummaryFlag: Codable, Identifiable {
    var id: String { text }
    let level: String
    let text: String
}

// MARK: - CRM Models
struct NARollupCRM: Codable {
    let total_clients: Int?
    let total_value_eur: Int?
    let won_deals: Int?
    let active: Int?
    let revenue_eur: Int?
    let cold_calls_pending: Int?
    let alerts: [NAAgentAlert]?
    let briefings: NABriefings?
}

struct NAAgentAlert: Codable, Identifiable {
    let id: Int?
    let title: String?
    let summary: String?
    let created: Int?
}

// MARK: - CRM API Models (for direct API calls)
struct NCRMClient: Codable, Identifiable {
    let id: String
    let name: String
    let company: String?
    let email: String?
    let phone: String?
    let segment: String?
    let stage: String?
    let status: String?
    let value: Int?
    let notes: String?
    let created: Int?
    let updated: Int?
}

struct NCRMClientList: Codable {
    let ts: String?
    let clients: [NCRMClient]
    let total: Int
    let total_value_eur: Int?
    let won_deals: Int?
    let active: Int?
    let contacted: Int?
    let new: Int?
}

struct NCRMRevenueEntry: Codable, Identifiable {
    let id: String?
    let client_id: String?
    let label: String?
    let amount: Int?
    let kind: String?
    let at: Int?
}

struct NCRMRevenue: Codable {
    let ts: String?
    let entries: [NCRMRevenueEntry]
    let total_eur: Int?
}

struct NCRMColdCall: Codable, Identifiable {
    let id: String?
    let client_id: String?
    let name: String?
    let company: String?
    let phone: String?
    let pitch: String?
    let result: String?
    let notes: String?
    let status: String?
    let called_at: Int?
    let created: Int?
}

struct NCRMColdCalls: Codable {
    let ts: String?
    let calls: [NCRMColdCall]
    let total: Int
    let follow_up: Int?
    let done: Int?
}

// MARK: - Briefing Models
struct NABriefing: Codable, Identifiable {
    let id: Int?
    let period: String?  // "morning" | "midday" | "evening"
    let title: String?
    let body: String?
    let created: Int?
}

struct NABriefings: Codable {
    let today: [NABriefing]?
    let latest_morning: NABriefing?
    let latest_midday: NABriefing?
    let latest_evening: NABriefing?
}