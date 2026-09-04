import Foundation
import EventKit

// MARK: - Calendar Event Creator
@MainActor
class NACalendarService: ObservableObject {
    static let shared = NACalendarService()

    private let store = EKEventStore()

    @Published var lastCreatedEvent: EKEvent?
    @Published var isAuthorized = false

    private init() {}

    /// Request calendar access. Call on launch or before first use.
    func requestAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToEvents()
                isAuthorized = granted
            } catch {
                print("[NACalendarService] Access error: \(error.localizedDescription)")
                isAuthorized = false
            }
        default:
            isAuthorized = false
        }
    }

    /// Create a calendar event. Returns true on success.
    /// Uses the default calendar. Sets `lastCreatedEvent` on success.
    @discardableResult
    func createEvent(title: String, startDate: Date, endDate: Date?, notes: String?) -> Bool {
        guard isAuthorized else {
            print("[NACalendarService] Not authorized")
            return false
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600) // default 1 hour
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent, commit: true)
            lastCreatedEvent = event
            print("[NACalendarService] ✅ Event created: \(title)")
            return true
        } catch {
            print("[NACalendarService] Save error: \(error.localizedDescription)")
            return false
        }
    }

    /// Create event from Agent Action params dict (e.g. from [ACTION:createCalendar,...])
    /// Supports keys: title, start (ISO8601), end (ISO8601, optional), duration (minutes, optional), notes
    @discardableResult
    func createEvent(from params: [String: String]) -> Bool {
        guard let title = params["title"], !title.isEmpty else {
            print("[NACalendarService] Missing title")
            return false
        }

        guard let startDate = parseISODate(params["start"]) else {
            print("[NACalendarService] Missing or invalid start date")
            return false
        }

        var endDate: Date?
        if let endStr = params["end"], let parsed = parseISODate(endStr) {
            endDate = parsed
        } else if let durationStr = params["duration"], let mins = Double(durationStr) {
            endDate = startDate.addingTimeInterval(mins * 60)
        }

        let notes = params["notes"]

        return createEvent(title: title, startDate: startDate, endDate: endDate, notes: notes)
    }

    // MARK: - Helpers

    /// Parse ISO8601 date strings like "2026-09-05T10:00" or "2026-09-05T10:00:00+02:00"
    private func parseISODate(_ str: String?) -> Date? {
        guard let str = str, !str.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withDashSeparatorInDate, .withColonSeparatorInTime]

        // Try full ISO8601 first
        if let date = formatter.date(from: str) {
            return date
        }

        // Try without timezone (e.g. "2026-09-05T10:00")
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        simpleFormatter.timeZone = TimeZone.current
        if let date = simpleFormatter.date(from: str) {
            return date
        }

        // Try date only "2026-09-05" → start of day
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleFormatter.date(from: str) {
            return date
        }

        print("[NACalendarService] Failed to parse date: \(str)")
        return nil
    }
}