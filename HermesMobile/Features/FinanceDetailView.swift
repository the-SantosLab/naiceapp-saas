import SwiftUI

// MARK: - Finance Detail View
struct FinanceDetailView: View {
    @ObservedObject private var finance = NAFinanceService.shared
    @State private var showAddExpense = false
    @State private var amount = ""
    @State private var selectedCategory = "essen"
    @State private var note = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Finanzen").font(.title2.weight(.bold)).foregroundColor(.ncDark)
                Text("\(Int(finance.monthlyTotal)) € ausgegeben diesen Monat").font(.subheadline).foregroundColor(.ncMuted)

                // Budget Overview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget-Ubersicht").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    ForEach(finance.categorySpending, id: \.0) { cat, spent, limit, pct in
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: NAFinanceService.categoryIcon(cat)).font(.caption).foregroundColor(.ncSage)
                                Text(NAFinanceService.categoryLabel(cat)).font(.subheadline).foregroundColor(.ncDark)
                                Spacer()
                                Text("\(Int(spent))€/\(Int(limit))€").font(.caption).foregroundColor(.ncMuted)
                            }
                            ProgressView(value: min(pct / 100, 1.0))
                                .tint(pct > 90 ? .ncRed : pct > 70 ? .ncGold : .ncGreen)
                        }
                    }
                }.warmCard()

                // Recent Expenses
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Letzte Ausgaben").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                        Spacer()
                        Button { showAddExpense = true } label: {
                            Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.ncGreen)
                        }
                    }
                    if finance.expenses.isEmpty {
                        Text("Noch keine Ausgaben erfasst.").font(.subheadline).foregroundColor(.ncMuted)
                    } else {
                        ForEach(finance.expenses.prefix(10)) { expense in
                            HStack(spacing: 10) {
                                Image(systemName: NAFinanceService.categoryIcon(expense.category))
                                    .font(.caption).foregroundColor(.ncSage).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NAFinanceService.categoryLabel(expense.category))
                                        .font(.subheadline.weight(.semibold)).foregroundColor(.ncDark)
                                    if !expense.note.isEmpty {
                                        Text(expense.note).font(.caption).foregroundColor(.ncMuted)
                                    }
                                }
                                Spacer()
                                Text("\(Int(expense.amount))€")
                                    .font(.subheadline.weight(.bold)).foregroundColor(.ncDark)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(8)
                        }
                    }
                }.warmCard()

                // AI-Tipp
                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    let highest = finance.categorySpending.max { $0.1 < $1.1 }
                    if let (cat, spent, limit, _) = highest, limit > 0 {
                        Text("\(NAFinanceService.categoryLabel(cat)) liegt bei \(Int(spent))€ von \(Int(limit))€.")
                            .font(.subheadline).foregroundColor(.ncMuted)
                    }
                }.warmCard()

                // AI-Tipp
                VStack(spacing: 8) {
                    Text("AI-Tipp").font(.headline.weight(.semibold)).foregroundColor(.ncDark)
                    Text("Tippe auf + um eine Ausgabe zu erfassen – der Agent lernt deine Ausgabenmuster.")
                        .font(.subheadline).foregroundColor(.ncMuted)
                }.warmCard()
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .warmBackground()
        .navigationTitle("Finanzen")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddExpense) {
            addExpenseSheet
        }
    }

    private var addExpenseSheet: some View {
        NavigationStack {
            Form {
                TextField("Betrag (€)", text: $amount).keyboardType(.decimalPad)
                Picker("Kategorie", selection: $selectedCategory) {
                    ForEach(["essen", "transport", "einkaufen", "wohnen", "freizeit", "gesundheit", "sonstiges"], id: \.self) { cat in
                        Label(NAFinanceService.categoryLabel(cat), systemImage: NAFinanceService.categoryIcon(cat)).tag(cat)
                    }
                }
                TextField("Notiz (optional)", text: $note)
            }
            .navigationTitle("Neue Ausgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        if let amt = Double(amount) {
                            finance.addExpense(amount: amt, category: selectedCategory, note: note)
                            amount = ""; note = ""; showAddExpense = false
                        }
                    }
                    .disabled(amount.isEmpty || Double(amount) == nil)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { showAddExpense = false }
                }
            }
        }
    }
}