import SwiftUI

// MARK: - Calculator-Style NumberPad (ported from Dime)
struct NANumberPad: View {
    @Binding var amount: Double
    @Binding var note: String
    var category: String
    var onSubmit: () -> Void

    let keys = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 10) {
            // Amount display
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("€")
                    .font(.system(.title2, design: .rounded))
                    .foregroundColor(.gray)

                Text(String(format: "%.2f", amount))
                    .font(.system(size: 44, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: amount)
            }
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(alignment: .trailing) {
                if amount > 0 {
                    Button {
                        deleteLastDigit()
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: Circle())
                    }
                    .padding(.trailing, 8)
                }
            }

            // Note field
            TextField("Notiz (optional)", text: $note)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                .padding(.horizontal, 20)

            // Number grid
            VStack(spacing: 8) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { num in
                            numberButton(num)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button {
                        // decimal point
                        let whole = floor(amount)
                        let frac = amount - whole
                        if frac == 0 {
                            amount = whole + 0.01
                        }
                    } label: {
                        Text(".")
                            .font(.system(size: 32, weight: .regular, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundColor(.white)
                    }

                    numberButton(0)

                    Button {
                        onSubmit()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundColor(.white)
                            .background(amount > 0 ? Color.ncNeonGreen : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(amount <= 0)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func numberButton(_ num: Int) -> some View {
        Button {
            if amount >= 10000000 { return }
            amount *= 10
            amount += Double(num) / 100
        } label: {
            Text("\(num)")
                .font(.system(size: 32, weight: .regular, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                .foregroundColor(.white)
        }
    }

    private func deleteLastDigit() {
        amount = Double(Int(amount * 10)) / 100
    }
}