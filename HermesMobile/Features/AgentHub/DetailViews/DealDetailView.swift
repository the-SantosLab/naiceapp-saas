import SwiftUI

// MARK: - Deal Detail View
struct DealDetailView: View {
    let deal: NADeal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(deal.name).font(.title2.weight(.bold)).foregroundColor(.ncDark)
                    Text("\(deal.value) €").font(.title.weight(.bold)).foregroundColor(.ncGreen)
                    if let s = deal.status {
                        HStack(spacing: 6) {
                            Circle().fill(statusColor(s)).frame(width: 8, height: 8)
                            Text(s.capitalized).font(.subheadline.weight(.medium)).foregroundColor(statusColor(s))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(statusColor(s).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }.warmCard()

                // AI-Tipp
                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    Text("Mehr Details zu diesem Deal werden automatisch aus Amelia's Pipeline geladen.")
                        .font(.subheadline).foregroundColor(.ncMuted)
                }.warmCard()
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Deal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "aktiv": return .ncGreen
        case "angebot": return .ncGold
        case "beauftragt": return .blue
        default: return .ncMuted
        }
    }
}