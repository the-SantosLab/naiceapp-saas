import SwiftUI

// MARK: - Donut Chart for Category Breakdown (ported from Dime)
struct NADonutChart: View {
    let data: [DonutSlice]
    let total: Double

    var body: some View {
        VStack(spacing: 16) {
            // Donut
            ZStack {
                ForEach(Array(data.enumerated()), id: \.element.id) { i, slice in
                    DonutSegment(
                        startAngle: startAngle(for: i),
                        endAngle: endAngle(for: i),
                        color: slice.color
                    )
                    .frame(width: 140, height: 140)
                }

                // Center text
                VStack(spacing: 2) {
                    Text("€\(Int(total))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Gesamt")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)

            // Legend
            VStack(spacing: 8) {
                ForEach(data) { slice in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(slice.color)
                            .frame(width: 8, height: 8)

                        Text(slice.label)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white)

                        Spacer()

                        Text("€\(Int(slice.amount))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("\(Int(slice.percent * 100))%")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.gray)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func startAngle(for index: Int) -> Angle {
        let cumulative = data[0..<index].reduce(0) { $0 + $1.percent }
        return .degrees(-90 + cumulative * 360)
    }

    private func endAngle(for index: Int) -> Angle {
        let cumulative = data[0...index].reduce(0) { $0 + $1.percent }
        return .degrees(-90 + cumulative * 360)
    }
}

// MARK: - Donut Segment
struct DonutSegment: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2

            Path { path in
                path.addArc(center: center, radius: radius,
                           startAngle: startAngle, endAngle: endAngle,
                           clockwise: false)
            }
            .stroke(color, style: StrokeStyle(lineWidth: 28, lineCap: .butt))
            .shadow(color: color.opacity(0.3), radius: 4)
        }
    }
}

// MARK: - Data Model
struct DonutSlice: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let color: Color
    var percent: Double { amount > 0 ? amount / total : 0 }
    let total: Double
}

// MARK: - Bar Chart (Alternative zur Donut)
struct NABarChart: View {
    let data: [DonutSlice]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(data) { slice in
                HStack(spacing: 10) {
                    Text(slice.label)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.04, green: 0.04, blue: 0.08))
                                .frame(height: 18)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(slice.color)
                                .frame(width: geo.size.width * CGFloat(slice.percent), height: 18)
                                .animation(.spring(response: 0.6), value: slice.percent)
                        }
                    }
                    .frame(height: 18)

                    Text("€\(Int(slice.amount))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 60, alignment: .trailing)

                    Text("\(Int(slice.percent * 100))%")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.gray)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }
}