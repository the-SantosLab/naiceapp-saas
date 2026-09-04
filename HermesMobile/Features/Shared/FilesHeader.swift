import SwiftUI

struct FilesHeader: View {
    @ObservedObject var fs: NAFilesService
    let onSort: () -> Void
    @Binding var isSelecting: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fs.selectedFolder ?? "Dateien").font(.title2.weight(.bold)).foregroundColor(.white)
                Text("\(fs.files.count) Dateien").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            if fs.isLoading { ProgressView().scaleEffect(0.7).tint(.ncCyan) }
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isSelecting.toggle(); if !isSelecting { } } } label: {
                Text(isSelecting ? "Fertig" : "Auswahlen")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelecting ? .ncCyan : .gray)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(isSelecting ? Color.ncCyan.opacity(0.1) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            Button { onSort() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down").font(.caption)
                    Text(fs.sortBy.rawValue).font(.caption2)
                }
                .foregroundColor(.ncCyan)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.ncCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}