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

    private let tokenKey = "naice_push_token"
    private let pendingKey = "naice_pending_notifications"

    private init() {
        loadPending()
    }

    // MARK: - Register for remote notifications
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
        // Send to server
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

    // MARK: - Local Notifications
    func scheduleLocal(title: String, body: String, at date: Date, id: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Schedule Briefing
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

    // MARK: - Poll pending from server
    func pollServer() async {
        guard let url = URL(string: "https://health.santoslab.de/api/push/pending") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        if let items = try? JSONDecoder().decode([NAPushNotification].self, from: data) {
            pendingNotifications = items
            savePending()
        }
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
    }
}

struct NAPushNotification: Codable, Identifiable {
    var id: String
    let title: String
    let body: String
    let type: String // "briefing", "deal", "contact", "budget", "general"
    let createdAt: String
    var isRead: Bool = false
}

// MARK: - AppDelegate for Push
class NAPushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NAPushService.shared.setToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String {
            // Handle deep link based on type
            print("[Push] Tapped: \(type)")
        }
    }
}