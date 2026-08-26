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
}