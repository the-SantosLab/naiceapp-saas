import SwiftUI
import WebKit
import UniformTypeIdentifiers
import PDFKit

// MARK: - NFileViewerWrapper (Entry Point)
struct NFileViewerWrapper: View {
    let file: NFile
    @State private var data: Data?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if let err = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.gray)
                    Text(err).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if isLoading {
                ProgressView().tint(.ncCyan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else if let d = data {
                FileContentView(file: file, data: d)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(file.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: file.name) {
                    Image(systemName: "square.and.arrow.up").foregroundColor(.ncCyan)
                }
            }
        }
        .task { await load() }
    }

    func load() async {
        guard let d = await NAFilesService.shared.downloadFile(file) else {
            error = "Datei konnte nicht geladen werden"
            isLoading = false
            return
        }
        data = d
        isLoading = false
    }
}

// MARK: - FileContentView (renders based on type)
struct FileContentView: View {
    let file: NFile
    let data: Data

    var body: some View {
        switch file.type.lowercased() {
        case "md", "txt":
            MarkdownView(text: String(data: data, encoding: .utf8) ?? "Datei konnte nicht gelesen werden")
        case "html", "htm":
            WebView(html: String(data: data, encoding: .utf8) ?? "")
        case "pdf":
            WebView(data: data, mimeType: "application/pdf")
        case "jpg", "jpeg", "png", "gif", "webp":
            ImageView(data: data)
        default:
            WebView(data: data, mimeType: UTType(filenameExtension: file.ext)?.preferredMIMEType ?? "application/octet-stream")
        }
    }
}

// MARK: - MarkdownView (renders .md / .txt)
struct MarkdownView: View {
    let text: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Simple rendering as plain text with word wrapping
                Text(processedText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var processedText: String {
        // Strip markdown headings markers for cleaner display
        var lines = text.components(separatedBy: "\n")
        var result = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                result += "\n" + trimmed.dropFirst(2) + "\n" + String(repeating: "=", count: min(trimmed.dropFirst(2).count, 30)) + "\n"
            } else if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                result += "\n" + trimmed.dropFirst(trimmed.prefix(while: { $0 == "#" }).count).trimmingCharacters(in: .whitespaces) + "\n" + String(repeating: "-", count: min(trimmed.dropFirst(trimmed.prefix(while: { $0 == "#" }).count).count, 20)) + "\n"
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                result += "  • " + trimmed.dropFirst(2) + "\n"
            } else {
                result += line + "\n"
            }
        }
        return result
    }
}

// MARK: - WebView (HTML/PDF/Office)
struct WebView: UIViewRepresentable {
    var html: String? = nil
    var data: Data? = nil
    var mimeType: String? = nil

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.isOpaque = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        // Allow zooming both in AND out
        wv.scrollView.minimumZoomScale = 0.25
        wv.scrollView.maximumZoomScale = 5.0
        if let h = html {
            wv.loadHTMLString(h, baseURL: nil)
        } else if let d = data, let mime = mimeType {
            wv.load(d, mimeType: mime, characterEncodingName: "utf-8", baseURL: URL(fileURLWithPath: "/"))
        }
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - ImageView (Bilder)
struct ImageView: View {
    let data: Data
    var body: some View {
        if let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Bild konnte nicht geladen werden").foregroundColor(.gray)
        }
    }
}