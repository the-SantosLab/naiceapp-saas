import Foundation
import SwiftUI

// MARK: - Company Model
struct NACompany: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var industry: String?
    var logoEmoji: String
    var color: String
    var revenueMtd: Double
    var revenueGoalMtd: Double
    var tasksOpen: Int
    var contactsCount: Int
    var created: Int

    var revenueProgress: Double {
        guard revenueGoalMtd > 0 else { return 0 }
        return min(1.0, revenueMtd / revenueGoalMtd)
    }

    var revenuePercent: Int { Int(revenueProgress * 100) }

    var colorSwift: Color {
        switch color {
        case "ncCyan": return .ncCyan
        case "ncRose": return .ncRose
        case "ncAmber": return .ncAmber
        case "ncNeonGreen": return .ncNeonGreen
        case "ncBlue": return .ncBlue
        case "ncPurple": return .ncPurple
        default: return .ncCyan
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, industry
        case logoEmoji = "logo_emoji"
        case color
        case revenueMtd = "revenue_mtd"
        case revenueGoalMtd = "revenue_goal_mtd"
        case tasksOpen = "tasks_open"
        case contactsCount = "contacts_count"
        case created
    }
}

struct NACompanyListResponse: Codable {
    let companies: [NACompany]
}

// MARK: - Company Service
@MainActor
class NACompanyService: ObservableObject {
    static let shared = NACompanyService()

    @Published var companies: [NACompany] = []
    @Published var isLoading = false

    private let baseURL = "https://health.santoslab.de/api/naice/companies"

    func fetch() async {
        guard let url = URL(string: baseURL) else { return }
        isLoading = true
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NACompanyListResponse.self, from: data)
            companies = response.companies
        } catch { print("[Companies] Fetch error: \(error)") }
        isLoading = false
    }

    func add(name: String, industry: String = "", emoji: String = "🏢", color: String = "ncCyan", revenueMtd: Double = 0, revenueGoalMtd: Double = 10000) async -> NACompany? {
        guard let url = URL(string: baseURL) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": "add", "name": name, "industry": industry, "logo_emoji": emoji, "color": color, "revenue_mtd": revenueMtd, "revenue_goal_mtd": revenueGoalMtd]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONDecoder().decode(NACompanyAddResponse.self, from: data)
            if let co = result.company { companies.append(co) }
            return result.company
        } catch { print("[Companies] Add error: \(error)"); return nil }
    }

    func update(companyId: String, revenueMtd: Double? = nil, tasksOpen: Int? = nil) async {
        guard let url = URL(string: baseURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": "update", "company_id": companyId]
        if let r = revenueMtd { body["revenue_mtd"] = r }
        if let t = tasksOpen { body["tasks_open"] = t }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONDecoder().decode(NACompanyUpdateResponse.self, from: data)
            if let co = result.company, let idx = companies.firstIndex(where: { $0.id == companyId }) {
                companies[idx] = co
            }
        } catch { print("[Companies] Update error: \(error)") }
    }
}

struct NACompanyAddResponse: Codable { let ok: Bool?; let company: NACompany? }
struct NACompanyUpdateResponse: Codable { let ok: Bool?; let company: NACompany? }