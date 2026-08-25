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
    @State private var showFolderContext = false
    @State private var showMoveFile = false
    @State private var moveTargetFolder = ""

    var body: some View {
        NavigationStack {
            content
                .warmBackground()
                .navigationTitle(fs.selectedFolder != nil && !fs.selectedFolder!.isEmpty ? fs.selectedFolder! : "Dateien")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable { await fs.fetchFiles() }
                .task { await fs.fetchFiles() }
                .navigationDestination(isPresented: $showFileViewer) {
                    if let f = selectedFile { NFileViewer(file: f) }
                }
                .sheet(isPresented: $showUpload) { NFileUploadSheet() }
                .sheet(isPresented: $showCreateFolder) {
                    createFolderSheet
                }
        }
    }

    // MARK: - Create Folder Sheet
    private var createFolderSheet: some View {
        NavigationStack {
            Form {
                Section("Ordner-Name") {
                    TextField("z.B. Rechnungen", text: $newFolderName)
                }
                if let parent = fs.selectedFolder, !parent.isEmpty {
                    Section("In") {
                        Text(parent).font(.subheadline).foregroundColor(.ncMuted)
                    }
                }
            }
            .navigationTitle("Ordner erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { showCreateFolder = false; newFolderName = "" } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        Task {
                            await fs.createFolder(name: newFolderName, parent: fs.selectedFolder ?? "")
                            showCreateFolder = false
                            newFolderName = ""
                        }
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Text("Dateien").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                    Spacer()
                    Text("\(fs.filteredFiles.count)").font(.subheadline).foregroundColor(.ncMuted)
                }

                // Search
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

                // Action Buttons Row
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
                    if let folder = fs.selectedFolder, !folder.isEmpty {
                        Button {
                            fs.selectedFolder = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left").font(.caption)
                                Text("Zurück").font(.caption.weight(.medium))
                            }
                            .foregroundColor(.ncMuted)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.ncSand.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Loading
                if fs.isLoading && fs.files.isEmpty {
                    VStack(spacing: 12) { ProgressView(); Text("Lade Dateien...").font(.subheadline).foregroundColor(.ncMuted) }.warmCard()
                } else {
                    let displayFiles = filteredBySearch()

                    // Show folders when in root
                    if fs.selectedFolder == nil || fs.selectedFolder!.isEmpty {
                        let folderList = buildFolderList()
                        if !folderList.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ordner").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                                ForEach(folderList) { folder in
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
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Files
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
                                        fileContextRow(file)
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

    private func filteredBySearch() -> [NFile] {
        let base = fs.filteredFiles
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func buildFolderList() -> [NFolder] {
        let folderDict = Dictionary(grouping: fs.filteredFiles) { $0.folder ?? "" }
        return folderDict.filter { !$0.key.isEmpty }.map { NFolder(name: $0.key, fileCount: $0.value.count) }.sorted { $0.name < $1.name }
    }

    // MARK: - File Row with Context Menu
    private func fileContextRow(_ file: NFile) -> some View {
        Button { selectedFile = file; showFileViewer = true } label: {
            fileRow(file)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Öffnen") { selectedFile = file; showFileViewer = true }
            Button("In Ordner verschieben") {
                selectedFile = file
                showMoveFile = true
            }
            Divider()
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
        .confirmationDialog("In Ordner verschieben", isPresented: $showMoveFile, titleVisibility: .visible) {
            let folderList = buildFolderList()
            ForEach(folderList) { folder in
                Button(folder.name) {
                    if let file = selectedFile {
                        Task { await fs.moveFile(file: file, toFolder: "/opt/naice-agent-data/uploads/" + folder.name) }
                    }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private func fileRow(_ file: NFile) -> some View {
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

    private func catLabel(_ t: String) -> String {
        switch t {
        case "pdf": return "📄 PDFs"
        case "docx": return "📝 Dokumente"
        case "html": return "🌐 HTML"
        case "md": return "📋 Markdown"
        case "txt": return "📃 Text"
        case "image": return "🖼️ Bilder"
        default: return "📦 Sonstiges"
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