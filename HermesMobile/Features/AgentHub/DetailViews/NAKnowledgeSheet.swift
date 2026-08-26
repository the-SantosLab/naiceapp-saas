import SwiftUI

// MARK: - Knowledge Sheet (Was weiß Amelia über diesen Kunden?)
struct NAKnowledgeSheet: View {
    let clientName: String
    let clientCompany: String?
    @ObservedObject private var rollup = NARollupService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.ncCyan.opacity(0.1))
                                .frame(width: 56, height: 56)
                            Image(systemName: "brain.head.profile")
                                .font(.title2)
                                .foregroundColor(.ncCyan)
                        }
                        Text("Wissen über")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(clientName)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        if let company = clientCompany, !company.isEmpty {
                            Text(company)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 8)

                    if matchingEntries.isEmpty {
                        // Empty state
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.ncCyan.opacity(0.06))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "questionmark.bubble")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                            Text("Noch kein Wissen über \(clientName) gespeichert.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Text("Amelia kann über den Chat neue Informationen lernen und speichern.")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    } else {
                        // Knowledge entries
                        VStack(spacing: 12) {
                            ForEach(matchingEntries) { entry in
                                knowledgeCard(entry)
                            }
                        }
                    }

                    // Ask Amelia button
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.caption)
                            Text("Amelia nach \(clientName) fragen")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.ncCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.ncCyan.opacity(0.3), lineWidth: 1)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.ncCyan.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.ncCyan)
                }
                ToolbarItem(placement: .principal) {
                    Text("Knowledge")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Knowledge Card
    private func knowledgeCard(_ entry: NAKnowledgeEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tags
            if let tags = entry.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag.trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.ncCyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.ncCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            // Title
            if let title = entry.title, !title.isEmpty {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }

            // Body
            if let body = entry.body, !body.isEmpty {
                Text(body)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(5)
            }

            // Date
            if let created = entry.created {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    Text(formatTimestamp(created))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0.08), .white.opacity(0.02), .clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Matching entries
    private var matchingEntries: [NAKnowledgeEntry] {
        guard let entries = rollup.knowledge?.entries else { return [] }
        let searchTerms = [clientName.lowercased(), (clientCompany ?? "").lowercased()].filter { !$0.isEmpty }
        if searchTerms.isEmpty { return entries }
        return entries.filter { entry in
            let body = (entry.body ?? "").lowercased()
            let title = (entry.title ?? "").lowercased()
            let tags = (entry.tags ?? []).map { $0.lowercased() }
            return searchTerms.contains { term in
                body.contains(term) || title.contains(term) || tags.contains(term)
            }
        }
    }

    private func formatTimestamp(_ ms: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(ms) / 1000)
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}