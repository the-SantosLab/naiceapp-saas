import Foundation
import SwiftUI

// MARK: - Note Model
struct NANote: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var content: String
    var created: Int
    var updated: Int
    var source: String?

    var createdDate: Date { Date(timeIntervalSince1970: TimeInterval(created)) }
    var updatedDate: Date { Date(timeIntervalSince1970: TimeInterval(updated)) }

    var preview: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first?
            .prefix(100).description ?? ""
    }

    var formattedDate: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: updatedDate, relativeTo: Date())
    }
}

// MARK: - Notes Service
@MainActor
class NANotesService: ObservableObject {
    static let shared = NANotesService()

    @Published var notes: [NANote] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let serverURL = "https://health.santoslab.de/api/naice/notes"

    private init() {}

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        guard let url = URL(string: serverURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            notes = try JSONDecoder().decode([NANote].self, from: data)
        } catch {
            lastError = "\(error.localizedDescription)"
        }
    }

    func addNote(title: String, content: String) async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "add", "title": title, "content": content]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let noteDict = result["note"] as? [String: Any],
               let noteData = try? JSONSerialization.data(withJSONObject: noteDict),
               let note = try? JSONDecoder().decode(NANote.self, from: noteData) {
                notes.insert(note, at: 0)
            }
        } catch {
            lastError = "Add failed: \(error.localizedDescription)"
        }
    }

    func updateNote(id: String, title: String, content: String) async {
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "update", "note_id": id, "title": title, "content": content]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            if let idx = notes.firstIndex(where: { $0.id == id }) {
                notes[idx].title = title
                notes[idx].content = content
                notes[idx].updated = Int(Date().timeIntervalSince1970)
            }
        } catch {
            lastError = "Update failed: \(error.localizedDescription)"
        }
    }

    func deleteNote(_ note: NANote) async {
        notes.removeAll { $0.id == note.id }
        guard let url = URL(string: serverURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "delete", "note_id": note.id]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, _) = try await URLSession.shared.data(for: req)
        } catch {
            lastError = "Delete failed: \(error.localizedDescription)"
        }
    }
}