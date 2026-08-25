import SwiftUI

// MARK: - Files Tab
struct NAIceFilesView: View {
    @ObservedObject private var fs = NAFilesService.shared
    @State private var searchText = ""
    @State private var selectedFile: NFile?
    @State private var showFileViewer = false
    @State private var showUpload = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var showRenameFolder = false
    @State private var renameFolderName = ""
    @State private var folderToEdit: String?
    @State private var showDeleteConfirm = false
    @State private var showMoveFile = false
    @State private var moveTargetFolder = ""

    var body: some View {
        NavigationStack {
            content
                .warmBackground()
                .navigationTitle(fs.selectedFolder ?? "Dateien")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable { await fs.fetchFiles(); await fs.fetchFolders() }
                .task { await fs.fetchFiles(); await fs.fetchFolders() }
                .navigationDestination(isPresented: $showFileViewer) {
                    if let f = selectedFile { NFileViewer(file: f) }
                }
                .sheet(isPresented: $showUpload) { NFileUploadSheet() }
                .sheet(isPresented: $showCreateFolder) { createFolderSheet }
                .sheet(isPresented: $showRenameFolder) { renameFolderSheet }
        }
    }

    // MARK: - Create Folder
    private var createFolderSheet: some View {
        NavigationStack {
            Form {
                Section("Ordner-Name") {
                    TextField("z.B. Rechnungen", text: $newFolderName)
                }
            }
            .navigationTitle("Ordner erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { showCreateFolder = false; newFolderName = "" } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        Task {
                            await fs.createFolder(name: newFolderName, parent: fs.selectedFolder ?? "")
                            await fs.fetchFolders()
                            showCreateFolder = false
                            newFolderName = ""
                        }
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Rename Folder
    private var renameFolderSheet: some View {
        NavigationStack {
            Form {
                Section("Ordner-Name") {
                    TextField("Name", text: $renameFolderName)
                }
            }
            .navigationTitle("Ordner umbenennen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { showRenameFolder = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task {
                            if let folder = folderToEdit {
                                await fs.renameFolder(from: folder, to: renameFolderName)
                                await fs.fetchFolders()
                            }
                            showRenameFolder = false
                        }
                    }
                    .disabled(renameFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Main Content
    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Dateien").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                    Spacer()
                    Text("\(fs.filteredFiles.count)").font(.subheadline).foregroundColor(.ncMuted)
                }

                HStack {
                    Image(systemName: "magnifyingglass").font(.caption).foregroundColor(.ncSand)
                    TextField("Suchen...", text: $searchText).font(.subheadline)
                }
                .padding(10)
                .background(Color.ncPaper, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ncSand.opacity(0.3)))

                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NAFilesService.FileFilter.allCases, id: \.rawValue) { filter in
                            Button {
                                fs.activeFilter = filter
                                fs.selectedFolder = nil
                            } label: {
                                Text(filter.rawValue)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(fs.activeFilter == filter ? .white : .ncDark)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(fs.activeFilter == filter ? Color.ncGreen : Color.ncPaper)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(fs.activeFilter == filter ? Color.ncGreen : Color.ncSand.opacity(0.4), lineWidth: 1))
                            }
                        }
                    }
                }

                // Action Buttons
                HStack(spacing: 8) {
                    Button { showUpload = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.doc.fill").font(.caption)
                            Text("Upload").font(.caption.weight(.medium))
                        }
                        .foregroundColor(.ncGreen)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.ncGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Button { showCreateFolder = true; newFolderName = "" } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus").font(.caption)
                            Text("Ordner").font(.caption.weight(.medium))
                        }
                        .foregroundColor(.ncSage)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.ncSage.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    if fs.selectedFolder != nil {
                        Button { fs.selectedFolder = nil } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left").font(.caption)
                                Text("Zuruck").font(.caption.weight(.medium))
                            }
                            .foregroundColor(.ncMuted)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.ncSand.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if fs.isLoading && fs.files.isEmpty {
                    VStack(spacing: 12) { ProgressView(); Text("Lade Dateien...").font(.subheadline).foregroundColor(.ncMuted) }.warmCard()
                } else {
                    let displayFiles = filteredBySearch()

                    if fs.selectedFolder == nil {
                        let folderList = buildFolderList()
                        if !folderList.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ordner").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                                ForEach(folderList) { folder in
                                    folderRow(folder)
                                }
                            }
                        }
                    }

                    if displayFiles.isEmpty {
                        HStack { Image(systemName: "doc").font(.title2).foregroundColor(.ncSand); Text("Keine Dateien").font(.subheadline).foregroundColor(.ncMuted) }.warmCard()
                    } else {
                        let grouped = Dictionary(grouping: displayFiles) { $0.type }
                        let order = ["pdf", "docx", "html", "md", "txt", "image", "other"]
                        ForEach(order, id: \.self) { key in
                            if let items = grouped[key], !items.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(catLabel(key)).font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                                    ForEach(items) { file in
                                        fileRow(file)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
    }

    // MARK: - Folder Row
    private func folderRow(_ folder: NFolder) -> some View {
        Button {
            fs.selectedFolder = folder.name
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill").font(.title3).foregroundColor(.ncSage).frame(width: 28)
                Text(folder.name).font(.subheadline.weight(.medium)).foregroundColor(.ncDark)
                Spacer()
                Text("\(folder.fileCount)").font(.caption).foregroundColor(.ncMuted)
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
            }
            .padding(10)
            .background(Color.white.opacity(0.6)).cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Umbenennen") {
                folderToEdit = folder.name
                renameFolderName = folder.name
                showRenameFolder = true
            }
            Button("Loschen", role: .destructive) {
                folderToEdit = folder.name
                showDeleteConfirm = true
            }
        }
        .alert("Ordner loschen?", isPresented: $showDeleteConfirm) {
            Button("Loschen", role: .destructive) {
                Task {
                    if let folder = folderToEdit {
                        await fs.deleteFolder(folder)
                        await fs.fetchFolders()
                        await fs.fetchFiles()
                    }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Ordner wird geloscht. Dateien bleiben erhalten.")
        }
    }

    // MARK: - File Row
    private func fileRow(_ file: NFile) -> some View {
        Button {
            selectedFile = file
            showFileViewer = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: file.icon).font(.title3).foregroundColor(file.color).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name).font(.subheadline.weight(.medium)).foregroundColor(.ncDark).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(file.sizeLabel).font(.caption2).foregroundColor(.ncMuted)
                        Text(file.dateLabel).font(.caption2).foregroundColor(.ncMuted)
                        if let s = file.source {
                            Text(sourceLabel(s)).font(.caption2).foregroundColor(sourceColor(s))
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.ncSand)
            }
            .padding(10)
            .background(Color.white.opacity(0.6)).cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Offnen") { selectedFile = file; showFileViewer = true }
            Button("Teilen") {
                let url = URL(string: "https://health.santoslab.de/api/naice/files/download?path=" + file.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first,
                   let root = window.rootViewController {
                    root.present(av, animated: true)
                }
            }
        }
    }

    // MARK: - Helpers
    private func filteredBySearch() -> [NFile] {
        let base = fs.filteredFiles
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func buildFolderList() -> [NFolder] {
        return fs.serverFolders.map { name in
            let count = fs.files.filter { $0.folder == name || $0.folder == "uploads/" + name }.count
            return NFolder(name: name, fileCount: count)
        }
    }

    private func catLabel(_ t: String) -> String {
        switch t {
        case "pdf": return "PDFs"
        case "docx": return "Dokumente"
        case "html": return "HTML"
        case "md": return "Markdown"
        case "txt": return "Text"
        case "image": return "Bilder"
        default: return "Sonstiges"
        }
    }

    private func sourceLabel(_ s: String) -> String {
        switch s {
        case "upload": return "Upload"
        case "ki": return "KI"
        case "workspace": return "WS"
        default: return s
        }
    }

    private func sourceColor(_ s: String) -> Color {
        switch s {
        case "upload": return .ncGreen
        case "ki": return .ncGold
        case "workspace": return .blue
        default: return .ncMuted
        }
    }
}