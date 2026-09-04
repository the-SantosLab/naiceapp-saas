import SwiftUI

struct NAIceFilesView: View {
    @ObservedObject private var fs = NAFilesService.shared
    @State private var searchText = ""
    @State private var showSort = false
    @State private var showUpload = false
    @State private var showCreate = false
    @State private var showRename = false
    @State private var folderName = ""
    @State private var showDelete = false
    @State private var fileToDelete: NFile?
    @State private var showMove = false
    @State private var fileToMove: NFile?
    @State private var delIsFolder = false
    @State private var isSelecting = false
    @State private var selectedFiles = Set<String>()
    @State private var showBatchMove = false
    @State private var showBatchDelete = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    FilesHeader(fs: fs, onSort: { showSort = true }, isSelecting: $isSelecting).padding(.horizontal, 20).padding(.top, 8)
                    FilesSearch(text: $searchText).padding(.horizontal, 16)
                    FilesFilterBar(fs: fs).padding(.horizontal, 16)
                    FilesActionBar(fs: fs, onUpload: { showUpload = true }, onCreateFolder: { showCreate = true }).padding(.horizontal, 16)
                    if fs.isLoading && fs.files.isEmpty { ProgressView().padding() }
                    else {
                        FilesFolderSection(fs: fs).padding(.horizontal, 16)
                        FilesListSection(fs: fs, searchText: searchText,
                            isSelecting: $isSelecting, selectedFiles: $selectedFiles,
                            onDelete: { fileToDelete = $0; delIsFolder = false; showDelete = true },
                            onMove: { fileToMove = $0; showMove = true })
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .refreshable { await fs.fetchFiles(); await fs.fetchFolders() }
            .task { await fs.fetchFiles(); await fs.fetchFolders() }

            // Batch Action Bar
            if isSelecting && !selectedFiles.isEmpty {
                batchActionBar
            }
        }
        .sheet(isPresented: $showSort) { sortSheet }
        .sheet(isPresented: $showUpload) { NFileUploadSheet() }
        .sheet(isPresented: $showCreate) { createSheet }
        .sheet(isPresented: $showRename) { renameSheet }
        .sheet(isPresented: $showMove) { moveSheet }
        .sheet(isPresented: $showBatchMove) { batchMoveSheet }
        .alert(delIsFolder ? "Loschen?" : "Datei loschen?", isPresented: $showDelete) {
            Button("Loschen", role: .destructive) { performDelete() }
            Button(FileActionLabel.cancel.rawValue, role: .cancel) {}
        } message: {
            Text(delIsFolder ? "Ordner wird geloscht." : (fileToDelete?.name ?? "") + " wird geloscht.")
        }
        .alert("\(selectedFiles.count) Dateien loschen?", isPresented: $showBatchDelete) {
            Button("Loschen", role: .destructive) { performBatchDelete() }
            Button(FileActionLabel.cancel.rawValue, role: .cancel) {}
        } message: {
            Text("Die ausgewahlten Dateien werden dauerhaft geloscht.")
        }
    }

    // MARK: - Batch Action Bar
    private var batchActionBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedFiles.count) ausgewahlt")
                .font(.subheadline.weight(.medium)).foregroundColor(.white)
            Spacer()
            Button { showBatchMove = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder").font(.caption)
                    Text("Verschieben").font(.caption.weight(.medium))
                }
                .foregroundColor(.ncCyan).padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.ncCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            Button { showBatchDelete = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash").font(.caption)
                    Text("Loschen").font(.caption.weight(.medium))
                }
                .foregroundColor(.ncRose).padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.ncRose.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            Button { isSelecting = false; selectedFiles.removeAll() } label: {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.06)), alignment: .top)
    }

    // MARK: - Batch Move Sheet
    private var batchMoveSheet: some View {
        NavigationStack {
            List {
                Text("\(selectedFiles.count) Dateien").font(.subheadline).foregroundColor(.gray)
                Button(FileActionLabel.root.rawValue) {
                    let files = fs.files.filter { selectedFiles.contains($0.id) }
                    Task {
                        for file in files { await fs.moveFile(file, toFolder: "") }
                        await fs.fetchFiles()
                        showBatchMove = false; isSelecting = false; selectedFiles.removeAll()
                    }
                }.foregroundColor(.white)
                ForEach(Array(fs.serverFolders), id: \.self) { folder in
                    Button(folder) {
                        let files = fs.files.filter { selectedFiles.contains($0.id) }
                        Task {
                            for file in files { await fs.moveFile(file, toFolder: folder) }
                            await fs.fetchFiles()
                            showBatchMove = false; isSelecting = false; selectedFiles.removeAll()
                        }
                    }.foregroundColor(.white)
                }
            }
            .background(Color.black).scrollContentBackground(.hidden)
            .navigationTitle("Verschieben").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(FileActionLabel.ok.rawValue) { showBatchMove = false }.foregroundColor(.ncCyan) } }
        }
    }

    private var sortSheet: some View { NavigationStack { List { ForEach(Array(FileSortBy.allCases), id: \.rawValue) { s in Button { if fs.sortBy == s { fs.sortAscending.toggle() } else { fs.sortBy = s; fs.sortAscending = false }; showSort = false } label: { HStack { Text(s.rawValue).foregroundColor(.white); Spacer(); if fs.sortBy == s { Image(systemName: fs.sortAscending ? "arrow.up" : "arrow.down").foregroundColor(.ncCyan) } } } } } .background(Color.black).scrollContentBackground(.hidden).navigationTitle(FileActionLabel.sort.rawValue).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(FileActionLabel.done.rawValue) { showSort = false }.foregroundColor(.ncCyan) } } } }
    private var createSheet: some View { NavigationStack { VStack(spacing: 20) { Text(FileActionLabel.create.rawValue).font(.headline.weight(.bold)).foregroundColor(.white); TextField("Name", text: $folderName).font(.subheadline).foregroundColor(.white).padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10)); Button(FileActionLabel.createBtn.rawValue) { Task { await fs.createFolder(name: folderName); await fs.fetchFolders() }; showCreate = false; folderName = "" }.font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(folderName.isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14)).disabled(folderName.isEmpty).padding(.horizontal, 20); Spacer() } .padding(.top, 24).background(Color.black.ignoresSafeArea()).toolbar { ToolbarItem(placement: .navigationBarLeading) { Button(FileActionLabel.cancel.rawValue) { showCreate = false; folderName = "" }.foregroundColor(.ncCyan) } } } }
    private var renameSheet: some View { NavigationStack { VStack(spacing: 20) { Text(FileActionLabel.rename.rawValue).font(.headline.weight(.bold)).foregroundColor(.white); TextField("Name", text: $folderName).font(.subheadline).foregroundColor(.white).padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10)); Button(FileActionLabel.save.rawValue) { Task { await fs.renameFolder(from: folderName, to: folderName); await fs.fetchFolders() }; showRename = false }.font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(folderName.isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14)).disabled(folderName.isEmpty).padding(.horizontal, 20); Spacer() } .padding(.top, 24).background(Color.black.ignoresSafeArea()).toolbar { ToolbarItem(placement: .navigationBarLeading) { Button(FileActionLabel.cancel.rawValue) { showRename = false }.foregroundColor(.ncCyan) } } } }
    private var moveSheet: some View { NavigationStack { List { if let f = fileToMove { Text(f.name).font(.subheadline).foregroundColor(.gray); Button(FileActionLabel.root.rawValue) { Task { await fs.moveFile(f, toFolder: ""); showMove = false } }.foregroundColor(.white); ForEach(Array(fs.serverFolders), id: \.self) { folder in Button(folder) { Task { await fs.moveFile(f, toFolder: folder); showMove = false } }.foregroundColor(.white) } } } .background(Color.black).scrollContentBackground(.hidden).navigationTitle(FileActionLabel.move.rawValue).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(FileActionLabel.ok.rawValue) { showMove = false }.foregroundColor(.ncCyan) } } } }

    private func performDelete() {
        if delIsFolder { Task { await fs.deleteFolder(folderName); await fs.fetchFolders() } }
        else if let f = fileToDelete { Task { await fs.deleteFile(f) } }
    }

    private func performBatchDelete() {
        Task {
            for file in fs.files.filter({ selectedFiles.contains($0.id) }) {
                _ = await fs.deleteFile(file)
            }
            await fs.fetchFiles()
            isSelecting = false; selectedFiles.removeAll()
        }
    }
}