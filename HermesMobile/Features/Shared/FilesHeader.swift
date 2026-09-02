import SwiftUI

struct FilesHeader: View {
    @ObservedObject var fs: NAFilesService
    let onSort: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fs.selectedFolder ?? "Dateien").font(.title2.weight(.bold)).foregroundColor(.white)
                Text("\(fs.files.count) Dateien").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            if fs.isLoading { ProgressView().scaleEffect(0.7).tint(.ncCyan) }
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