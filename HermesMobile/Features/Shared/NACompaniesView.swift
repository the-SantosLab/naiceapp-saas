import SwiftUI

// MARK: - Unternehmen Dashboard
struct NACompaniesView: View {
    @ObservedObject private var companies = NACompanyService.shared
    @ObservedObject private var goals = NAGoalService.shared
    @State private var showAdd = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unternehmen").font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("\(companies.companies.count) aktiv").font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus").font(.title3).foregroundColor(.ncCyan)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                if companies.companies.isEmpty && !companies.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2").font(.title).foregroundColor(.gray.opacity(0.5))
                        Text("Keine Unternehmen").font(.subheadline).foregroundColor(.gray)
                    }
                    .padding(40).frame(maxWidth: .infinity)
                }

                ForEach(companies.companies) { company in
                    companyCard(company)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .refreshable { await companies.fetch(); await goals.fetch() }
        .task { await companies.fetch() }
        .sheet(isPresented: $showAdd) { NACompanyAddSheet() }
    }

    func companyCard(_ co: NACompany) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(co.logoEmoji).font(.title).frame(width: 36, height: 36)
                    .background(co.colorSwift.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(co.name).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                    if let ind = co.industry, !ind.isEmpty {
                        Text(ind).font(.caption).foregroundColor(.gray)
                    }
                }
                Spacer()
            }

            // Revenue progress
            VStack(spacing: 4) {
                HStack {
                    Text("Umsatz MTD").font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(co.revenueMtd))/\(Int(co.revenueGoalMtd))€").font(.caption2).foregroundColor(co.colorSwift)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 4).fill(co.colorSwift).frame(width: geo.size.width * co.revenueProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }

            // Stats
            HStack(spacing: 16) {
                companyStat(icon: "checklist", value: "\(co.tasksOpen)", label: "Tasks")
                companyStat(icon: "person.fill", value: "\(co.contactsCount)", label: "Kontakte")
                Spacer()
                // Goals for this company
                let companyGoals = goals.activeGoals.filter { $0.company == co.name }
                if !companyGoals.isEmpty {
                    companyStat(icon: "target", value: "\(companyGoals.count)", label: "Ziele")
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.02, green: 0.02, blue: 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(co.colorSwift.opacity(0.2), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    func companyStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.caption2.weight(.medium)).foregroundColor(.white)
                Text(label).font(.system(size: 8)).foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Add Company Sheet
struct NACompanyAddSheet: View {
    @ObservedObject private var companies = NACompanyService.shared
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var industry = ""
    @State private var emoji = "🏢"
    @State private var color = "ncCyan"
    @State private var revenueGoal: Double = 10000

    let emojis = ["🏢", "🍷", "📦", "🤖", "🌱", "💰", "🎯", "⚡"]
    let colors: [(String, Color)] = [("ncCyan", .ncCyan), ("ncRose", .ncRose), ("ncAmber", .ncAmber), ("ncNeonGreen", .ncNeonGreen), ("ncBlue", .ncBlue), ("ncPurple", .ncPurple)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Name", text: $name).font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                TextField("Branche (optional)", text: $industry).font(.subheadline).foregroundColor(.white)
                    .padding(14).background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 8) {
                    ForEach(emojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Text(e).font(.title).frame(width: 36, height: 36)
                                .background(emoji == e ? Color.ncCyan.opacity(0.2) : Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach(colors, id: \.0) { c in
                        Button { color = c.0 } label: {
                            Circle().fill(c.1).frame(width: 24, height: 24).overlay(Circle().stroke(color == c.0 ? Color.white : Color.clear, lineWidth: 2))
                        }
                    }
                }

                HStack {
                    Text("Monats-Umsatzziel: \(Int(revenueGoal))€").font(.subheadline).foregroundColor(.gray)
                    Slider(value: $revenueGoal, in: 100...100000, step: 100).tint(.ncCyan)
                }

                Button("Unternehmen speichern") {
                    Task {
                        await companies.add(name: name, industry: industry, emoji: emoji, color: color, revenueGoalMtd: revenueGoal)
                        dismiss()
                    }
                }
                .font(.headline.weight(.semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                .padding(.vertical, 14).background(Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(20).background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Abbrechen") { dismiss() }.foregroundColor(.ncCyan) }
            }
        }
    }
}