import SwiftUI

// MARK: - Amelia Slide-Up (Halb-Sheet Chat)
struct AmeliaSlideUp: View {
    @ObservedObject private var context = AmeliaContextProvider.shared
    @State private var message = ""

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.15))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.ncCyan.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundColor(.ncCyan)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amelia")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(context.slideUpContext)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()
                .overlay(Color.white.opacity(0.06))

            // Chat area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Welcome message
                        chatBubble(
                            text: "Ich bin im Kontext »\(context.slideUpContext)« für dich da. Was möchtest du wissen?",
                            isAmelia: true
                        )

                        // Context suggestions
                        ForEach(contextSuggestions, id: \.self) { suggestion in
                            Button {
                                message = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.ncCyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.ncCyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ncCyan.opacity(0.15), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Notes
                        Text("Amelia antwortet im Agent-Tab.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }

            // Input bar
            HStack(spacing: 10) {
                TextField("Frag Amelia...", text: $message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.04, green: 0.04, blue: 0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))

                Button {
                    // Will be handled in a future version
                    message = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(message.isEmpty ? .gray : .ncCyan)
                }
                .disabled(message.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var contextSuggestions: [String] {
        switch context.currentTab {
        case "home":
            return ["Was ist heute wichtig?", "Fasse meine Daten zusammen", "Welche Aufgaben sind kritisch?"]
        case "life":
            return ["Wie ist meine Life Balance?", "Was kann ich verbessern?", "Zeig mir Trends"]
        case "tasks":
            return ["Priorisiere meine Tasks", "Was ist heute fällig?", "Erstelle einen Plan"]
        case "agent":
            return ["Was hast du über mich gelernt?", "Wie war mein Tag?", "Erinnere mich an etwas"]
        case "more":
            return ["Welche Integrationen sind aktiv?", "Server-Status?", "Was ist neu?"]
        default:
            return ["Was weißt du über mich?", "Hilf mir", "Zeig mir meine Daten"]
        }
    }

    @ViewBuilder
    private func chatBubble(text: String, isAmelia: Bool) -> some View {
        HStack {
            if !isAmelia { Spacer(minLength: 40) }
            Text(text)
                .font(.subheadline)
                .foregroundColor(isAmelia ? .white.opacity(0.85) : .white)
                .padding(12)
                .background(
                    isAmelia ?
                        Color(red: 0.04, green: 0.04, blue: 0.08) :
                        Color.ncCyan.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )
            if isAmelia { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Slide-Up Modifier
extension View {
    func ameliaSlideUp(isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            AmeliaSlideUp()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.black)
        }
    }
}