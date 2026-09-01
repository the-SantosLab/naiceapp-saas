import SwiftUI

struct NAFilesHeaderView: View {
    let fs: NAFilesService
    @Binding var showSortPicker: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let folder = fs.selectedFolder, !folder.isEmpty {
                    Text(folder).font(.title2.weight(.bold)).foregroundColor(.white)
                } else {
                    Text("Dateien").font(.title2.weight(.bold)).foregroundColor(.white)
                }
                Text("\(fs.files.count) Dateien").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 12) {
                if fs.isLoading { ProgressView().scaleEffect(0.7).tint(.ncCyan) }
                Button { showSortPicker = true } label: {
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
}

// MARK: - Search Bar
