import SwiftUI

// MARK: - Finance Detail View (Modern Dark + Revenue)
struct FinanceDetailView: View {
    @ObservedObject private var rollup = NARollupService.shared
    @ObservedObject private var finance = NAFinanceService.shared
    @State private var showAddExpense = false
    @State private var amountDouble = 0.0
    @State private var selectedCategory = "essen"
    @State private var note = ""
    @State private var showCsvPicker = false
    @State private var importResult: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Finanzen")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text("\(Int(finance.monthlyTotal)) € ausgegeben diesen Monat")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if rollup.isLoading {
                        ProgressView().scaleEffect(0.7).tint(.ncCyan)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Server Einnahmen
                if let rev = rollup.revenue, !(rev.entries?.isEmpty ?? true) {
                    revenueSection(rev)
                        .padding(.horizontal, 16)
                }

                // Insights Charts (ported from Dime)
                if !finance.expenses.isEmpty {
                    insightsSection
                        .padding(.horizontal, 16)
                }

                // Budget
                budgetSection
                    .padding(.horizontal, 16)

                // Ausgaben
                expensesSection
                    .padding(.horizontal, 16)

                // AI-Tipp
                aiTipSection
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { finance.syncFromServer() }
        .sheet(isPresented: $showAddExpense) {
            addExpenseSheet
        }
        .fileImporter(isPresented: $showCsvPicker, allowedContentTypes: [.commaSeparatedText, .text, .plainText, .data]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let expenses = NACsvImportService.parseCSV(content)
                    for exp in expenses {
                        finance.addExpenseVal(amount: exp.amount, category: exp.category, note: exp.note, date: exp.date)
                    }
                    importResult = "\(expenses.count) Transaktionen importiert"
                } catch {
                    // Try latin1
                    if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
                        let expenses = NACsvImportService.parseCSV(content)
                        for exp in expenses {
                            finance.addExpenseVal(amount: exp.amount, category: exp.category, note: exp.note, date: exp.date)
                        }
                        importResult = "\(expenses.count) Transaktionen importiert"
                    } else {
                        importResult = "Fehler: Datei konnte nicht gelesen werden"
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    importResult = nil
                }
            case .failure:
                importResult = "Fehler: Datei konnte nicht geoffnet werden"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importResult = nil }
            }
        }
        .overlay(alignment: .top) {
            if let result = importResult {
                Text(result)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.ncNeonGreen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.ncNeonGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ncNeonGreen.opacity(0.2), lineWidth: 0.5))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: importResult != nil)
            }
        }
    }

    // MARK: - Revenue Section
    private func revenueSection(_ rev: NARevenueRollup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "eurosign.circle.fill")
                    .font(.caption)
                    .foregroundColor(.ncNeonGreen)
                Text("Einnahmen (Server)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }

            // Header Stats
            HStack(spacing: 10) {
                statBox("Gesamt", "\(rev.total_eur ?? 0)€", .ncNeonGreen)
                statBox("Dieser Monat", "\(rev.this_month ?? 0)€", .ncCyan)
                statBox("Letzter Monat", "\(rev.last_month ?? 0)€", .ncAmber)
            }

            // Monthly Chart
            if let monthly = rev.monthly, !monthly.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monatliche Einnahmen")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(monthly) { m in
                            let maxVal = monthly.map { $0.total ?? 0 }.max() ?? 1
                            let pct = Double(m.total ?? 0) / Double(max(1, maxVal))
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.ncNeonGreen)
                                    .frame(width: 24, height: max(8, CGFloat(pct) * 60))
                                Text(m.month?.suffix(2) ?? "")
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(height: 72)
                    .padding(10)
                    .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            // Revenue Entries List
            if let entries = rev.entries, !entries.isEmpty {
                Text("Zahlungseingänge")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.gray)

                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        HStack(spacing: 10) {
                            Circle().fill(Color.ncNeonGreen).frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.client ?? entry.label ?? "")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                HStack(spacing: 6) {
                                    if let k = entry.kind, !k.isEmpty {
                                        Text(k.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            Spacer()
                            Text("\(entry.amount ?? 0)€")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.ncNeonGreen)
                        }
                        .padding(10)
                        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Insights Section (Dime-Inspired)
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("Analyse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }

            // Suggested Transactions
            if !suggestedExpenses.isEmpty {
                NASuggestedTransactions(
                    suggestions: suggestedExpenses,
                    currencySymbol: "€",
                    onTap: { item in
                        finance.addExpense(amount: item.amount, category: item.category, note: item.label)
                    }
                )
            }

            // Donut Chart
            if !donutData.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Kategorien")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    NADonutChart(data: donutData, total: donutData.reduce(0) { $0 + $1.amount })
                }
            }

            // Line Graph
            if !lineGraphData.isEmpty {
                NALineGraph(
                    dataPoints: lineGraphData,
                    lineColor: .ncCyan,
                    title: "Ausgaben Trend"
                )
                .frame(height: 200)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Computed Data
    private var donutData: [DonutSlice] {
        let total = finance.monthlyTotal
        guard total > 0 else { return [] }
        let catColors: [String: Color] = [
            "essen": .ncAmber, "transport": .ncCyan, "einkaufen": .ncPurple,
            "wohnen": .ncBlue, "freizeit": .ncNeonGreen, "gesundheit": .ncRose, "sonstiges": .gray
        ]
        return finance.categorySpending.compactMap { cat, spent, _, _ in
            guard spent > 0 else { return nil }
            return DonutSlice(
                label: NAFinanceService.categoryLabel(cat),
                amount: spent,
                color: catColors[cat] ?? .gray,
                total: total
            )
        }
    }

    private var lineGraphData: [GraphPoint] {
        let last7 = finance.expenses.prefix(7).reversed()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return last7.enumerated().map { i, exp in
            GraphPoint(label: formatter.string(from: exp.date), value: exp.amount)
        }
    }

    private var suggestedExpenses: [SuggestedExpense] {
        // Group expenses by category, find most common amounts
        let grouped = Dictionary(grouping: finance.expenses.prefix(20)) { $0.category }
        var suggestions: [SuggestedExpense] = []
        let catColors: [String: Color] = [
            "essen": .ncAmber, "transport": .ncCyan, "einkaufen": .ncPurple,
            "wohnen": .ncBlue, "freizeit": .ncNeonGreen, "gesundheit": .ncRose, "sonstiges": .gray
        ]
        for (cat, exps) in grouped {
            guard let mostCommon = exps.max(by: { $0.amount < $1.amount }) else { continue }
            suggestions.append(SuggestedExpense(
                label: mostCommon.note.isEmpty ? NAFinanceService.categoryLabel(cat) : mostCommon.note,
                amount: mostCommon.amount,
                category: cat,
                color: catColors[cat] ?? .gray
            ))
        }
        return Array(suggestions.prefix(5))
    }

    // MARK: - Budget Section
    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("Budget-Ubersicht")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 10) {
                ForEach(finance.categorySpending, id: \.0) { cat, spent, limit, pct in
                    VStack(spacing: 4) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: NAFinanceService.categoryIcon(cat))
                                    .font(.system(size: 8))
                                    .foregroundColor(.ncCyan)
                                Text(NAFinanceService.categoryLabel(cat))
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Text("\(Int(spent))€/\(Int(limit))€")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        ProgressView(value: min(pct / 100, 1.0))
                            .tint(pct > 90 ? .ncRose : pct > 70 ? .ncAmber : .ncNeonGreen)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Expenses Section
    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("Letzte Ausgaben")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Button { showAddExpense = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.ncCyan)
                }
                Button { showCsvPicker = true } label: {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(.ncCyan.opacity(0.7))
                }
            }

            if finance.expenses.isEmpty {
                VStack(spacing: 8) {
                    Text("Noch keine Ausgaben erfasst.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 6) {
                    ForEach(finance.expenses.prefix(10)) { expense in
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.ncCyan.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: NAFinanceService.categoryIcon(expense.category))
                                    .font(.system(size: 10))
                                    .foregroundColor(.ncCyan)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NAFinanceService.categoryLabel(expense.category))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                if !expense.note.isEmpty {
                                    Text(expense.note)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Text("\(Int(expense.amount))€")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - AI Tip
    private var aiTipSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
                Text("AI-Tipp")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            let highest = finance.categorySpending.max { $0.1 < $1.1 }
            if let (cat, spent, limit, _) = highest, limit > 0 {
                Text("\(NAFinanceService.categoryLabel(cat)) liegt bei \(Int(spent))€ von \(Int(limit))€.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Text("Tippe auf + um eine Ausgabe zu erfassen – der Agent lernt deine Ausgabenmuster.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ncCyan.opacity(0.1), lineWidth: 0.5))
        )
    }

    // MARK: - Helpers
    private func statBox(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    // MARK: - Add Expense Sheet (NumberPad)
    private var addExpenseSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["essen", "transport", "einkaufen", "wohnen", "freizeit", "gesundheit", "sonstiges"], id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: NAFinanceService.categoryIcon(cat))
                                        .font(.system(size: 10))
                                    Text(NAFinanceService.categoryLabel(cat))
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundColor(selectedCategory == cat ? .white : .ncCyan)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == cat ?
                                        Color.ncCyan :
                                        Color.ncCyan.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color(red: 0.02, green: 0.02, blue: 0.04))

                Divider().overlay(Color.white.opacity(0.06))

                // NumberPad
                NANumberPad(
                    amount: $amountDouble,
                    note: $note,
                    category: selectedCategory,
                    onSubmit: {
                        finance.addExpense(amount: amountDouble, category: selectedCategory, note: note)
                        amountDouble = 0.0
                        note = ""
                        showAddExpense = false
                    }
                )
                .padding(.top, 20)

                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { showAddExpense = false }
                        .foregroundColor(.ncCyan)
                }
                ToolbarItem(placement: .principal) {
                    Text("Neue Ausgabe")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
    }
}