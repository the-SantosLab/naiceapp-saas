import Foundation
import CoreLocation
import UIKit

// MARK: - Location Reminder
struct NALocationReminder: Codable, Identifiable {
    var id = UUID().uuidString
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double // meters
    let onEntry: Bool
    let onExit: Bool
    let note: String
    var isEnabled: Bool = true
    var lastTriggered: String?
}

// MARK: - Location Reminder Service
@MainActor
class NALocationService: ObservableObject {
    static let shared = NALocationService()

    private let locationManager = CLLocationManager()
    @Published var reminders: [NALocationReminder] = []

    private let storageKey = "naice_location_reminders"

    init() {
        loadReminders()
    }

    func requestAlwaysAuth() async {
        let status = locationManager.authorizationStatus
        if status == .notDetermined || status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    func addReminder(_ reminder: NALocationReminder) {
        reminders.append(reminder)
        saveReminders()
        startMonitoring(reminder)
    }

    func removeReminder(_ id: String) {
        reminders.removeAll { $0.id == id }
        saveReminders()
    }

    func toggleReminder(_ id: String) {
        if let idx = reminders.firstIndex(where: { $0.id == id }) {
            reminders[idx].isEnabled.toggle()
            saveReminders()
        }
    }

    private func loadReminders() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([NALocationReminder].self, from: data) else { return }
        reminders = decoded
    }

    private func saveReminders() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func startMonitoring(_ reminder: NALocationReminder) {
        guard reminder.isEnabled else { return }
        let center = CLLocationCoordinate2D(latitude: reminder.latitude, longitude: reminder.longitude)
        let region = CLCircularRegion(center: center, radius: reminder.radius, identifier: reminder.id)
        region.notifyOnEntry = reminder.onEntry
        region.notifyOnExit = reminder.onExit
        locationManager.startMonitoring(for: region)
    }
}

// MARK: - Routine Models
struct NARoutine: Codable, Identifiable {
    var id = UUID().uuidString
    let name: String
    let icon: String
    let description: String
    let frequency: String // "daily", "weekly", "custom"
    var streak: Int = 0
    var lastCompleted: String?
    var isEnabled: Bool = true
}

struct NAHabitLog: Codable, Identifiable {
    var id = UUID().uuidString
    let routineId: String
    let date: String
    let note: String?
}

// MARK: - Routine Service
@MainActor
class NARoutineService: ObservableObject {
    static let shared = NARoutineService()

    @Published var routines: [NARoutine] = []
    @Published var logs: [NAHabitLog] = []
    @Published var suggestions: [String] = []

    private let routineKey = "naice_routines"
    private let logKey = "naice_routine_logs"
    private let suggestKey = "naice_routine_suggestions"

    init() {
        load()
        generateSuggestions()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: routineKey),
           let decoded = try? JSONDecoder().decode([NARoutine].self, from: data) {
            routines = decoded
        } else {
            // Default routines
            routines = [
                NARoutine(name: "Morgen-Routine", icon: "sunrise.fill", description: "Kurzer Check-in mit Wetter, Terminen und Gefühlslage.", frequency: "daily"),
                NARoutine(name: "Mittags-Pause", icon: "fork.knife", description: "Bewusst 15 Min Pause machen – ohne Handy.", frequency: "daily"),
                NARoutine(name: "Tages-Reflexion", icon: "moon.stars.fill", description: "Was war gut? Was morgen besser?", frequency: "daily"),
                NARoutine(name: "Wöchentlicher Rückblick", icon: "calendar.badge.clock", description: "Sonntags: Woche reflektieren, Ziele nächste Woche setzen.", frequency: "weekly")
            ]
        }

        if let data = UserDefaults.standard.data(forKey: logKey),
           let decoded = try? JSONDecoder().decode([NAHabitLog].self, from: data) {
            logs = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(routines) {
            UserDefaults.standard.set(data, forKey: routineKey)
        }
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: logKey)
        }
    }

    func completeRoutine(_ id: String, note: String? = nil) {
        guard let idx = routines.firstIndex(where: { $0.id == id }) else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        let log = NAHabitLog(routineId: id, date: now, note: note)
        logs.insert(log, at: 0)
        routines[idx].lastCompleted = now
        routines[idx].streak += 1
        save()
    }

    func addRoutine(_ routine: NARoutine) {
        routines.append(routine)
        save()
    }

    func removeRoutine(_ id: String) {
        routines.removeAll { $0.id == id }
        save()
    }

    var completedToday: Int {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return logs.filter { $0.date.prefix(10) == today }.count
    }

    var currentStreak: Int {
        routines.filter { $0.streak > 0 }.reduce(0) { $0 + $1.streak } / max(routines.filter { $0.streak > 0 }.count, 1)
    }

    private func generateSuggestions() {
        let all = [
            "Deine produktivste Zeit ist am Vormittag. Plane wichtige Aufgaben zwischen 9 und 12 Uhr.",
            "Kurze Spaziergänge nach dem Mittagessen verbessern deine Konzentration um bis zu 60%.",
            "Trinke ein Glas Wasser direkt nach dem Aufwachen – dein Korper ist dehydriert nach der Nacht.",
            "Eine feste Schlafenszeit verbessert deine HRV um durchschnittlich 15%.",
            "Nutze die Pomodoro-Technik: 25 Min fokussiert arbeiten, 5 Min Pause.",
            "Dein Gehirn kann nur 3-4 hochfokussierte Stunden pro Tag leisten – plane sie bewusst.",
            "Jede Stunde 5 Minuten Dehnen beugt Ruckenschmerzen vor und verbessert die Durchblutung.",
            "Morgens kein Handy fur die erste Stunde – das reduziert Stress um 30%."
        ]
        suggestions = all.shuffled().prefix(3).map { $0 }
    }

    func refreshSuggestions() {
        generateSuggestions()
        if let data = try? JSONEncoder().encode(suggestions) {
            UserDefaults.standard.set(data, forKey: suggestKey)
        }
    }
}