import SwiftUI

// MARK: - nAIce Colors (Sci-Fi / Revolut-Inspired Palette)
extension Color {
    // Core palette
    static let ncBg = Color(red: 0.051, green: 0.051, blue: 0.082)       // #0D0D15
    static let ncSurface = Color(red: 0.102, green: 0.102, blue: 0.157)   // #1A1A28
    static let ncSurface2 = Color(red: 0.149, green: 0.149, blue: 0.212)  // #262636
    
    // Accents
    static let ncCyan = Color(red: 0.0, green: 0.898, blue: 1.0)         // #00E5FF
    static let ncPurple = Color(red: 0.486, green: 0.227, blue: 0.929)   // #7C3AED
    static let ncNeonGreen = Color(red: 0.0, green: 0.902, blue: 0.463)  // #00E676
    static let ncBlue = Color(red: 0.231, green: 0.510, blue: 0.965)     // #3B82F6
    static let ncAmber = Color(red: 0.961, green: 0.620, blue: 0.043)    // #F59E0B
    static let ncRose = Color(red: 0.937, green: 0.267, blue: 0.267)     // #EF4444
    
    // Neutrals
    static let ncWhite = Color(red: 0.965, green: 0.965, blue: 0.980)    // #F6F6FA
    static let ncGray = Color(red: 0.420, green: 0.439, blue: 0.502)     // #6B7280
    static let ncGray2 = Color(red: 0.294, green: 0.314, blue: 0.376)    // #4B5060
    
    // Keep old names aliased to new values for backward compatibility
    static let ncCream = Color(red: 0.051, green: 0.051, blue: 0.082)    // was warm cream, now dark bg
    static let ncPaper = Color(red: 0.102, green: 0.102, blue: 0.157)    // was warm paper, now glass surface
    static let ncSand = Color(red: 0.420, green: 0.439, blue: 0.502)     // was sand, now gray
    static let ncSage = Color(red: 0.0, green: 0.898, blue: 1.0)        // was sage green, now cyan
    static let ncGreen = Color(red: 0.0, green: 0.902, blue: 0.463)     // was dark green, now neon green
    static let ncGreenLight = Color(red: 0.231, green: 0.510, blue: 0.965) // was light green, now blue
    static let ncDark = Color(red: 0.965, green: 0.965, blue: 0.980)    // was dark brown, now white
    static let ncMuted = Color(red: 0.420, green: 0.439, blue: 0.502)   // stays muted gray
    static let ncRed = Color(red: 0.937, green: 0.267, blue: 0.267)     // was muted red, now rose
    static let ncGold = Color(red: 0.961, green: 0.620, blue: 0.043)    // was gold, now amber
}

// MARK: - Glass Card Style (Sci-Fi)
struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Color.ncSurface
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(lineWidth: 0.5)
                        .foregroundColor(.white.opacity(0.06))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white.opacity(0.12),
                                .white.opacity(0.03),
                                .clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .ncCyan.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Glow Effect
extension View {
    func glow(color: Color = .ncCyan, radius: CGFloat = 12) -> some View {
        self.overlay(self, alignment: .center)
            .shadow(color: color.opacity(0.4), radius: radius)
    }
}

// MARK: - View Extensions
extension View {
    func warmCard() -> some View { modifier(GlassCardStyle()) }
    func warmBackground() -> some View {
        self.background(
            ZStack {
                Color.ncBg
                // Subtle ambient glow
                Circle()
                    .fill(Color.ncCyan.opacity(0.03))
                    .blur(radius: 80)
                    .offset(x: -100, y: -200)
                Circle()
                    .fill(Color.ncPurple.opacity(0.03))
                    .blur(radius: 80)
                    .offset(x: 100, y: 200)
            }
            .ignoresSafeArea()
        )
    }
}

// MARK: - Section Label (Sci-Fi)
struct NAIceSectionLabel: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.ncCyan)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.ncGray)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .padding(.horizontal, 4)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - Shared Helpers
func timeGreeting() -> String {
    let h = Calendar.current.component(.hour, from: Date())
    if h < 6 { return "Nachtruhe?" }
    if h < 9 { return "Guten Morgen!" }
    if h < 12 { return "Guten Vormittag!" }
    if h < 14 { return "Mittagspause?" }
    if h < 17 { return "Nachmittag!" }
    if h < 21 { return "Feierabend!" }
    return "Gute Nacht!"
}

func recoveryColor(_ s: Int) -> Color {
    s >= 67 ? .ncNeonGreen : s >= 34 ? .ncAmber : .ncRose
}

func wm(_ i: String, _ v: String, _ l: String) -> some View {
    VStack(spacing: 4) {
        Image(systemName: i).font(.caption).foregroundColor(.ncCyan)
        Text(v).font(.caption.weight(.bold)).foregroundColor(.ncWhite)
        Text(l).font(.system(size: 8)).foregroundColor(.ncGray)
    }.frame(maxWidth: .infinity)
}

func mini(_ i: String, _ v: String, _ l: String) -> some View {
    VStack(spacing: 4) {
        Image(systemName: i).font(.caption).foregroundColor(.ncCyan)
        Text(v).font(.caption.weight(.bold)).foregroundColor(.ncWhite)
        Text(l).font(.caption2).foregroundColor(.ncGray)
    }.frame(maxWidth: .infinity)
}

func legend(_ l: String, _ c: Color) -> some View {
    HStack(spacing: 3) {
        Circle().fill(c).frame(width: 6, height: 6)
        Text(l).font(.system(size: 9)).foregroundColor(.ncGray)
    }
}

func area(_ icon: String, _ title: String, _ color: Color, _ dest: AnyView) -> some View {
    NavigationLink(destination: dest) {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(title).font(.caption.weight(.semibold)).foregroundColor(.ncWhite)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .warmCard()
    }.buttonStyle(PlainButtonStyle())
}

// MARK: - nAIce Constants (centralized URLs)
struct NAConstants {
    static let baseURL = URL(string: "https://health.santoslab.de")!
    static let rollupURL = baseURL.appending(path: "/api/rollup")
    static let whatsappBase = baseURL.appending(path: "/api/whatsapp")
    static let whoopSummary = URL(string: "https://health.santoslab.de/whoop/summary")!
    static let ideasEndpoint = URL(string: "https://health.santoslab.de/api/naice/ideas")!
    static let syncEndpoint = URL(string: "https://health.santoslab.de/api/naice/sync")!
    static let versionEndpoint = URL(string: "https://health.santoslab.de/api/naice/version")!
    static let widgetData = URL(string: "https://health.santoslab.de/api/naice/widget-data")!
    static let macBase = URL(string: "https://health.santoslab.de/api/mac")!
    static let pushRegister = URL(string: "https://health.santoslab.de/api/naice/push/register")!
    static let appStoreURL = URL(string: "https://agent.santoslab.de/naice-app/")!
    static let websiteURL = URL(string: "https://santoslab.de")!
    static let naiceAppURL = URL(string: "https://naice.app")!
    static let appVersion = "20260825.0630"
}