import SwiftUI

struct NAIceFilesView: View {
    @ObservedObject private var fs = NAFilesService.shared
    @State private var searchText = ""
    @State private var showSortPicker = false
    @State private var showUpload = false
    @State private var showCreateFolder = false
    @State private var showRenameFolder = false
    @State private var folderToEdit: String?
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: NFile?
    @State private var showMoveSheet = false
    @State private var fileToMove: NFile?
    @State private var deleteTargetIsFolder = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                FilesHeader(fs: fs, showSortPicker: $showSortPicker)
                    .padding(.horizontal, 20).padding(.top, 8)
                FilesSearch(text: $searchText).padding(.horizontal, 16)
                FilesFilterBar(fs: fs).padding(.horizontal, 16)
                FilesActionBar(fs: fs, showUpload: $showUpload, showCreateFolder: $showCreateFolder).padding(.horizontal, 16)
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
        .sheet(isPresented: $showSortPicker) { SortPickerSheet(fs: fs, show: $showSortPicker) }
        .sheet(isPresented: $showCreateFolder) { CreateFolderSheet(fs: fs, show: $showCreateFolder) }
        .sheet(isPresented: $showRenameFolder) { RenameFolderSheet(current: folderToEdit ?? "", onRename: { n in Task { await fs.renameFolder(from: folderToEdit ?? "", to: n); await fs.fetchFolders() } }, show: $showRenameFolder) }
        .sheet(isPresented: $showMoveSheet) {
            if let f = fileToMove { MoveSheetView(file: f, folders: fs.serverFolders, onMove: { folder in Task { await fs.moveFile(f, toFolder: folder) } }, show: $showMoveSheet) }
        }
        .alert(deleteTargetIsFolder ? "Ordner loschen?" : "Datei loschen?", isPresented: $showDeleteConfirm) {
            Button("Loschen", role: .destructive) { performDelete() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(deleteTargetIsFolder ? "Ordner wird geloscht." : (fileToDelete?.name ?? "") + " wird geloscht.")
        }
    }

    private func performDelete() {
        if deleteTargetIsFolder, let f = folderToEdit { Task { await fs.deleteFolder(f); await fs.fetchFolders() } }
        else if let f = fileToDelete { Task { await fs.deleteFile(f) } }
    }
}