import AppIntents
import SwiftUI

// MARK: - nAIce Siri Shortcuts
struct NAiceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecoveryIntent(),
            phrases: [
                "Wie ist meine Recovery?",
                "Zeig mir meine WHOOP Daten",
                "Meine Recovery in \(.applicationName)",
                "Wie geht es mir heute?"
            ],
            shortTitle: "Recovery abfragen",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: BriefingIntent(),
            phrases: [
                "Was steht heute an?",
                "Mein Tagesbriefing",
                "Zeig mir mein Briefing in \(.applicationName)",
                "Tagesübersicht"
            ],
            shortTitle: "Tagesbriefing",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: BusinessIntent(),
            phrases: [
                "Business Status",
                "Wie läuft das Business?",
                "Pipeline Status in \(.applicationName)",
                "Meine Business Übersicht"
            ],
            shortTitle: "Business Status",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: JournalIntent(),
            phrases: [
                "Neuer Journal Eintrag",
                "Öffne das Journal",
                "Tagebuch eintrag in \(.applicationName)",
                "Journal schreiben"
            ],
            shortTitle: "Journal öffnen",
            systemImageName: "book.fill"
        )
        AppShortcut(
            intent: OpenTasksIntent(),
            phrases: [
                "Meine Aufgaben",
                "Was muss ich tun?",
                "Aufgaben in \(.applicationName)",
                "Zeig mir meine Aufgaben"
            ],
            shortTitle: "Aufgaben öffnen",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "Notiz erstellen",
                "Erstelle eine Notiz mit \(\.$text)",
                "Notiz in \(.applicationName)"
            ],
            shortTitle: "Notiz erstellen",
            systemImageName: "note.text"
        )
        AppShortcut(
            intent: LogMoodIntent(),
            phrases: [
                "Logge meine Stimmung",
                "Stimmung loggen",
                "Meine Laune in \(.applicationName)"
            ],
            shortTitle: "Stimmung loggen",
            systemImageName: "face.smiling"
        )
    }
}