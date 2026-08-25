import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Model
struct NFile: Codable, Identifiable {
    var id: String { name }
    let name: String
    let path: String
    let size: Int
    let mtime: Double
    let ext: String
    let type: String

    var sizeLabel: String {
        if size < 1024 { return "\(size) B" }
        let kb = Double(size) / 1024
        if kb < 1024 { return "\(Int(kb)) KB" }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }

    var dateLabel: String {
        let d = Date(timeIntervalSince1970: mtime)
        if Calendar.current.isDateInToday(d) { return "Heute" }
        if Calendar.current.isDateInYesterday(d) { return "Gestern" }
        let df = DateFormatter()
        df.dateFormat = "dd.MM."
        return df.string(from: d)
    }

    var icon: String {
        switch type {
        case "pdf": return "doc.richtext"
        case "docx": return "doc.text"
        case "html": return "globe"
        case "md": return "doc.text"
        case "txt": return "doc.plaintext"
        case "image": return "photo"
        default: return "doc"
        }
    }

    var color: Color {
        switch type {
        case "pdf": return .red
        case "docx": return .blue
        case "html": return .orange
        case "md": return .purple
        case "txt": return .gray
        case "image": return .green
        default: return .ncMuted
        }
    }
}

struct NFileListResponse: Codable {
    let files: [NFile]
    let total: Int
}

// MARK: - File Service
@MainActor
class NAFilesService: ObservableObject {
    static let shared = NAFilesService()

    @Published var files: [NFile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var downloadedFiles: [String: Data] = [:] // cache

    private let baseURL = "https://health.santoslab.de/api/naice/files"

    func fetchFiles() async {
        isLoading = true
        errorMessage = nil
        do {
            let url = URL(string: baseURL)!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NFileListResponse.self, from: data)
            files = response.files
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func downloadFile(_ file: NFile) async -> Data? {
        if let cached = downloadedFiles[file.path] { return cached }
        let urlStr = baseURL + "/download?path=" + file.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            downloadedFiles[file.path] = data
            return data
        } catch {
            return nil
        }
    }

    func uploadFile(name: String, data: Data) async -> Bool {
        let urlStr = baseURL + "/upload"
        guard let url = URL(string: urlStr) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": name, "content": data.base64EncodedString(), "encoding": "base64"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchFiles()
            return true
        } catch {
            return false
        }
    }

    var categories: [(String, [NFile])] {
        let grouped = Dictionary(grouping: files) { $0.type }
        let order = ["pdf", "docx", "html", "md", "txt", "image", "other"]
        return order.compactMap { key in
            guard let items = grouped[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    var searchResults: (String) -> [NFile] {
        return { query in
            guard !query.isEmpty else { return self.files }
            return self.files.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }
}