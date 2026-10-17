import SwiftUI

struct NAReflectionView: View {
    @State private var reflection: Reflection?
    @State private var loading = true
    @State private var errorMsg: String? = nil

    struct Reflection: Codable {
        let facts_7d: Int
        let high_conf_7d: Int
        let notes_7d: Int
        let daily_avg: Double
        let top_cats: [CatItem]
        let daily: [String: Int]?
        let patterns: [String]
        let summary: String
    }
    struct CatItem: Codable {
        let n: String
        let c: Int
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reflection").font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("Letzte 7 Tage").font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                    if loading { ProgressView().tint(.ncCyan) }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                if let err = errorMsg {
                    Text(err).font(.caption).foregroundColor(.gray).padding(40)
                } else if let r = reflection {
                    // Summary card
                    VStack(spacing: 8) {
                        Text(r.summary).font(.body).foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ncCyan.opacity(0.15), lineWidth: 0.5)))

                    // Stats grid
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 12) {
                        statCard("\(r.facts_7d)", "Fakten", .ncNeonGreen)
                        statCard("\(r.high_conf_7d)", "Hoch", .ncCyan)
                        statCard("\(r.notes_7d)", "Notizen", .ncAmber)
                    }
                    .padding(.horizontal, 16)

                    // Top categories
                    if !r.top_cats.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOP-KATEGORIEN").font(.caption2.weight(.semibold)).foregroundColor(.gray).padding(.leading, 20)
                            ForEach(Array(r.top_cats.enumerated()), id: \.offset) { i, cat in
                                HStack(spacing: 8) {
                                    Text(cat.n).font(.subheadline).foregroundColor(.white)
                                    Spacer()
                                    Text("\(cat.c)").font(.subheadline.weight(.medium)).foregroundColor(.ncCyan)
                                    Text("×").font(.caption2).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20).padding(.vertical, 4)
                            }
                        }
                    }

                    // Daily breakdown
                    if let daily = r.daily, !daily.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TÄGLICH").font(.caption2.weight(.semibold)).foregroundColor(.gray).padding(.leading, 20)
                            let sortedDays = daily.sorted { a, b in
                                let daysOrder = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
                                return (daysOrder.firstIndex(of: a.key) ?? 0) < (daysOrder.firstIndex(of: b.key) ?? 0)
                            }
                            HStack(spacing: 6) {
                                ForEach(sortedDays, id: \.key) { day, count in
                                    VStack(spacing: 2) {
                                        Text("\(count)").font(.caption.weight(.semibold)).foregroundColor(.white)
                                        Text(day.prefix(2)).font(.system(size: 8)).foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(6)
                                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Patterns
                    if !r.patterns.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MUSTER").font(.caption2.weight(.semibold)).foregroundColor(.gray).padding(.leading, 20)
                            ForEach(r.patterns, id: \.self) { p in
                                HStack(spacing: 6) {
                                    Circle().fill(Color.ncAmber).frame(width: 4, height: 4)
                                    Text(p).font(.caption).foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Reflection").navigationBarTitleDisplayMode(.inline)
        .task { await fetch() }
    }

    func statCard(_ val: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(val).font(.title3.weight(.semibold)).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    func fetch() async {
        let url = URL(string: "https://health.santoslab.de/api/naice/reflection")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            reflection = try JSONDecoder().decode(Reflection.self, from: data)
            loading = false
        } catch {
            errorMsg = "Fehler: \(error.localizedDescription)"
            loading = false
        }
    }
}