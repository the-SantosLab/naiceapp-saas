import SwiftUI
import QuickLook

class FilePreviewDataSource: NSObject, QLPreviewControllerDataSource {
    let url: URL
    init(url: URL) { self.url = url }
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as QLPreviewItem }
}

class FilePreviewDelegate: NSObject, QLPreviewControllerDelegate {}

struct FilesFolderSection: View {
    @ObservedObject var fs: NAFilesService
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ordner").font(.subheadline.weight(.semibold)).foregroundColor(.white)
            ForEach(folders()) { f in
                NAFolderRowView(name: f.name, count: f.fileCount, onTap: { fs.selectedFolder = f.name; Task { await fs.fetchFilesInFolder(f.name) } })
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
    }
    func folders() -> [NFolder] {
        fs.serverFolders.compactMap { name in
            let c = fs.files.filter { f in (f.folder == name || f.folder == "uploads/"+name) && (fs.activeFilter == .all || f.source == fs.activeFilter.serverValue) }.count
            return c > 0 ? NFolder(name: name, fileCount: c) : nil
        }
    }
}

struct FilesListSection: View {
    @ObservedObject var fs: NAFilesService
    let searchText: String
    let onDelete: (NFile) -> Void
    let onMove: (NFile) -> Void
    var body: some View {
        let files = computeFiles()
        if files.isEmpty {
            Text("Keine Dateien").font(.subheadline).foregroundColor(.gray).padding()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(fs.selectedFolder ?? "Dateien").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                ForEach(files) { file in
                    HStack {
                        NAFileRowView(file: file, onTap: { openFile(file) })
                        Spacer()
                        Menu {
                            Button("Teilen") { shareFile(file) }
                            Button("Verschieben") { onMove(file) }
                            Button("Loschen", role: .destructive) { onDelete(file) }
                        } label: {
                            Image(systemName: "ellipsis").font(.caption).foregroundColor(.gray).padding(6)
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
        }
    }
    func computeFiles() -> [NFile] {
        var r = fs.files
        if let f = fs.selectedFolder, !f.isEmpty { r = r.filter { $0.folder == f || $0.folder == "uploads/"+f } }
        // Apply type filter
        switch fs.typeFilter {
        case .pdf: r = r.filter { $0.type.lowercased() == "pdf" }
        case .image: r = r.filter { ["jpg", "jpeg", "png", "gif", "webp"].contains($0.type.lowercased()) }
        case .text: r = r.filter { ["txt", "md", "docx", "doc"].contains($0.type.lowercased()) }
        case .html: r = r.filter { $0.type.lowercased() == "html" }
        default: break
        }
        if !searchText.isEmpty { r = r.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
        r.sort { a, b in
            switch fs.sortBy {
            case .date: return a.mtime > b.mtime
            case .name: return a.name.lowercased() < b.name.lowercased()
            case .size: return a.size > b.size
            case .type: return a.type < b.type
            }
        }
        if !fs.sortAscending { r.reverse() }
        return r
    }
    func openFile(_ file: NFile) {
        Task {
            if let url = await NAFilesService.shared.downloadForSharing(file) {
                await MainActor.run {
                    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = scene.windows.first,
                          let root = window.rootViewController else { return }
                    
                    let preview = QLPreviewController()
                    preview.dataSource = FilePreviewDataSource(url: url)
                    preview.delegate = FilePreviewDelegate()
                    
                    root.present(preview, animated: true)
                }
            }
        }
    }
    func shareFile(_ file: NFile) {
        Task {
            if let url = await NAFilesService.shared.downloadForSharing(file) {
                if let s = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let w = s.windows.first, let r = w.rootViewController {
                    r.present(UIActivityViewController(activityItems: [url], applicationActivities: nil), animated: true)
                }
            }
        }
    }
}