import SwiftData
import Foundation

// MARK: - SwiftData Model

@Model
final class NewsArticle {
    var id: String
    var title: String
    var preview: String
    var source: String
    var url: String
    var publishedAt: Date
    var relevanceTags: [String]
    var reason: String
    var isRead: Bool
    var isSaved: Bool
    var fetchedAt: Date

    init(
        id: String,
        title: String,
        preview: String,
        source: String,
        url: String,
        publishedAt: Date,
        relevanceTags: [String] = [],
        reason: String = "",
        isRead: Bool = false,
        isSaved: Bool = false,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.source = source
        self.url = url
        self.publishedAt = publishedAt
        self.relevanceTags = relevanceTags
        self.reason = reason
        self.isRead = isRead
        self.isSaved = isSaved
        self.fetchedAt = fetchedAt
    }
}

// MARK: - API Response DTOs

struct NewsFeedResponse: Decodable {
    let articles: [NewsArticleDTO]
    let stats: NewsStatsDTO
}

struct NewsArticleDTO: Decodable {
    let id: String
    let title: String
    let preview: String
    let source: String
    let url: String
    let published_at: String
    let relevance_tags: [String]?
    let reason: String?
    let is_read: Bool?
    let is_saved: Bool?
}

struct NewsStatsDTO: Decodable {
    let filtered_today: Int
    let shown: Int
    let updated_at: String
}

// MARK: - DTO → Model

extension NewsArticleDTO {
    func toModel() -> NewsArticle {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: published_at) ?? Date()

        return NewsArticle(
            id: id,
            title: title,
            preview: preview,
            source: source,
            url: url,
            publishedAt: date,
            relevanceTags: relevance_tags ?? [],
            reason: reason ?? "",
            isRead: is_read ?? false,
            isSaved: is_saved ?? false
        )
    }
}