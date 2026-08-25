import SwiftUI
import SwiftData
import UserNotifications

// MARK: - App Delegate (Push Notifications)
class NAIceAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Request notification permission
        Task {
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                print("[PUSH] Permission granted: \(granted)")
                if granted {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            } catch {
                print("[PUSH] Permission error: \(error.localizedDescription)")
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenHex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[PUSH] Device token: \(tokenHex)")
        // Send to server
        guard let url = URL(string: "https://health.santoslab.de/api/push/register") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["token": tokenHex, "user_id": "johannes", "platform": "ios"]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { _, _, error in
            if let error = error {
                print("[PUSH] Registration failed: \(error.localizedDescription)")
            } else {
                print("[PUSH] Token registered on server")
            }
        }.resume()
        // Store locally for More-Tab display
        PushRegistrar.shared.didRegister = true
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[PUSH] Failed to register: \(error.localizedDescription)")
        PushRegistrar.shared.registrationError = error.localizedDescription
    }
}

// MARK: - Push Registrar (for More-Tab status)
@MainActor
class PushRegistrar: ObservableObject {
    static let shared = PushRegistrar()
    @Published var didRegister = false
    @Published var registrationError: String?
    var isRegistered: Bool { didRegister }
    var statusText: String {
        if didRegister { return "Registriert ✅" }
        if let err = registrationError { return "Fehler: \(err)" }
        return "Nicht registriert"
    }
}

struct nAIceSceneActions {
    let canCreateNewChat: Bool
    let createNewChat: () -> Void
    let searchSessions: () -> Void
}

private struct nAIceSceneActionsKey: FocusedValueKey {
    typealias Value = nAIceSceneActions
}

extension FocusedValues {
    var nAIceSceneActions: nAIceSceneActions? {
        get { self[nAIceSceneActionsKey.self] }
        set { self[nAIceSceneActionsKey.self] = newValue }
    }
}

struct nAIceCommands: Commands {
    @FocusedValue(\.nAIceSceneActions) private var actions
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Chat") { actions?.createNewChat() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions?.canCreateNewChat != true)
        }
        CommandGroup(after: .newItem) {
            Button("Search Sessions") { actions?.searchSessions() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)
        }
    }
}

// MARK: - SwiftData Models

@Model
final class MoodEntry {
    var date: Date
    var mood: String // "good", "neutral", "bad"
    var note: String
    
    init(date: Date, mood: String, note: String) {
        self.date = date; self.mood = mood; self.note = note
    }
}

@Model
final class HabitLog {
    var date: Date
    var habit: String // "walk", "meditation", "reading", "workout", "water"
    var isCompleted: Bool
    var note: String
    
    init(date: Date, habit: String, isCompleted: Bool, note: String) {
        self.date = date; self.habit = habit; self.isCompleted = isCompleted; self.note = note
    }
}

@Model
final class Expense {
    var date: Date
    var amount: Double
    var category: String
    var note: String
    
    init(date: Date, amount: Double, category: String, note: String) {
        self.date = date; self.amount = amount; self.category = category; self.note = note
    }
}

@Model
final class HabitDefinition {
    var name: String
    var icon: String
    var isActive: Bool
    
    init(name: String, icon: String, isActive: Bool = true) {
        self.name = name; self.icon = icon; self.isActive = isActive
    }
}

// MARK: - App

@main
struct nAIceApp: App {
    @UIApplicationDelegateAdaptor(NAIceAppDelegate.self) var appDelegate
    @State private var authManager = AuthManager()
    @AppStorage(AppTheme.storageKey) private var appThemeRawValue = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView(authManager: authManager)
                .preferredColorScheme(AppTheme.storedValue(appThemeRawValue).colorScheme)
        }
        .modelContainer(for: [CachedSession.self, CachedMessage.self, MoodEntry.self, HabitLog.self, Expense.self, HabitDefinition.self])
        .commands { nAIceCommands(); SidebarCommands() }
    }
}