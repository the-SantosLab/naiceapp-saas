import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Model
struct NFile: Codable, Identifiable {
    var id: String { name + path }
    let name: String
    let path: String
    let size: Int
    let mtime: Double
    let ext: String
    let type: String
    let source: String?
    let folder: String?

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
        df.dateFormat = "dd.MM.yy"
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
        case "video": return "video.fill"
        case "audio": return "music.note"
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
        case "video": return .ncRose
        case "audio": return .ncAmber
        default: return .ncMuted
        }
    }
}

struct NFileListResponse: Codable {
    let files: [NFile]
    let total: Int
}

struct NFolder: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let fileCount: Int
}

// MARK: - Sort & Filter
enum FileSortBy: String, CaseIterable {
    case date = "Datum"
    case name = "Name"
    case size = "Größe"
    case type = "Typ"
}

enum FileTypeFilter: String, CaseIterable {
    case all = "Alle"
    case pdf = "PDFs"
    case image = "Bilder"
    case text = "Text"
    case html = "HTML"
    case other = "Sonstiges"
}

// MARK: - File Service
@MainActor
class NAFilesService: ObservableObject {
    static let shared = NAFilesService()

    @Published var files: [NFile] = []
    @Published var folders: [NFolder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var downloadedFiles: [String: Data] = [:]
    @Published var activeFilter: FileFilter = .all
    @Published var selectedFolder: String?
    @Published var serverFolders: [String] = []

    @Published var sortBy: FileSortBy = .date
    @Published var sortAscending = false
    @Published var typeFilter: FileTypeFilter = .all

    enum FileFilter: String, CaseIterable {
        case all = "Alle"
        case uploads = "Uploads"
        case ki = "KI-Erstellt"
        case workspace = "Workspace"

        var serverValue: String? {
            switch self {
            case .all: return nil
            case .uploads: return "upload"
            case .ki: return "ki"
            case .workspace: return "workspace"
            }
        }
    }

    private let baseURL = "https://health.santoslab.de/api/naice/files"

    // MARK: - Filtered + Sorted Files
    var sortedFiles: [NFile] {
        let filtered = applyAllFilters()
        return filtered.sorted { a, b in
            let result: Bool
            switch sortBy {
            case .date: result = a.mtime > b.mtime
            case .name: result = a.name.lowercased() < b.name.lowercased()
            case .size: result = a.size > b.size
            case .type: result = a.type < b.type
            }
            return sortAscending ? !result : result
        }
    }

    var folderFiles: [NFile] {
        // Files in the currently selected folder
        let filtered = applyAllFilters()
        if let folder = selectedFolder, !folder.isEmpty {
            return filtered.filter { $0.folder == folder || $0.folder == "uploads/" + folder }
        }
        return filtered
    }

    private func applyAllFilters() -> [NFile] {
        var result = files

        // Source filter
        if let sv = activeFilter.serverValue {
            result = result.filter { $0.source == sv }
        }

        // Type filter
        if typeFilter != .all {
            result = result.filter { fileTypeMatches($0.type) }
        }

        return result
    }

    private func fileTypeMatches(_ t: String) -> Bool {
        switch typeFilter {
        case .all: return true
        case .pdf: return t == "pdf"
        case .image: return t == "image"
        case .text: return ["txt", "md", "docx"].contains(t)
        case .html: return t == "html"
        case .other: return !["pdf", "image", "txt", "md", "docx", "html"].contains(t)
        }
    }

    // MARK: - API
    func fetchFiles() async {
        isLoading = true
        errorMessage = nil
        do {
            let url = URL(string: baseURL)!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NFileListResponse.self, from: data)
            files = response.files
            buildFolders()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchFolders() async {
        let urlStr = baseURL + "/folders"
        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode([String: [String]].self, from: data)
            serverFolders = (result["folders"] ?? []).filter { !$0.contains("/") && $0 != "uploads" }
        } catch {}
    }

    func fetchFilesInFolder(_ folder: String) async {
        isLoading = true
        selectedFolder = folder
        do {
            var urlStr = baseURL + "?folder=" + folder.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            var url = URL(string: urlStr)!
            var (data, _) = try await URLSession.shared.data(from: url)
            var response = try JSONDecoder().decode(NFileListResponse.self, from: data)
            if response.files.isEmpty {
                urlStr = baseURL + "?folder=uploads/" + folder.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                url = URL(string: urlStr)!
                (data, _) = try await URLSession.shared.data(from: url)
                response = try JSONDecoder().decode(NFileListResponse.self, from: data)
            }
            files = response.files
            buildFolders()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func buildFolders() {
        let folderDict = Dictionary(grouping: files) { $0.folder ?? "" }
        folders = folderDict.filter { !$0.key.isEmpty }.map { NFolder(name: $0.key, fileCount: $0.value.count) }.sorted { $0.name < $1.name }
    }

    // MARK: - Download
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

    // MARK: - Share (echte Datei, nicht nur Link)
    func downloadForSharing(_ file: NFile) async -> URL? {
        guard let data = await downloadFile(file) else { return nil }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("naice_share", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempFile = tempDir.appendingPathComponent(file.name)
        do {
            try data.write(to: tempFile)
            return tempFile
        } catch {
            return nil
        }
    }

    // MARK: - Upload
    func uploadFile(name: String, data: Data, folder: String = "") async -> Bool {
        let urlStr = baseURL + "/upload"
        guard let url = URL(string: urlStr) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var bodyDict: [String: Any] = ["name": name, "content": data.base64EncodedString(), "encoding": "base64"]
        if !folder.isEmpty { bodyDict["folder"] = folder }
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchFiles()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Delete
    func deleteFile(_ file: NFile) async -> Bool {
        let urlStr = baseURL + "/delete"
        guard let url = URL(string: urlStr) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["path": file.path])
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode([String: AnyCodable].self, from: data)
            if result["ok"]?.boolValue == true {
                files.removeAll { $0.path == file.path }
                buildFolders()
                return true
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Move
    func moveFile(_ file: NFile, toFolder: String) async -> Bool {
        let urlStr = baseURL + "/move"
        guard let url = URL(string: urlStr) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["path": file.path, "folder": toFolder]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchFiles()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Folder Management
    func createFolder(name: String, parent: String = "") async -> Bool {
        let urlStr = baseURL + "/folder/create"
        guard let url = URL(string: urlStr) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": name, "parent": parent]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchFiles()
            return true
        } catch {
            return false
        }
    }

    func renameFolder(from: String, to: String) async -> Bool {
        let urlStr = baseURL + "/folder/rename"
        guard let url = URL(string: urlStr) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["from": from, "to": to]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            return true
        } catch {
            return false
        }
    }

    func deleteFolder(_ name: String) async -> Bool {
        let urlStr = baseURL + "/folder/delete"
        guard let url = URL(string: urlStr) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": name]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Helper for dynamic JSON decoding
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let str = try? container.decode(String.self) { value = str }
        else { value = try container.decode([String: AnyCodable].self) }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let bool = value as? Bool { try container.encode(bool) }
        else if let str = value as? String { try container.encode(str) }
    }

    var boolValue: Bool? { value as? Bool }
}