import SwiftUI

// MARK: - Amelia Menu Button (Brain-Icon auf Karten)
struct AmeliaMenuButtonModifier: ViewModifier {
    let entity: String
    let detail: String
    @Binding var showSlideUp: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                Button {
                    AmeliaContextProvider.shared.setContext(
                        tab: AmeliaContextProvider.shared.currentTab,
                        view: entity,
                        entity: entity,
                        detail: detail
                    )
                    showSlideUp = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.ncCyan.opacity(0.12))
                            .frame(width: 22, height: 22)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 8))
                            .foregroundColor(.ncCyan)
                    }
                }
                .buttonStyle(.plain)
                .padding(6)
            }
    }
}

extension View {
    func ameliaButton(entity: String = "", detail: String = "", showSlideUp: Binding<Bool>) -> some View {
        modifier(AmeliaMenuButtonModifier(entity: entity, detail: detail, showSlideUp: showSlideUp))
    }
}