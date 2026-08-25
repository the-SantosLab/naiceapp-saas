import SwiftUI

// MARK: - Files Tab
struct NAIceFilesView: View {
    @ObservedObject private var fs = NAFilesService.shared
    @State private var searchText = ""
    @State private var selectedFile: NFile?
    @State private var showFileViewer = false
    @State private var showUpload = false

    private var filteredFiles: [NFile] {
        guard !searchText.isEmpty else { return fs.files }
        return fs.files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            content
                .warmBackground()
                .navigationTitle("Dateien")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable { await fs.fetchFiles() }
                .task { await fs.fetchFiles() }
                .navigationDestination(isPresented: $showFileViewer) {
                    if let f = selectedFile { NFileViewer(file: f) }
                }
                .sheet(isPresented: $showUpload) { NFileUploadSheet() }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Dateien").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                    Spacer()
                    Text("\(fs.files.count)").font(.subheadline).foregroundColor(.ncMuted)
                }

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").font(.caption).foregroundColor(.ncSand)
                    TextField("Suchen...", text: $searchText).font(.subheadline)
                }
                .padding(10)
                .background(Color.ncPaper, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ncSand.opacity(0.3)))

                // Upload
                Button { showUpload = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.title3)
                        Text("Datei hochladen"); Spacer()
                    }
                    .font(.subheadline.weight(.semibold)).foregroundColor(.ncGreen)
                    .padding(12).background(Color.ncGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }

                if fs.isLoading && fs.files.isEmpty {
                    VStack(spacing: 12) { ProgressView(); Text("Lade Dateien...").font(.subheadline).foregroundColor(.ncMuted) }.warmCard()
                } else if filteredFiles.isEmpty {
                    HStack { Image(systemName: "doc").font(.title2).foregroundColor(.ncSand); Text("Keine Dateien").font(.subheadline).foregroundColor(.ncMuted) }.warmCard()
                } else {
                    let grouped = Dictionary(grouping: filteredFiles) { $0.type }
                    let order = ["pdf", "docx", "html", "md", "txt", "image", "other"]
                    ForEach(order, id: \.self) { key in
                        if let items = grouped[key], !items.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(catLabel(key)).font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                                ForEach(items) { file in
                                    Button { selectedFile = file; showFileViewer = true } label: {
                                        fileRow(file)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
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
}