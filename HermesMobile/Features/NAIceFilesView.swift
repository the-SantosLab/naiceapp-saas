import SwiftUI

struct NAIceFilesView: View {
    @ObservedObject private var fs = NAFilesService.shared
    @State private var searchText = ""
    @State private var showSortSheet = false
    @State private var showUpload = false
    @State private var showCreateFolderSheet = false
    @State private var folderName = ""
    @State private var showRenameFolderSheet = false
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: NFile?
    @State private var showMoveSheet = false
    @State private var fileToMove: NFile?
    @State private var deleteTargetIsFolder = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                FilesHeader(fs: fs, onSort: { showSortSheet = true }).padding(.horizontal, 20).padding(.top, 8)
                FilesSearch(text: $searchText).padding(.horizontal, 16)
                FilesFilterBar(fs: fs).padding(.horizontal, 16)
                FilesActionBar(fs: fs, onUpload: { showUpload = true }, onCreateFolder: { showCreateFolderSheet = true }).padding(.horizontal, 16)
                if fs.isLoading && fs.files.isEmpty {
                    ProgressView().padding()
                } else {
                    FilesFolderSection(fs: fs).padding(.horizontal, 16)
                    FilesListSection(fs: fs, searchText: searchText, onDelete: { fileToDelete = $0; deleteTargetIsFolder = false; showDeleteConfirm = true }, onMove: { fileToMove = $0; showMoveSheet = true })
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .refreshable { await fs.fetchFiles(); await fs.fetchFolders() }
        .task { await fs.fetchFiles(); await fs.fetchFolders() }
        .sheet(isPresented: $showUpload) { NFileUploadSheet() }
        .sheet(isPresented: $showSortSheet) { sortSheetContent }
        .sheet(isPresented: $showCreateFolderSheet) { createSheetContent }
        .sheet(isPresented: $showRenameFolderSheet) { renameSheetContent }
        .sheet(isPresented: $showMoveSheet) { moveSheetContent }
        .alert(deleteTargetIsFolder ? "Loschen?" : "Datei loschen?", isPresented: $showDeleteConfirm) {
            Button("Loschen", role: .destructive) { performDelete() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(deleteTargetIsFolder ? "Ordner wird geloscht." : (fileToDelete?.name ?? "") + " wird geloscht.")
        }
    }

    private var sortSheetContent: some View {
        NavigationStack {
            List {
                ForEach(FileSortBy.allCases, id: \.rawValue) { s in
                    Button { if fs.sortBy == s { fs.sortAscending.toggle() } else { fs.sortBy = s; fs.sortAscending = false }; showSortSheet = false } label: {
                        HStack { Text(s.rawValue).foregroundColor(.white); Spacer(); if fs.sortBy == s { Image(systemName: fs.sortAscending ? "arrow.up" : "arrow.down").foregroundColor(.ncCyan) } }
                    }
                }
            }
            .background(Color.black).scrollContentBackground(.hidden)
            .navigationTitle("Sortieren").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Fertig") { showSortSheet = false }.foregroundColor(.ncCyan) } }
        }
    }

    private var createSheetContent: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ordner erstellen").font(.headline.weight(.bold)).foregroundColor(.white)
                TextField("Name", text: $folderName).font(.subheadline).foregroundColor(.white).padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                Button("Erstellen") { Task { await fs.createFolder(name: folderName); await fs.fetchFolders() }; showCreateFolderSheet = false; folderName = "" }
                    .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding(.vertical, 14).background(folderName.isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                    .disabled(folderName.isEmpty).padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24).background(Color.black.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { showCreateFolderSheet = false; folderName = "" }.foregroundColor(.ncCyan) } }
        }
    }

    private var renameSheetContent: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Umbenennen").font(.headline.weight(.bold)).foregroundColor(.white)
                TextField("Name", text: $folderName).font(.subheadline).foregroundColor(.white).padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                Button("Speichern") { Task { await fs.renameFolder(from: folderName, to: folderName); await fs.fetchFolders() }; showRenameFolderSheet = false }
                    .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding(.vertical, 14).background(folderName.isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                    .disabled(folderName.isEmpty).padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24).background(Color.black.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { showRenameFolderSheet = false }.foregroundColor(.ncCyan) } }
        }
    }

    private var moveSheetContent: some View {
        NavigationStack {
            List {
                if let f = fileToMove {
                    Text(f.name).font(.subheadline).foregroundColor(.gray)
                    Button("Stammverzeichnis") { Task { await fs.moveFile(f, toFolder: ""); showMoveSheet = false } }.foregroundColor(.white)
                    ForEach(fs.serverFolders, id: \.self) { folder in Button(folder) { Task { await fs.moveFile(f, toFolder: folder); showMoveSheet = false } }.foregroundColor(.white) }
                }
            }
            .background(Color.black).scrollContentBackground(.hidden)
            .navigationTitle("Verschieben").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("OK") { showMoveSheet = false }.foregroundColor(.ncCyan) } }
        }
    }

    private func performDelete() {
        if deleteTargetIsFolder { Task { await fs.deleteFolder(folderName); await fs.fetchFolders() } }
        else if let f = fileToDelete { Task { await fs.deleteFile(f) } }
    }
}