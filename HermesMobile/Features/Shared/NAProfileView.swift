import SwiftUI

// MARK: - Johannes-Modell View
struct NAProfileView: View {
    @State private var learnings: [NALearning] = []
    @State private var insights: NAInsightsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let learnURL = "https://health.santoslab.de/api/naice/learn"
    private let insightsURL = "https://health.santoslab.de/api/naice/insights"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Johannes-Modell")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text("\(learnings.count) Fakten · \(insights?.categories?.count ?? 0) Kategorien")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if isLoading {
                        ProgressView().scaleEffect(0.7).tint(.ncCyan)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Stats Card
                statsCard

                // Insights by Category
                if let insights = insights?.topInsights, !insights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Erkenntnisse")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        ForEach(insights) { insight in
                            insightCard(insight)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 16)
                }

                // All Learnings
                if !learnings.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile").font(.caption).foregroundColor(.ncCyan)
                            Text("Alle Fakten").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            Spacer()
                            Text("\(learnings.count)").font(.caption.weight(.bold)).foregroundColor(.ncCyan)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.ncCyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(.horizontal, 4)

                        ForEach(learnings) { learning in
                            learningRow(learning)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 16)
                }

                if learnings.isEmpty && !isLoading {
                    emptySection
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var statsCard: some View {
        let categories = insights?.categories ?? [:]
        let highConf = insights?.topInsights?.reduce(0) { $0 + $1.highConfidence } ?? 0

        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.06), lineWidth: 5).frame(width: 56, height: 56)
                Circle().trim(from: 0, to: learnings.isEmpty ? 0 : min(CGFloat(highConf) / CGFloat(learnings.count), 1))
                    .stroke(Color.ncCyan, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56).rotationEffect(.degrees(-90))
                Image(systemName: "brain").font(.system(size: 18)).foregroundColor(.ncCyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(learnings.count) Fakten gesammelt").font(.headline.weight(.bold)).foregroundColor(.white)
                Text("\(highConf) mit hoher Konfidenz · \(categories.count) Kategorien").font(.caption).foregroundColor(.gray)
                Text("Der Agent lernt mit jeder Interaktion dazu.").font(.caption2).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.02, green: 0.02, blue: 0.04))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ncCyan.opacity(0.15), lineWidth: 0.5)))
        .padding(.horizontal, 16)
    }

    private func insightCard(_ insight: NAInsightItem) -> some View {
        let categoryColors: [String: Color] = [
            "arbeit": .ncCyan, "gesundheit": .ncNeonGreen, "persoenlichkeit": .ncAmber,
            "kommunikation": .ncPurple, "allgemein": .ncBlue
        ]
        let color = categoryColors[insight.category] ?? .gray

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 28, height: 28)
                    Image(systemName: insightIcon(insight.category)).font(.system(size: 11)).foregroundColor(color)
                }
                Text(categoryLabel(insight.category)).font(.subheadline.weight(.medium)).foregroundColor(.white)
                Spacer()
                Text("\(insight.highConfidence) hoch").font(.caption2.weight(.semibold)).foregroundColor(.ncNeonGreen)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.ncNeonGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            if !insight.examples.isEmpty {
                ForEach(insight.examples, id: \.self) { example in
                    HStack(spacing: 8) {
                        Image(systemName: "quote.opening").font(.system(size: 8)).foregroundColor(.gray)
                        Text(example).font(.caption).foregroundColor(.gray).lineLimit(3)
                    }
                    .padding(10)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                }
            }

            HStack(spacing: 4) {
                Text("\(insight.count) Fakten").font(.caption2).foregroundColor(.gray)
                Spacer()
                Text("\(Int(Double(insight.highConfidence) / Double(max(insight.count, 1)) * 100))% Konfidenz")
                    .font(.caption2).foregroundColor(color)
            }
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private func learningRow(_ learning: NALearning) -> some View {
        let confidence = learning.confidence
        let confidencePct = Int(confidence * 100)
        let color: Color = confidence >= 0.7 ? .ncNeonGreen : confidence >= 0.4 ? .ncAmber : .gray

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 28, height: 28)
                Text("\(confidencePct)").font(.system(size: 9, weight: .bold)).foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(learning.fact).font(.subheadline).foregroundColor(.white).lineLimit(3)
                HStack(spacing: 6) {
                    Text(learning.category).font(.caption2).foregroundColor(.gray)
                    Text("·").font(.caption2).foregroundColor(.gray)
                    Text("\(learning.reinforced)× erneut").font(.caption2).foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(confidencePct)%").font(.caption2.weight(.bold)).foregroundColor(color)
                Text(learning.source).font(.system(size: 7)).foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private var emptySection: some View {
        VStack(spacing: 14) {
            ZStack { Circle().fill(Color.ncCyan.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: "brain.head.profile").font(.title2).foregroundColor(.ncCyan) }
            Text("Noch keine Fakten").font(.subheadline.weight(.semibold)).foregroundColor(.white)
            Text("Der Agent sammelt mit jeder Interaktion Wissen über dich.\nNach ein paar Chats siehst du hier was er gelernt hat.")
                .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private func insightIcon(_ c: String) -> String {
        switch c {
        case "arbeit": return "briefcase.fill"
        case "gesundheit": return "heart.fill"
        case "persoenlichkeit": return "person.fill"
        case "kommunikation": return "bubble.left.fill"
        default: return "sparkle"
        }
    }

    private func categoryLabel(_ c: String) -> String {
        switch c {
        case "arbeit": return "Arbeit"
        case "gesundheit": return "Gesundheit"
        case "persoenlichkeit": return "Persönlichkeit"
        case "kommunikation": return "Kommunikation"
        case "allgemein": return "Allgemein"
        default: return c
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Fetch learnings
            if let learnUrl = URL(string: learnURL) {
                let (ldata, _) = try await URLSession.shared.data(from: learnUrl)
                learnings = (try? JSONDecoder().decode([NALearning].self, from: ldata)) ?? []
            }
            // Fetch insights
            if let insightsUrl = URL(string: insightsURL) {
                let (idata, _) = try await URLSession.shared.data(from: insightsUrl)
                insights = try? JSONDecoder().decode(NAInsightsResponse.self, from: idata)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Models
struct NALearning: Identifiable, Codable {
    let id: String
    let fact: String
    let category: String
    let confidence: Double
    let source: String
    let created: Int?
    let reinforced: Int?
}

struct NAInsightsResponse: Codable {
    let totalFacts: Int?
    let categories: [String: Int]?
    let topInsights: [NAInsightItem]?

    enum CodingKeys: String, CodingKey {
        case totalFacts = "total_facts"
        case categories, topInsights = "top_insights"
    }
}

struct NAInsightItem: Identifiable, Codable {
    let category: String
    let count: Int
    let highConfidence: Int
    let examples: [String]

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category, count
        case highConfidence = "high_confidence"
        case examples
    }
}

#Preview {
    NAProfileView()
}