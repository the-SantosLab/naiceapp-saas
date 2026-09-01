import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
    private var didStartOpening = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !didStartOpening else { return }
        didStartOpening = true

        Task {
            await handleSharedContent()
        }
    }

    private func handleSharedContent() async {
        guard let context = extensionContext,
              let item = context.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            completeRequest()
            return
        }

        var textParts: [String] = []
        var urlParts: [String] = []

        for provider in attachments {
            // First try to get a URL
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = await loadItem(from: provider, type: UTType.url.identifier) as? URL {
                    urlParts.append(url.absoluteString)
                    continue
                }
                if let urlStr = await loadItem(from: provider, type: UTType.url.identifier) as? String {
                    urlParts.append(urlStr)
                    continue
                }
            }

            // Then try text
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = await loadItem(from: provider, type: UTType.plainText.identifier) as? String {
                    textParts.append(text)
                    continue
                }
            }

            // Try text as fallback
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                if let text = await loadItem(from: provider, type: UTType.text.identifier) as? String {
                    textParts.append(text)
                    continue
                }
            }
        }

        // Build the shared text
        var sharedText = ""
        if !urlParts.isEmpty {
            sharedText = urlParts.joined(separator: "\n")
        }
        if !textParts.isEmpty {
            let text = textParts.joined(separator: "\n\n")
            sharedText = sharedText.isEmpty ? text : "\(text)\n\n\(sharedText)"
        }

        // Open nAIce with the shared content via URL
        guard !sharedText.isEmpty else {
            completeRequest()
            return
        }

        guard var components = URLComponents(string: "naice://share") else {
            completeRequest()
            return
        }
        components.queryItems = [URLQueryItem(name: "text", value: sharedText)]

        guard let url = components.url else {
            completeRequest()
            return
        }

        // Open the main app
        context.open(url) { [weak self] success in
            if !success {
                // Fallback: try via UIApplication
                let selector = NSSelectorFromString("sharedApplication")
                if let appClass = NSClassFromString("UIApplication") as? NSObject.Type,
                   appClass.responds(to: selector),
                   let app = appClass.perform(selector)?.takeUnretainedValue() as? NSObject {
                    let openSelector = NSSelectorFromString("openURL:options:completionHandler:")
                    if app.responds(to: openSelector) {
                        typealias OpenFunc = @convention(c) (NSObject, Selector, NSURL, NSDictionary, Any?) -> Void
                        let open = unsafeBitCast(app.method(for: openSelector), to: OpenFunc.self)
                        open(app, openSelector, url as NSURL, [:] as NSDictionary, nil)
                    }
                }
            }
            self?.completeRequest()
        }
    }

    private func loadItem(from provider: NSItemProvider, type: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}