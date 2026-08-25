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

struct NFolder: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let fileCount: Int
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

    var filteredFiles: [NFile] {
        var result = files
        // Filter by source
        if let sv = activeFilter.serverValue {
            result = result.filter { $0.source == sv }
        }
        // Filter by folder
        if let folder = selectedFolder, !folder.isEmpty {
            result = result.filter { $0.folder == folder }
        }
        return result
    }

    var currentFolderFiles: [NFile] {
        if let folder = selectedFolder, !folder.isEmpty {
            return files.filter { $0.folder == folder }
        }
        return filteredFiles
    }

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
            // Filter out subpaths with / and the bare 'uploads' folder
            serverFolders = (result["folders"] ?? []).filter { !$0.contains("/") && $0 != "uploads" }
        } catch {}
    }

    func fetchFilesInFolder(_ folder: String) async {
        isLoading = true
        selectedFolder = folder
        do {
            let urlStr = baseURL + "?folder=" + folder.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let url = URL(string: urlStr)!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NFileListResponse.self, from: data)
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

    func moveFile(file: NFile, toFolder: String) async -> Bool {
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
}