import SwiftUI

struct AgentHubView_Immersive: View {
    @Query(sort: \.date, order: .reverse) var moods: [MoodEntry]
    @ObservedObject private var rollup = NARollupService.shared
    @ObservedObject private var proactive = NAProactiveService.shared
    @ObservedObject private var goals = NAGoalService.shared
    @State private var showLifeScore = false
    @State private var dismissedAlerts: Set<String> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("nAIce")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text(timeGreeting())
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button { Task { await rollup.fetch(); await goals.fetch() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.ncCyan)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                // MARK: - Life Score Card (BIG)
                LifeScoreBigCard(rollup: rollup, onTap: { showLifeScore = true })
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)

                // MARK: - "What You Need To Know" Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Was du wissen musst")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)

                    // Flags (Alerts)
                    if !rollup.flags.isEmpty {
                        ForEach(rollup.flags.filter { !dismissedAlerts.contains($0.id) }) { flag in
                            ActionCard(
                                icon: flag.level == "red" ? "exclamationmark.triangle.fill" : flag.level == "yellow" ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                                title: flag.text,
                                color: flag.level == "red" ? .ncRose : flag.level == "yellow" ? .ncAmber : .ncNeonGreen,
                                onDismiss: { dismissedAlerts.insert(flag.id) }
                            )
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }

                    // Briefing if exists
                    if let briefings = rollup.briefings?.filter({ Calendar.current.isDateInToday($0.ts) }), !briefings.isEmpty {
                        ActionCard(
                            icon: "sparkle",
                            title: "\(briefings.count) Briefing\(briefings.count > 1 ? "s" : "") für dich",
                            subtitle: briefings.first?.title ?? "",
                            color: .ncAmber,
                            action: { showLifeScore = true }
                        )
                        .padding(.horizontal, 16)
                    }

                    // Tasks if overdue
                    if let t = rollup.tasks, t.active > 0 {
                        ActionCard(
                            icon: "checkmark.circle.fill",
                            title: "\(t.active) Task\(t.active > 1 ? "s" : "") offen",
                            color: .ncCyan,
                            action: { showLifeScore = true }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)

                // MARK: - Quick Access
                VStack(alignment: .leading, spacing: 12) {
                    Text("Schnellzugriff")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            quickButton("bubble.right.fill", "Chat", .ncCyan) {
                                // TODO: Navigate to Chat
                            }
                            quickButton("note.text", "Notizen", .ncBlue) {
                                // TODO: Navigate to Notes
                            }
                            quickButton("target", "Ziele", .ncAmber) {
                                // TODO: Navigate to Goals
                            }
                            quickButton("heart.fill", "Gesundheit", .ncRose) {
                                // TODO: Navigate to Health
                            }
                            quickButton("folder.fill", "Dateien", .ncPurple) {
                                // TODO: Navigate to Files
                            }
                            quickButton("square.grid.2x2", "Mehr", .ncGray) {
                                // TODO: Navigate to All Areas
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 24)

                Spacer(height: 40)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLifeScore) {
            NavigationStack { NALifeScoreView() }
        }
        .task {
            await rollup.fetch()
            await goals.fetch()
            proactive.generate()
        }
    }

    private func quickButton(_ icon: String, _ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
            haptic(.medium)
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 60)
            .padding(.vertical, 12)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 0.5))
        }
    }

    private func timeGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Guten Morgen"
        case 12..<17: return "Guten Nachmittag"
        case 17..<21: return "Guten Abend"
        default: return "Gute Nacht"
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Life Score Big Card
struct LifeScoreBigCard: View {
    @ObservedObject var rollup: NARollupService
    let onTap: () -> Void
    @State private var animateScore = false

    var lifeScore: Int {
        guard let w = rollup.whoop, let rec = w.recovery?.score else { return 0 }
        let recovery = Double(rec) / 100
        let tasks = rollup.tasks?.active ?? 0
        let taskScore = min(1.0, 1.0 - (Double(tasks) / 10))
        let health = recovery * 0.7 + taskScore * 0.3
        return Int(health * 100)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("Life Score")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.gray)

                    ZStack {
                        // Background Circle
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 3)

                        // Progress Circle
                        Circle()
                            .trim(from: 0, to: animateScore ? CGFloat(lifeScore) / 100 : 0)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.ncNeonGreen, .ncCyan]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        // Score Text
                        VStack(spacing: 4) {
                            Text("\(lifeScore)")
                                .font(.system(size: 44, weight: .bold, design: .default))
                                .foregroundColor(.white)
                            Text("von 100")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(height: 140)
                }

                Divider().overlay(Color.white.opacity(0.06))

                // Stats Row
                HStack(spacing: 16) {
                    statMini("Recovery", rollup.whoop?.recovery?.score.map { "\($0)%" } ?? "–", .ncRose)
                    Divider().overlay(Color.white.opacity(0.06))
                    statMini("Sleep", rollup.whoop?.sleep.map { String(format: "%.1fh", $0.net_hours) } ?? "–", .ncCyan)
                    Divider().overlay(Color.white.opacity(0.06))
                    statMini("Tasks", (rollup.tasks.map { "\($0.active)" } ?? "0"), .ncAmber)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.04, green: 0.04, blue: 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.ncNeonGreen.opacity(0.2), Color.ncCyan.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    ))
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                animateScore = true
            }
        }
    }

    private func statMini(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.gray)
            Text(value).font(.headline).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Action Card (für Alerts/Briefings/Tasks)
struct ActionCard: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let color: Color
    var action: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        ZStack(alignment: .trailing) {
            // Dismiss Background
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ncRose.opacity(0.2))

            // Main Card
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                    if let subtitle { Text(subtitle).font(.caption).foregroundColor(.gray).lineLimit(1) }
                }

                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray)
            }
            .padding(12)
            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.15), lineWidth: 0.5))
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { action?() } }
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if g.translation.width < 0 {
                            offset = g.translation.width
                        }
                    }
                    .onEnded { g in
                        if g.translation.width < -60 {
                            withAnimation(.spring()) {
                                opacity = 0
                                offset = -100
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDismiss?()
                            }
                        } else {
                            withAnimation(.spring()) {
                                offset = 0
                            }
                        }
                    }
            )

            // Dismiss Hint
            if offset < -20 {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill").font(.caption2).foregroundColor(.white)
                }
                .padding(.trailing, 16)
            }
        }
        .opacity(opacity)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AgentHubView_Immersive()
    }
}