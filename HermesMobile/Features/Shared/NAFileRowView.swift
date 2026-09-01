import SwiftUI

struct NAFileRowView: View {
    let file: NFile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(file.color.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: file.icon).font(.system(size: 12)).foregroundColor(file.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name).font(.subheadline.weight(.medium)).foregroundColor(.white).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(file.sizeLabel).font(.caption2).foregroundColor(.gray)
                        Text(file.dateLabel).font(.caption2).foregroundColor(.gray)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray.opacity(0.5))
            }
            .padding(10)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}