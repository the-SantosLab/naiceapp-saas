import SwiftUI
import PDFKit
import WebKit
import UniformTypeIdentifiers

// MARK: - File Viewer
struct NFileViewer: View {
    let file: NFile
    @State private var data: Data?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(0.8).tint(.ncCyan)
                    Text("Lade \(file.name)...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            } else if let err = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.ncRose)
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            } else if let d = data {
                switch file.type {
                case "pdf":
                    PDFViewer(data: d)
                case "html":
                    HTMLViewer(data: d, baseURL: URL(fileURLWithPath: file.path))
                case "md", "txt", "docx":
                    TextFileViewer(data: d, type: file.type)
                case "image":
                    ImageViewer(data: d)
                default:
                    TextFileViewer(data: d, type: "txt")
                }
            }
        }
        .task { await loadFile() }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadFile() async {
        isLoading = true
        let d = await NAFilesService.shared.downloadFile(file)
        if let d = d {
            data = d
        } else {
            error = "Konnte Datei nicht laden"
        }
        isLoading = false
    }
}

// MARK: - PDF Viewer
struct PDFViewer: View {
    let data: Data
    var body: some View {
        PDFKitView(data: data)
            .ignoresSafeArea()
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.document = PDFDocument(data: data)
        v.autoScales = true
        v.backgroundColor = UIColor.black
        return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - HTML Viewer
struct HTMLViewer: View {
    let data: Data
    let baseURL: URL
    var body: some View {
        WebView(data: data, baseURL: baseURL)
            .ignoresSafeArea()
    }
}

struct WebView: UIViewRepresentable {
    let data: Data
    let baseURL: URL
    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.load(data, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: baseURL)
        wv.backgroundColor = UIColor.black
        wv.isOpaque = false
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Text File Viewer
struct TextFileViewer: View {
    let data: Data
    let type: String
    @State private var text = ""

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: type == "md" ? .default : .monospaced))
                .foregroundColor(.white)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            if type == "docx" {
                text = "DOCX-Vorschau: \(data.count) Bytes\n\n(Direkte DOCX-Parsing nicht implementiert – speichere und offne in Word)"
            } else {
                text = String(data: data, encoding: .utf8) ?? "Kann Datei nicht dekodieren"
            }
        }
    }
}

// MARK: - Image Viewer
struct ImageViewer: View {
    let data: Data
    var body: some View {
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .padding()
                .background(Color.black.ignoresSafeArea())
        } else {
            Text("Bild kann nicht angezeigt werden")
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
        }
    }
}

// MARK: - File Upload Sheet
struct NFileUploadSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var showFilePicker = false
    @State private var selectedURL: URL?
    @State private var isUploading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.ncCyan)
                Text("Datei hochladen")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("Wahle eine PDF, DOCX, HTML, MD oder TXT Datei")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus").font(.title3)
                        Text("Datei auswahlen")
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)

                if let url = selectedURL {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.ncNeonGreen)
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }

                if isUploading {
                    ProgressView("Lade hoch...")
                        .tint(.ncCyan)
                }

                Spacer()
            }
            .padding(.top, 40)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schliessen") { dismiss() }
                        .foregroundColor(.ncCyan)
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf, .text, .plainText, .html, .json, .data, .image]) { result in
                switch result {
                case .success(let url):
                    selectedURL = url
                    startUpload(url)
                case .failure:
                    break
                }
            }
        }
    }

    private func startUpload(_ url: URL) {
        isUploading = true
        Task {
            guard let data = try? Data(contentsOf: url) else { return }
            let ok = await NAFilesService.shared.uploadFile(name: url.lastPathComponent, data: data)
            if ok { dismiss() }
            isUploading = false
        }
    }
}