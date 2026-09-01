import SwiftUI

struct NAFolderRowView: View {
    let name: String
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.ncCyan.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: "folder.fill").font(.system(size: 12)).foregroundColor(.ncCyan)
                }
                Text(name).font(.subheadline.weight(.medium)).foregroundColor(.white)
                Spacer()
                Text("\(count)").font(.caption).foregroundColor(.gray)
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray.opacity(0.5))
            }
            .padding(10)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}