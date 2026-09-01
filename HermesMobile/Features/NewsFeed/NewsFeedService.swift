import Foundation
import SwiftUI

// MARK: - NewsFeedService

@MainActor
class NewsFeedService: ObservableObject {
    static let shared = NewsFeedService()

    @Published var articles: [NewsArticle] = []
    @Published var stats: (filtered: Int, shown: Int)?
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL = "https://health.santoslab.de/api/news/feed"
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Fetch from API

    func fetch() async {
        isLoading = true
        error = nil

        do {
            guard let url = URL(string: baseURL) else {
                throw URLError(.badURL)
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NewsFeedResponse.self, from: data)

            // Convert DTOs to models
            let newArticles = response.articles.map { $0.toModel() }
            self.articles = newArticles
            self.stats = (response.stats.filtered_today, response.stats.shown)
            self.isLoading = false
        } catch {
            print("[NewsFeed] API fetch failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
            // Fallback to mock data
            self.articles = Self.mockArticles()
            self.stats = (1805, 3)
            self.isLoading = false
        }
    }

    // MARK: - Mock Data

    static func mockArticles() -> [NewsArticle] {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        return [
            NewsArticle(
                id: "mock-1",
                title: "SWS-Konkurrent raised $50M Series B",
                preview: "Das Logistik-KI Startup OptiRoute bekommt Series B von a16z. Betrifft direkt unseren aktiven Deal mit der SWS Pilotphase (105k Pipeline).",
                source: "TechCrunch",
                url: "https://techcrunch.com/2026/08/31/sws-konkurrent-optiroute-series-b",
                publishedAt: today.addingTimeInterval(-3600),
                relevanceTags: ["sws-deal", "logistics-ai"],
                reason: "Betrifft aktiven Deal SWS Pilot (105k Pipeline)",
                isRead: false,
                isSaved: false
            ),
            NewsArticle(
                id: "mock-2",
                title: "Neue EU-Regulierung für KI-Systeme ab 2027",
                preview: "Die EU-Kommission hat neue Richtlinien für KI-Systeme veröffentlicht, die auch mittelständische Unternehmen betreffen.",
                source: "Handelsblatt",
                url: "https://handelsblatt.com/politik/eu-ki-regulierung-2027",
                publishedAt: today.addingTimeInterval(-7200),
                relevanceTags: ["regulation", "compliance"],
                reason: "Relevant für nAIce Compliance-Strategie",
                isRead: false,
                isSaved: false
            ),
            NewsArticle(
                id: "mock-3",
                title: "Food Delivery Markt: Neue Player aus Asien",
                preview: "Zwei asiatische Food-Delivery-Plattformen kündigen Expansion nach Europa an. Potenzielle Partner oder Konkurrenz für foodloop.",
                source: "Sifted",
                url: "https://sifted.eu/articles/food-delivery-asia-expansion-2026",
                publishedAt: yesterday.addingTimeInterval(3600),
                relevanceTags: ["foodloop", "competition"],
                reason: "foodloop Marktumfeld beobachten",
                isRead: true,
                isSaved: false
            ),
            NewsArticle(
                id: "mock-4",
                title: "OpenAI stellt neues Reasoning-Modell vor",
                preview: "Das neue Modell o4 übertrifft Vorgänger in Mathematik und Coding-Benchmarks. Mögliche Implikationen für nAIce Agent-Architektur.",
                source: "The Verge",
                url: "https://theverge.com/2026/08/30/openai-o4-reasoning-model",
                publishedAt: yesterday.addingTimeInterval(-7200),
                relevanceTags: ["ai-models", "technology"],
                reason: "Relevant für nAIce Produktentwicklung",
                isRead: false,
                isSaved: true
            ),
            NewsArticle(
                id: "mock-5",
                title: "Startup-Finanzierung in Deutschland: Q2 Analyse",
                preview: "Die Gründerszene analysiert die Finanzierungsrunde Q2 2026. SaaS und KI dominieren, während Climate Tech anzieht.",
                source: "Gruenderszene",
                url: "https://gruenderszene.de/finance/startup-funding-q2-2026",
                publishedAt: yesterday.addingTimeInterval(-14400),
                relevanceTags: ["funding", "market"],
                reason: "Relevant für Investor-Updates",
                isRead: true,
                isSaved: false
            ),
            NewsArticle(
                id: "mock-6",
                title: "WhatsApp Business API: Neue KI-Features",
                preview: "Meta rollout KI-gestützte Antwortvorschläge und automatische Kategorisierung für WhatsApp Business.",
                source: "Meta Blog",
                url: "https://blog.whatsapp.com/whatsapp-business-ai-features-2026",
                publishedAt: Calendar.current.date(byAdding: .day, value: -2, to: today)!,
                relevanceTags: ["whatsapp", "integration"],
                reason: "WhatsApp Bridge Feature-Update",
                isRead: false,
                isSaved: false
            )
        ]
    }
}