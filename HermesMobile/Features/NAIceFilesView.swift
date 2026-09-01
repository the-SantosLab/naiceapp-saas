import SwiftUI

// MARK: - Files Tab (Neubau: Suche, Sortierung, Filter, Löschen, Teilen, Verschieben)
struct NAIceFilesView: View {
    @ObservedObject private var fs = NAFilesService.shared
    @State private var searchText = ""
    @State private var showSortPicker = false
    @State private var showUpload = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var showRenameFolder = false
    @State private var renameFolderName = ""
    @State private var folderToEdit: String?
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: NFile?
    @State private var showMoveSheet = false
    @State private var fileToMove: NFile?
    @State private var showShareConfirm = false
    @State private var fileToShare: NFile?
    @State private var shareFileURL: URL?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let folder = fs.selectedFolder, !folder.isEmpty {
                            Text(folder)
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                        } else {
                            Text("Dateien")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                        }
                        Text("\(currentCount) Dateien")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        if fs.isLoading {
                            ProgressView().scaleEffect(0.7).tint(.ncCyan)
                        }
                        // Sort Button
                        Button { showSortPicker = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down").font(.caption)
                                Text(fs.sortBy.rawValue).font(.caption2)
                            }
                            .foregroundColor(.ncCyan)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.ncCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.subheadline).foregroundColor(.gray)
                    TextField("Suchen...", text: $searchText)
                        .font(.subheadline).foregroundColor(.white)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").font(.caption).foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                .padding(.horizontal, 16)

                // Filter + Action Bar
                HStack(spacing: 8) {
                    // Source Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(NAFilesService.FileFilter.allCases, id: \.rawValue) { filter in
                                Button {
                                    fs.activeFilter = filter
                                    if fs.selectedFolder != nil { fs.selectedFolder = nil }
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(fs.activeFilter == filter ? .white : .gray)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(fs.activeFilter == filter ? Color.ncCyan : Color(red: 0.03, green: 0.03, blue: 0.06), in: Capsule())
                                        .overlay(Capsule().stroke(fs.activeFilter == filter ? Color.ncCyan : Color.white.opacity(0.08), lineWidth: 0.5))
                                }
                            }
                        }
                    }

                    // Type Filter
                    Picker("", selection: $fs.typeFilter) {
                        ForEach(FileTypeFilter.allCases, id: \.rawValue) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.gray)
                    .scaleEffect(0.85)
                }
                .padding(.horizontal, 16)

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
                        Button { fs.selectedFolder = nil; Task { await fs.fetchFiles() } } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left").font(.caption)
                                Text("Zurück").font(.caption.weight(.medium))
                            }
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 16)

                if fs.isLoading && fs.files.isEmpty {
                    loadingState
                } else {
                    let displayFiles = currentDisplayFiles

                    // Ordner-Ansicht (nur wenn kein Ordner ausgewählt)
                    if fs.selectedFolder == nil {
                        let folderList = buildFolderList()
                        if !folderList.isEmpty {
                            sectionCard("Ordner") {
                                ForEach(folderList) { folder in
                                    folderRow(folder)
                                }
                            }
                        }
                        // Dateien ohne Ordner
                        let rootFiles = displayFiles.filter { $0.folder == nil || $0.folder!.isEmpty }
                        if !rootFiles.isEmpty {
                            sectionCard("Dateien") {
                                ForEach(rootFiles) { file in
                                    fileRow(file)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                fileToDelete = file
                                                showDeleteConfirm = true
                                            } label: {
                                                Label("Löschen", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    } else {
                        // Dateien im aktuellen Ordner
                        if displayFiles.isEmpty && !fs.isLoading {
                            emptyState
                        } else {
                            sectionCard("Inhalt") {
                                ForEach(displayFiles) { file in
                                    fileRow(file)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                fileToDelete = file
                                                showDeleteConfirm = true
                                            } label: {
                                                Label("Löschen", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }

                    if displayFiles.isEmpty && fs.selectedFolder == nil {
                        let rootFiles = currentDisplayFiles.filter { $0.folder == nil || $0.folder!.isEmpty }
                        if rootFiles.isEmpty && buildFolderList().isEmpty {
                            emptyState
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
        .sheet(isPresented: $showSortPicker) { sortPickerSheet }
        .sheet(isPresented: $showMoveSheet) { moveSheet }
        .alert("Datei löschen?", isPresented: $showDeleteConfirm) {
            Button("Löschen", role: .destructive) {
                if let file = fileToDelete {
                    Task { await fs.deleteFile(file) }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("\(fileToDelete?.name ?? "") wird unwiderruflich gelöscht.")
        }
    }

    // MARK: - Computed
    private var currentCount: Int {
        if fs.selectedFolder != nil {
            return currentDisplayFiles.count
        }
        return fs.files.count
    }

    private var currentDisplayFiles: [NFile] {
        var result: [NFile]
        if let folder = fs.selectedFolder, !folder.isEmpty {
            result = fs.files.filter { $0.folder == folder || $0.folder == "uploads/" + folder }
        } else {
            result = fs.files
        }

        // Source filter
        if let sv = fs.activeFilter.serverValue {
            result = result.filter { $0.source == sv }
        }

        // Type filter
        if fs.typeFilter != .all {
            result = result.filter { typeMatches($0.type) }
        }

        // Search
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort
        result.sort { a, b in
            let r: Bool
            switch fs.sortBy {
            case .date: r = a.mtime > b.mtime
            case .name: r = a.name.lowercased() < b.name.lowercased()
            case .size: r = a.size > b.size
            case .type: r = a.type < b.type
            }
            return fs.sortAscending ? !r : r
        }

        return result
    }

    private func typeMatches(_ t: String) -> Bool {
        switch fs.typeFilter {
        case .all: return true
        case .pdf: return t == "pdf"
        case .image: return t == "image"
        case .text: return ["txt", "md", "docx"].contains(t)
        case .html: return t == "html"
        case .other: return !["pdf", "image", "txt", "md", "docx", "html"].contains(t)
        }
    }

    // MARK: - States
    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(0.8).tint(.ncCyan)
            Text("Lade Dateien...").font(.subheadline).foregroundColor(.gray)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04)))
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc").font(.title2).foregroundColor(.gray.opacity(0.5))
            Text("Keine Dateien").font(.subheadline).foregroundColor(.gray)
            if !searchText.isEmpty {
                Text("Keine Treffer") + Text(" fuer ") + Text("\"" + searchText + "\"").font(.caption).foregroundColor(.gray)
                    .font(.caption).foregroundColor(.gray)
            }
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
        .padding(.horizontal, 16)
    }

    // MARK: - Sort Picker
    private var sortPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(FileSortBy.allCases, id: \.rawValue) { sort in
                    Button {
                        if fs.sortBy == sort {
                            fs.sortAscending.toggle()
                        } else {
                            fs.sortBy = sort
                            fs.sortAscending = false
                        }
                        showSortPicker = false
                    } label: {
                        HStack {
                            Text(sort.rawValue).foregroundColor(.white)
                            Spacer()
                            if fs.sortBy == sort {
                                Image(systemName: fs.sortAscending ? "arrow.up" : "arrow.down")
                                    .foregroundColor(.ncCyan)
                            }
                        }
                    }
                }
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .navigationTitle("Sortieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { showSortPicker = false }
                        .foregroundColor(.ncCyan)
                }
            }
        }
    }

    // MARK: - Move Sheet
    private var moveSheet: some View {
        NavigationStack {
            List {
                if let file = fileToMove {
                    Text("Verschieben: \(file.name)")
                        .font(.subheadline).foregroundColor(.gray)
                }
                Button("Kein Ordner (Stammverzeichnis)") {
                    if let file = fileToMove {
                        Task { await fs.moveFile(file, toFolder: ""); showMoveSheet = false }
                    }
                }
                .foregroundColor(.white)
                ForEach(fs.serverFolders, id: \.self) { folder in
                    Button(folder) {
                        if let file = fileToMove {
                            Task { await fs.moveFile(file, toFolder: folder); showMoveSheet = false }
                        }
                    }
                    .foregroundColor(.white)
                }
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .navigationTitle("Verschieben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") { showMoveSheet = false }
                        .foregroundColor(.ncCyan)
                }
            }
        }
    }

    // MARK: - Folder Row
    private func folderRow(_ folder: NFolder) -> some View {
        Button {
            fs.selectedFolder = folder.name
            Task { await fs.fetchFilesInFolder(folder.name) }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.ncCyan.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: "folder.fill").font(.system(size: 12)).foregroundColor(.ncCyan)
                }
                Text(folder.name).font(.subheadline.weight(.medium)).foregroundColor(.white)
                Spacer()
                Text("\(folder.fileCount)").font(.caption).foregroundColor(.gray)
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray.opacity(0.5))
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
            Button("Löschen", role: .destructive) {
                folderToEdit = folder.name
                showDeleteConfirm = true
            }
        }
    }

    // MARK: - File Row
    private func fileRow(_ file: NFile) -> some View {
        NavigationLink(destination: NFileViewer(file: file)) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(file.color.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: file.icon).font(.system(size: 12)).foregroundColor(file.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name).font(.subheadline.weight(.medium)).foregroundColor(.white).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(file.sizeLabel).font(.caption2).foregroundColor(.gray)
                        Text(file.dateLabel).font(.caption2).foregroundColor(.gray)
                        if let s = file.source {
                            Text(sourceLabel(s)).font(.caption2).foregroundColor(sourceColor(s))
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray.opacity(0.5))
            }
            .padding(10)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Öffnen") {}
            Button {
                // Teilen – echte Datei
                Task {
                    if let url = await fs.downloadForSharing(file) {
                        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first,
                           let root = window.rootViewController {
                            root.present(av, animated: true)
                        }
                    }
                }
            } label: {
                Label("Teilen", systemImage: "square.and.arrow.up")
            }
            Button {
                fileToMove = file
                showMoveSheet = true
            } label: {
                Label("Verschieben", systemImage: "folder")
            }
            Button(role: .destructive) {
                fileToDelete = file
                showDeleteConfirm = true
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    // MARK: - Section Card
    private func sectionCard(_ title: String, @ViewBuilder content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                Spacer()
            }
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers
    private func buildFolderList() -> [NFolder] {
        var result: [NFolder] = []
        for name in fs.serverFolders {
            let count = fs.files.filter { f in
                (f.folder == name || f.folder == "uploads/" + name) &&
                (fs.activeFilter == .all || f.source == fs.activeFilter.serverValue)
            }.count
            if count > 0 {
                result.append(NFolder(name: name, fileCount: count))
            }
        }
        return result
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

    // MARK: - Create Folder
    private var createFolderSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ordner erstellen").font(.headline.weight(.bold)).foregroundColor(.white)
                TextField("z.B. Rechnungen", text: $newFolderName)
                    .font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
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
                .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24).background(Color.black.ignoresSafeArea())
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
                Text("Ordner umbenennen").font(.headline.weight(.bold)).foregroundColor(.white)
                TextField("Name", text: $renameFolderName)
                    .font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
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
                .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(renameFolderName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(renameFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24).background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { showRenameFolder = false }
                        .foregroundColor(.ncCyan)
                }
            }
        }
    }
}