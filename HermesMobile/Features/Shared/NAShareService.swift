import Foundation
import SwiftUI
import UIKit

// MARK: - Chat Share Service
@MainActor
struct NAShareService {
    static func shareSession(sessionID: String) async -> String? {
        let urlStr = "https://health.santoslab.de/api/naice/share"
        guard let url = URL(string: urlStr) else { return nil }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["session_id": sessionID]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30
        
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let shareURL = result["url"] as? String {
                return shareURL
            }
        } catch {
            print("[Share] Error: \(error)")
        }
        return nil
    }
}

// MARK: - Identifiable URL for sheets
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - iOS Share Sheet
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}