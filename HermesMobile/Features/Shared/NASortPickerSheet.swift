import SwiftUI

struct NASortPickerSheet: View {
    @ObservedObject var fs: NAFilesService
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(FileSortBy.allCases, id: \.rawValue) { sort in
                    Button {
                        if fs.sortBy == sort { fs.sortAscending.toggle() }
                        else { fs.sortBy = sort; fs.sortAscending = false }
                        isPresented = false
                    } label: {
                        HStack {
                            Text(sort.rawValue).foregroundColor(.white)
                            Spacer()
                            if fs.sortBy == sort {
                                Image(systemName: fs.sortAscending ? "arrow.up" : "arrow.down").foregroundColor(.ncCyan)
                            }
                        }
                    }
                }
            }
            .background(Color.black).scrollContentBackground(.hidden)
            .navigationTitle("Sortieren").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { isPresented = false }.foregroundColor(.ncCyan)
                }
            }
        }
    }
}

// MARK: - Move Sheet
