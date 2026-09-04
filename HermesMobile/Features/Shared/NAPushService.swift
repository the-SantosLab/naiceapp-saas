import Foundation
import UIKit
import UserNotifications

// MARK: - Push Notification Service
@MainActor
class NAPushService: ObservableObject {
    static let shared = NAPushService()

    @Published var isRegistered = false
    @Published var deviceToken: String?
    @Published var pendingNotifications: [NAPushNotification] = []
    @Published var lastBriefing: String?
    @Published var lastBriefingType: String?
    @Published var unreadCount = 0

    private let tokenKey = "naice_push_token"
    private let pendingKey = "naice_pending_notifications"
    private let lastSeenKey = "naice_last_push_id"
    private var timer: Timer?

    private init() {
        loadPending()
        startPolling()
    }

    // MARK: - Start polling
    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.pollServer() }
        }
        // Poll immediately
        Task { await pollServer() }
    }

    // MARK: - Register
    func register() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func setToken(_ token: String) {
        deviceToken = token
        isRegistered = true
        UserDefaults.standard.set(token, forKey: tokenKey)
        sendTokenToServer(token)
    }

    private func sendTokenToServer(_ token: String) {
        guard let url = URL(string: "https://health.santoslab.de/api/push/register") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["token": token, "device": "ios"])
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Poll
    func pollServer() async {
        guard let url = URL(string: "https://health.santoslab.de/api/push/queue") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let result = try? JSONDecoder().decode(NAPushQueueResponse.self, from: data) {
                let items = result.notifications.map { n in
                    NAPushNotification(
                        id: "\(n.id)",
                        title: n.title,
                        body: n.body,
                        type: n.type ?? "briefing",
                        createdAt: n.created_at,
                        isRead: false
                    )
                }
                // Check for new items
                let lastSeen = UserDefaults.standard.integer(forKey: lastSeenKey)
                let newItems = items.filter { $0.idInt > lastSeen }
                if !newItems.isEmpty {
                    unreadCount += newItems.count
                    // Show local notification for latest
                    if let latest = newItems.last {
                        if latest.type == "calendar" {
                            // Handle calendar push - auto-create event
                            await handleCalendarPush(latest)
                        } else {
                            showLocalNotification(title: latest.title, body: latest.body, id: latest.id)
                        }
                        lastBriefing = latest.body
                        lastBriefingType = latest.type
                    }
                    // Update last seen
                    if let maxId = items.map({ $0.idInt }).max() {
                        UserDefaults.standard.set(maxId, forKey: lastSeenKey)
                    }
                }
                pendingNotifications = items
                savePending()
            }
        } catch {
            print("[Push] Poll error: \(error)")
        }
    }

    /// Handle a push notification of type "calendar" — parse body as JSON and create the event silently (no local notification).
    private func handleCalendarPush(_ notification: NAPushNotification) async {
        // Try to parse body as JSON with calendar event fields
        if let data = notification.body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let title = json["title"], !title.isEmpty {

            await NACalendarService.shared.requestAccess()

            // Extract event details from JSON body
            var params = json
            if params["start"] == nil {
                params["start"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
            }
            if params["duration"] == nil && params["end"] == nil {
                params["duration"] = "60"
            }

            if NACalendarService.shared.createEvent(from: params) {
                print("[Push] Calendar event created from push: \(title)")
            }
        } else if let dataJson = try? JSONSerialization.jsonObject(with: notification.body.data(using: .utf8) ?? Data()) as? [String: Any] {
            // JSON with non-string values
            let title = dataJson["title"] as? String ?? notification.title
            var params: [String: String] = ["title": title]
            if let start = dataJson["start"] as? String { params["start"] = start }
            if let end = dataJson["end"] as? String { params["end"] = end }
            if let duration = dataJson["duration"] { params["duration"] = "\(duration)" }
            if let notes = dataJson["notes"] as? String { params["notes"] = notes }

            await NACalendarService.shared.requestAccess()
            if NACalendarService.shared.createEvent(from: params) {
                print("[Push] Calendar event created from push: \(title)")
            }
        }
        // Don't show a local notification for calendar events — the event just appears
    }

    // MARK: - Local Notification
    private func showLocalNotification(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = String(body.prefix(200))
        content.sound = .default
        content.badge = NSNumber(value: unreadCount)
        content.userInfo = ["type": "briefing"]

        let request = UNNotificationRequest(identifier: "proactive_\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Schedule Morning Briefing (local fallback)
    func scheduleMorningBriefing() {
        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "☀️ Guten Morgen, Johannes"
        content.body = "Dein Briefing wird geladen..."
        content.sound = .default
        content.userInfo = ["type": "briefing"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_briefing", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func markAllRead() {
        unreadCount = 0
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    // MARK: - Persistence
    private func savePending() {
        if let data = try? JSONEncoder().encode(pendingNotifications) {
            UserDefaults.standard.set(data, forKey: pendingKey)
        }
    }

    private func loadPending() {
        guard let data = UserDefaults.standard.data(forKey: pendingKey),
              let items = try? JSONDecoder().decode([NAPushNotification].self, from: data) else { return }
        pendingNotifications = items
        unreadCount = items.filter { !$0.isRead }.count
    }
}

// MARK: - Models
struct NAPushNotification: Codable, Identifiable {
    var id: String
    let title: String
    let body: String
    let type: String
    let createdAt: String
    var isRead: Bool = false

    var idInt: Int { Int(id) ?? 0 }
}

struct NAPushQueueResponse: Codable {
    let notifications: [NAPushQueueItem]
    let count: Int
}

struct NAPushQueueItem: Codable {
    let id: Int
    let title: String
    let body: String
    let type: String?
    let data: [String: String]?
    let created_at: String
    let tokens: [String]?
}

// MARK: - AppDelegate for Push
@MainActor
class NADevPushDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String {
            if type == "briefing" {
                NAIntentRouter.shared.pendingTab = "home"
            }
        }
    }
}