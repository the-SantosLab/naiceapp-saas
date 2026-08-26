import SwiftUI

// MARK: - Unified Inbox View
struct NAUnifiedInboxView: View {
    @ObservedObject private var inbox = NAUnifiedInboxService.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Posteingang")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text(inbox.getBriefingSummary())
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button { Task { await inbox.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.ncCyan)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Quick Stats
                HStack(spacing: 10) {
                    statCard(count: inbox.unreadCount, label: "Ungelesen", icon: "envelope.fill", color: .ncCyan)
                    statCard(count: inbox.items.filter { $0.urgency == "high" && !$0.isRead }.count, label: "Dringend", icon: "exclamationmark.triangle.fill", color: .ncRose)
                    statCard(count: 4, label: "Quellen", icon: "square.grid.2x2", color: .ncNeonGreen)
                }
                .padding(.horizontal, 16)

                // Messages
                let displayItems = inbox.items

                if displayItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Keine Nachrichten")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                    )
                    .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 6) {
                        ForEach(displayItems.prefix(30)) { item in
                            messageRow(item)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await inbox.refresh() }
    }

    private func statCard(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private func messageRow(_ item: NAUnifiedInboxItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(sourceColor(item.source).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: sourceIcon(item.source))
                    .font(.system(size: 12))
                    .foregroundColor(sourceColor(item.source))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.contactName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    if item.urgency == "high" && !item.isRead {
                        Circle().fill(Color.ncRose).frame(width: 6, height: 6)
                    }
                    Spacer()
                    Text(item.date, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Text(item.preview)
                    .font(.caption)
                    .foregroundColor(item.isRead ? .gray : .white.opacity(0.8))
                    .lineLimit(2)
            }

            if !item.isRead {
                Circle()
                    .fill(Color.ncCyan)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(item.isRead ? 0.02 : 0.06), lineWidth: 0.5))
        .onTapGesture {
            inbox.markRead(item.id)
        }
    }

    private func sourceColor(_ source: String) -> Color {
        switch source {
        case "whatsapp": return .ncNeonGreen
        case "imessage": return .ncCyan
        case "telegram": return .ncBlue
        default: return .gray
        }
    }

    private func sourceIcon(_ source: String) -> String {
        switch source {
        case "whatsapp": return "message.fill"
        case "imessage": return "bubble.left.fill"
        case "telegram": return "paperplane.fill"
        default: return "bell.fill"
        }
    }
}