import SwiftUI

struct FilesSearch: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.subheadline).foregroundColor(.gray)
            TextField("Suchen...", text: $text).font(.subheadline).foregroundColor(.white)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").font(.caption).foregroundColor(.gray) } }
        }
        .padding(12).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}

struct FilesFilterBar: View {
    @ObservedObject var fs: NAFilesService
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(NAFilesService.FileFilter.allCases, id: \.rawValue) { f in
                    Button {
                        fs.activeFilter = f
                        if fs.selectedFolder != nil { fs.selectedFolder = nil }
                    } label: {
                        Text(f.rawValue).font(.system(size: 11, weight: .medium))
                            .foregroundColor(fs.activeFilter == f ? .white : .gray)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(fs.activeFilter == f ? Color.ncCyan : Color(red: 0.03, green: 0.03, blue: 0.06), in: Capsule())
                            .overlay(Capsule().stroke(fs.activeFilter == f ? Color.ncCyan : Color.white.opacity(0.08), lineWidth: 0.5))
                    }
                }
                Picker("", selection: $fs.typeFilter) {
                    Text("Alle").tag(FileTypeFilter.all)
                    Text("PDFs").tag(FileTypeFilter.pdf)
                    Text("Bilder").tag(FileTypeFilter.image)
                    Text("Text").tag(FileTypeFilter.text)
                }
                .pickerStyle(.menu).tint(.gray).scaleEffect(0.85)
            }
        }
    }
}

struct FilesActionBar: View {
    @ObservedObject var fs: NAFilesService
    let onUpload: () -> Void
    let onCreateFolder: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            btn("arrow.up.doc.fill", "Upload", .ncCyan, onUpload)
            btn("folder.badge.plus", "Ordner", .ncNeonGreen, onCreateFolder)
            if fs.selectedFolder != nil {
                btn("arrow.left", "Zuruck", .gray) { fs.selectedFolder = nil; Task { await fs.fetchFiles() } }
            }
        }
    }
    func btn(_ icon: String, _ label: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 4) { Image(systemName: icon).font(.caption); Text(label).font(.caption.weight(.medium)) }
            .foregroundColor(color).padding(.horizontal, 12).padding(.vertical, 8)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}