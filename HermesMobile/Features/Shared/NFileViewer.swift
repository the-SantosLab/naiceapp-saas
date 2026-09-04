import SwiftUI
import WebKit

struct NFileViewer: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.backgroundColor = .black
        wv.isOpaque = false
        wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return wv
    }
    func updateUIView(_ wv: WKWebView, context: Context) {}
}

struct NFileViewerWrapper: View {
    let file: NFile
    @Environment(\.dismiss) private var dismiss
    @State private var url: URL? = nil
    @State private var loading = true
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let err = error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.ncRose)
                        Text(err).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
                    }
                } else if loading {
                    ProgressView()
                } else if let u = url {
                    NFileViewer(url: u)
                }
            }
            .navigationTitle(file.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { dismiss() }.foregroundColor(.ncCyan)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    ShareLink(item: url ?? URL(string: "https://agent.santoslab.de")!) {
                        Image(systemName: "square.and.arrow.up").foregroundColor(.ncCyan)
                    }
                }
            }
            .task {
                if let u = await NAFilesService.shared.downloadForSharing(file) {
                    url = u; loading = false
                } else {
                    error = "Datei konnte nicht geladen werden"; loading = false
                }
            }
        }
    }
}