import SwiftUI
import SwiftData
import SafariServices

// MARK: - Safari View Controller Wrapper

struct NASafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = .systemBlue
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - News Feed Card (für "Meine Bereiche" / Home)

struct NewsFeedCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NewsArticle.fetchedAt, order: .reverse) private var cachedArticles: [NewsArticle]
    @ObservedObject private var service = NewsFeedService.shared
    @State private var showingFeed = false

    /// Anzeige-Kandidaten: erst API-Artikel, dann Cache als Fallback
    private var displayArticles: [NewsArticle] {
        if !service.articles.isEmpty { return service.articles }
        return Array(cachedArticles.prefix(5))
    }

    private var topArticle: NewsArticle? { displayArticles.first }
    private var filteredCount: Int { service.stats?.filtered ?? 1805 }
    private var isPlaceholder: Bool {
        service.articles.isEmpty && cachedArticles.isEmpty && !service.isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: 📰 News  [X gefiltert]  Alle ›
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.ncCyan.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.ncCyan)
                }
                Text("News")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                if service.isLoading {
                    ProgressView().scaleEffect(0.7).tint(.ncCyan)
                } else {
                    if let stats = service.stats {
                        Text("\u{00B7} \(stats.filtered) gefiltert")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    } else {
                        Text("\u{00B7} \(filteredCount) gefiltert")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Button {
                        showingFeed = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Alle")
                                .font(.caption)
                                .foregroundColor(.ncCyan)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundColor(.ncCyan)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let article = topArticle {
                // Top-Artikel — kompakt: 1 Zeile Titel + 1 Zeile Grund + Tags + Source
                Button {
                    showingFeed = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(article.reason)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                // Tags + Source
                HStack(spacing: 6) {
                    ForEach(article.relevanceTags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .foregroundColor(.ncNewsTag)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.ncNewsTag.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Spacer()
                    Text(article.source)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else if isPlaceholder {
                // Empty State (Spec: "Keine relevanten News heute.")
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.ncNeonGreen)
                        Text("0 relevant")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Text("Keine relevanten News heute.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("\(filteredCount) Stories gefiltert.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Button {
                        Task { await service.fetch() }
                    } label: {
                        Text("Pull to check again")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.ncCyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.ncCyan.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
        .onAppear {
            if service.articles.isEmpty && cachedArticles.isEmpty && !service.isLoading {
                Task { await service.fetch() }
            }
        }
        .fullScreenCover(isPresented: $showingFeed) {
            NewsFeedScreen()
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - News Feed Screen (Push / Sheet)

struct NewsFeedScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NewsArticle.publishedAt, order: .reverse) private var cachedArticles: [NewsArticle]
    @ObservedObject private var service = NewsFeedService.shared
    @State private var selectedArticle: NewsArticle?
    @State private var showSafari = false

    private var displayArticles: [NewsArticle] {
        if !service.articles.isEmpty { return service.articles }
        return cachedArticles
    }

    /// Nach Kalendertag gruppierte Artikel (absteigend)
    private var grouped: [(day: String, articles: [NewsArticle])] {
        let sorted = displayArticles.sorted { $0.publishedAt > $1.publishedAt }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, d. MMMM"

        var result: [(day: String, articles: [NewsArticle])] = []
        var currentDay: String? = nil
        var currentArticles: [NewsArticle] = []

        for article in sorted {
            let day = formatter.string(from: article.publishedAt)
            if day != currentDay {
                if let currentDay, !currentArticles.isEmpty {
                    result.append((day: currentDay, articles: currentArticles))
                }
                currentDay = day
                currentArticles = [article]
            } else {
                currentArticles.append(article)
            }
        }
        if let currentDay, !currentArticles.isEmpty {
            result.append((day: currentDay, articles: currentArticles))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Stats-Bar: "Heute: 1.805 gefiltert · 3 für dich"
                    if let stats = service.stats {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.ncCyan)
                            Text("Heute: \(stats.filtered) gefiltert · \(stats.shown) für dich")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.ncCyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ncCyan.opacity(0.12)))
                        .padding(.horizontal, 16)
                    }

                    if displayArticles.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                // Day-Section-Divider: "── 31. August ────────"
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 1)
                                    Text(" \(group.day) ")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.gray)
                                        .fixedSize()
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 1)
                                }

                                ForEach(group.articles) { article in
                                    articleRow(article)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundColor(.ncCyan)
                }
            }
            .refreshable {
                await service.fetch()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSafari) {
            if let url = selectedArticle.flatMap({ URL(string: $0.url) }) {
                NASafariView(url: url)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.ncCyan.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: "newspaper").font(.title2).foregroundColor(.ncCyan)
            }
            Text(service.isLoading ? "Lade News..." : "Keine News verfügbar")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Text("Ziehe nach unten zum Aktualisieren")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private func articleRow(_ article: NewsArticle) -> some View {
        Button {
            selectedArticle = article
            showSafari = true
            markRead(article)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Read/Unread Dot
                Circle()
                    .fill(article.isRead ? Color.gray.opacity(0.3) : Color.ncCyan)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 5) {
                    // Source + Zeit
                    HStack(spacing: 6) {
                        Text(article.source)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.ncNeonGreen)
                        Text(timeString(article.publishedAt))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        if article.isSaved {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.ncAmber)
                        }
                    }

                    // Title
                    Text(article.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(article.isRead ? .gray : .white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    // Preview
                    if !article.preview.isEmpty {
                        Text(article.preview)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // KI-Reason
                    if !article.reason.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundColor(.ncAmber)
                            Text(article.reason)
                                .font(.caption2)
                                .foregroundColor(.ncAmber)
                                .lineLimit(1)
                        }
                    }

                    // Relevance-Tags (Spec: #3D5A47 dunkelgrün)
                    if !article.relevanceTags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(article.relevanceTags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .foregroundColor(.ncNewsTag)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.ncNewsTag.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            .padding(12)
            .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func markRead(_ article: NewsArticle) {
        article.isRead = true
        if let mem = service.articles.first(where: { $0.id == article.id }) {
            mem.isRead = true
        }
        try? modelContext.save()
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}