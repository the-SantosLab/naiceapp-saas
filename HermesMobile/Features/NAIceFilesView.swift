import SwiftUI

// MARK: - Files Tab (Modern Dark Theme)
struct NAIceFilesView: View {
    @ObservedObject private var fs = NAFilesService.shared
    @State private var searchText = ""
    @State private var selectedFile: NFile?
    @State private var showUpload = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var showRenameFolder = false
    @State private var renameFolderName = ""
    @State private var folderToEdit: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dateien")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text("\(fs.filteredFiles.count) Dateien")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if fs.isLoading {
                        ProgressView().scaleEffect(0.7).tint(.ncCyan)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("Suchen...", text: $searchText)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                .padding(.horizontal, 16)

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
                                    .foregroundColor(fs.activeFilter == filter ? .white : .gray)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(fs.activeFilter == filter ? Color.ncCyan : Color(red: 0.03, green: 0.03, blue: 0.06), in: Capsule())
                                    .overlay(Capsule().stroke(fs.activeFilter == filter ? Color.ncCyan : Color.white.opacity(0.08), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Action Buttons
                HStack(spacing: 8) {
                    Button { showUpload = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.doc.fill").font(.caption)
                            Text("Upload").font(.caption.weight(.medium))
                        }
                        .foregroundColor(.ncCyan)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.ncCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Button { showCreateFolder = true; newFolderName = "" } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus").font(.caption)
                            Text("Ordner").font(.caption.weight(.medium))
                        }
                        .foregroundColor(.ncNeonGreen)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.ncNeonGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    if fs.selectedFolder != nil {
                        Button { fs.selectedFolder = nil } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left").font(.caption)
                                Text("Zuruck").font(.caption.weight(.medium))
                            }
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 16)

                if fs.isLoading && fs.files.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(0.8).tint(.ncCyan)
                        Text("Lade Dateien...").font(.subheadline).foregroundColor(.gray)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 16)
                } else {
                    let displayFiles = filteredBySearch()

                    if fs.selectedFolder == nil {
                        let folderList = buildFolderList()
                        if !folderList.isEmpty {
                            sectionCard("Ordner") {
                                ForEach(folderList) { folder in
                                    folderRow(folder)
                                }
                            }
                        }
                    }

                    if displayFiles.isEmpty && !fs.isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "doc")
                                .font(.title2)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Keine Dateien")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        )
                        .padding(.horizontal, 16)
                    } else if !displayFiles.isEmpty {
                        let grouped = Dictionary(grouping: displayFiles) { $0.type }
                        let order = ["pdf", "docx", "html", "md", "txt", "image", "other"]
                        ForEach(order, id: \.self) { key in
                            if let items = grouped[key], !items.isEmpty {
                                sectionCard(catLabel(key)) {
                                    ForEach(items) { file in
                                        NavigationLink(destination: NFileViewer(file: file)) {
                                            fileRow(file)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await fs.fetchFiles(); await fs.fetchFolders() }
        .task { await fs.fetchFiles(); await fs.fetchFolders() }
        .sheet(isPresented: $showUpload) { NFileUploadSheet() }
        .sheet(isPresented: $showCreateFolder) { createFolderSheet }
        .sheet(isPresented: $showRenameFolder) { renameFolderSheet }
    }

    // MARK: - Create Folder
    private var createFolderSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ordner erstellen")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                TextField("z.B. Rechnungen", text: $newFolderName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                Button("Erstellen") {
                    Task {
                        await fs.createFolder(name: newFolderName, parent: fs.selectedFolder ?? "")
                        await fs.fetchFolders()
                        showCreateFolder = false
                        newFolderName = ""
                    }
                }
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { showCreateFolder = false; newFolderName = "" }
                        .foregroundColor(.ncCyan)
                }
            }
        }
    }

    // MARK: - Rename Folder
    private var renameFolderSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ordner umbenennen")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                TextField("Name", text: $renameFolderName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                Button("Speichern") {
                    Task {
                        if let folder = folderToEdit {
                            await fs.renameFolder(from: folder, to: renameFolderName)
                            await fs.fetchFolders()
                        }
                        showRenameFolder = false
                    }
                }
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(renameFolderName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(renameFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { showRenameFolder = false }
                        .foregroundColor(.ncCyan)
                }
            }
        }
    }

    // MARK: - Folder Row
    private func folderRow(_ folder: NFolder) -> some View {
        Button {
            fs.selectedFolder = folder.name
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.ncCyan.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.ncCyan)
                }
                Text(folder.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                Spacer()
                Text("\(folder.fileCount)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(10)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
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
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(file.color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: file.icon)
                    .font(.system(size: 12))
                    .foregroundColor(file.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(file.sizeLabel)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(file.dateLabel)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    if let s = file.source {
                        Text(sourceLabel(s))
                            .font(.caption2)
                            .foregroundColor(sourceColor(s))
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        .contextMenu {
            Button("Offnen") {
                // NavigationLink handles this
            }
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

    // MARK: - Section Card
    private func sectionCard(_ title: String, @ViewBuilder content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
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
        case "upload": return .ncNeonGreen
        case "ki": return .ncAmber
        case "workspace": return .ncCyan
        default: return .gray
        }
    }
}