import AppIntents
import SwiftUI

// MARK: - Siri Shortcuts via AppIntents

struct NAiceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "Erstelle eine Notiz mit \(\.$text)",
                "Notiz erstellen mit \(\.$text)",
                "Neue nAIce Notiz"
            ],
            shortTitle: "Notiz erstellen",
            systemImageName: "note.text"
        )
        AppShortcut(
            intent: LogMoodIntent(),
            phrases: [
                "Logge meine Stimmung als \(\.$mood)",
                "Stimmung loggen \(\.$mood)",
                "nAIce Stimmung"
            ],
            shortTitle: "Stimmung loggen",
            systemImageName: "face.smiling"
        )
        AppShortcut(
            intent: OpenChatIntent(),
            phrases: [
                "Offne nAIce Chat",
                "nAIce Agent fragen"
            ],
            shortTitle: "Chat offnen",
            systemImageName: "bubble.left.and.bubble.right"
        )
    }
}

// MARK: - Create Note Intent
struct CreateNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Notiz erstellen"
    static var description = LocalizedStringResource("Erstellt eine neue Notiz in nAIce")

    @Parameter(title: "Text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Store in a local array that can be read
        UserDefaults.sharedNotes.append(text)
        return .result(value: "Notiz erstellt: \(text)")
    }
}

// MARK: - Log Mood Intent
struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Stimmung loggen"
    static var description = LocalizedStringResource("Loggt deine aktuelle Stimmung")

    @Parameter(title: "Stimmung")
    var mood: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let moodInt = mood == "gut" ? 3 : mood == "mittel" ? 2 : 1
        UserDefaults.standard.set(moodInt, forKey: "naice_last_mood")
        return .result(value: "Stimmung geloggt: \(mood)")
    }
}

// MARK: - Open Chat Intent
struct OpenChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Chat offnen"
    static var description = LocalizedStringResource("Offnet den nAIce Agent Chat")

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - UserDefaults Extension for shared notes
extension UserDefaults {
    static var sharedNotes: [String] {
        get { return standard.stringArray(forKey: "naice_shared_notes") ?? [] }
        set { standard.set(newValue, forKey: "naice_shared_notes") }
    }
}