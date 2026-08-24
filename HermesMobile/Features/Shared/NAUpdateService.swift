import Foundation

// MARK: - In-App Update Check
struct NAUpdateInfo: Codable {
    let latestVersion: String
    let updateURL: String
    let isRequired: Bool
    let changelog: String?
}

@MainActor
class NAUpdateService: ObservableObject {
    static let shared = NAUpdateService()

    @Published var updateAvailable: NAUpdateInfo?
    @Published var isLoading = false
    @Published var lastChecked: Date?

    private let currentVersion = "20260824.2230"
    private let updateURL = "https://agent.santoslab.de/naice-app/"

    func checkForUpdates() async {
        isLoading = true
        lastChecked = Date()

        // The server has a version endpoint
        guard let url = URL(string: "https://health.santoslab.de/api/naice/version") else {
            isLoading = false
            return
        }

        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                isLoading = false
                return
            }
            let serverInfo = try JSONDecoder().decode(NAUpdateInfo.self, from: data)

            if serverInfo.latestVersion > currentVersion {
                updateAvailable = serverInfo
            }
            isLoading = false
        } catch {
            // Fallback: check if the latest version on the OTA page differs
            await checkOTAFallback()
            isLoading = false
        }
    }

    private func checkOTAFallback() async {
        guard let url = URL(string: updateURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return }

            // Parse version from HTML
            if let range = html.range(of: "Version ") {
                let afterVersion = html[range.upperBound...]
                if let endRange = afterVersion.range(of: " ") {
                    let serverVer = String(afterVersion[..<endRange.lowerBound])
                    if serverVer > currentVersion {
                        updateAvailable = NAUpdateInfo(
                            latestVersion: serverVer,
                            updateURL: updateURL,
                            isRequired: false,
                            changelog: nil
                        )
                    }
                }
            }
        } catch {}
    }
}