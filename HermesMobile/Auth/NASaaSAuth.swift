import Foundation

/// Stores JWT token + server URL for nAIce SaaS multi-user login
final class NASaaSAuth: ObservableObject {
    static let shared = NASaaSAuth()

    @Published var token: String? { didSet { saveToken() } }
    @Published var serverURL: String = "https://saas.naice.app" { didSet { saveServer() } }
    @Published var user: UserInfo? = nil
    @Published var isLoggedIn: Bool = false

    struct UserInfo: Codable {
        let user_id: String
        let email: String
        let name: String
        let role: String
    }

    private init() {
        loadToken()
        loadServer()
        isLoggedIn = token != nil
        if isLoggedIn {
            NAJWTInterceptor.install()
        }
    }

    // MARK: - Login / Register

    func login(email: String, password: String) async throws {
        let url = URL(string: "\(serverURL)/api/naice/auth/login")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(LoginResponse.self, from: data)
        token = resp.token
        user = UserInfo(user_id: resp.user.user_id, email: resp.user.email, name: resp.user.name, role: resp.user.role)
        isLoggedIn = true
        NAJWTInterceptor.install()
    }

    func register(email: String, password: String, name: String) async throws {
        let url = URL(string: "\(serverURL)/api/naice/auth/register")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password, "name": name])

        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(RegisterResponse.self, from: data)
        token = resp.token
        user = UserInfo(user_id: resp.user.user_id, email: resp.user.email, name: resp.user.name, role: resp.user.role)
        isLoggedIn = true
        NAJWTInterceptor.install()
    }

    func logout() {
        token = nil
        user = nil
        isLoggedIn = false
        NAJWTInterceptor.uninstall()
        _ = try? KeychainStore().delete(.init(rawValue: "naice_saas_token") ?? .serverURL)
    }

    // MARK: - Authorized Request

    func authorizedRequest(_ path: String) -> URLRequest? {
        guard let t = token, let url = URL(string: "\(serverURL)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        return req
    }

    func authorizedGET(_ path: String) async throws -> Data {
        guard let req = authorizedRequest(path) else { throw NSError(domain: "NASaaSAuth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]) }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    func authorizedPOST(_ path: String, body: Encodable) async throws -> Data {
        guard var req = authorizedRequest(path) else { throw NSError(domain: "NASaaSAuth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]) }
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    // MARK: - Persistence

    private func saveToken() {
        guard let t = token else { _ = try? KeychainStore().delete(.init(rawValue: "naice_saas_token") ?? .serverURL); return }
        _ = try? KeychainStore().save(t, forKey: .init(rawValue: "naice_saas_token") ?? .serverURL)
    }

    private func loadToken() {
        if let t = try? KeychainStore().load(.init(rawValue: "naice_saas_token") ?? .serverURL) {
            token = t
            Task { try? await fetchUserInfo() }
        }
    }

    private func saveServer() {
        UserDefaults.standard.set(serverURL, forKey: "naice_saas_server")
    }

    private func loadServer() {
        serverURL = UserDefaults.standard.string(forKey: "naice_saas_server") ?? "https://saas.naice.app"
    }

    private func fetchUserInfo() async throws {
        let data = try await authorizedGET("/api/naice/auth/me")
        let info = try JSONDecoder().decode(UserInfo.self, from: data)
        user = info
        isLoggedIn = true
    }

    // MARK: - Codable

    struct LoginResponse: Codable {
        let token: String
        let user: UserInfoResponse
    }
    struct RegisterResponse: Codable {
        let token: String
        let user: UserInfoResponse
    }
    struct UserInfoResponse: Codable {
        let user_id: String
        let email: String
        let name: String
        let role: String
    }
}