import SwiftUI

struct SortPickerSheet: View {
    @ObservedObject var fs: NAFilesService
    @Binding var show: Bool
    var body: some View {
        NavigationStack {
            List {
                ForEach(FileSortBy.allCases, id: \.rawValue) { s in
                    Button {
                        if fs.sortBy == s { fs.sortAscending.toggle() }
                        else { fs.sortBy = s; fs.sortAscending = false }
                        show = false
                    } label: {
                        HStack {
                            Text(s.rawValue).foregroundColor(.white)
                            Spacer()
                            if fs.sortBy == s {
                                Image(systemName: fs.sortAscending ? "arrow.up" : "arrow.down").foregroundColor(.ncCyan)
                            }
                        }
                    }
                }
            }
            .background(Color.black).scrollContentBackground(.hidden)
            .navigationTitle("Sortieren").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Fertig") { show = false }.foregroundColor(.ncCyan) } }
        }
    }
}

struct CreateFolderSheet: View {
    @ObservedObject var fs: NAFilesService
    @Binding var show: Bool
    @State private var name = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ordner erstellen").font(.headline.weight(.bold)).foregroundColor(.white)
                TextField("Name", text: $name).font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                Button("Erstellen") {
                    Task { await fs.createFolder(name: name); await fs.fetchFolders() }
                    show = false; name = ""
                }
                .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                .padding(.vertical, 14).background(name.isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(name.isEmpty).padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24).background(Color.black.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { show = false; name = "" }.foregroundColor(.ncCyan) } }
        }
    }
}

struct RenameFolderSheet: View {
    let current: String
    let onRename: (String) -> Void
    @Binding var show: Bool
    @State private var name = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ordner umbenennen").font(.headline.weight(.bold)).foregroundColor(.white)
                TextField("Name", text: $name).font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                Button("Speichern") { onRename(name); show = false }
                    .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding(.vertical, 14).background(name.isEmpty ? Color.gray.opacity(0.3) : Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                    .disabled(name.isEmpty).padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 24).background(Color.black.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { show = false }.foregroundColor(.ncCyan) } }
        }
        .onAppear { name = current }
    }
}

struct MoveSheetView: View {
    let file: NFile
    let folders: [String]
    let onMove: (String) -> Void
    @Binding var show: Bool
    var body: some View {
        NavigationStack {
            List {
                Text(file.name).font(.subheadline).foregroundColor(.gray)
                Button("Stammverzeichnis") { onMove(""); show = false }.foregroundColor(.white)
                ForEach(folders, id: \.self) { f in
                    Button(f) { onMove(f); show = false }.foregroundColor(.white)
                }
            }
            .background(Color.black).scrollContentBackground(.hidden)
            .navigationTitle("Verschieben").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Abbrechen") { show = false }.foregroundColor(.ncCyan) } }
        }
    }
}