import SwiftUI

// MARK: - Radar Chart (6-zackig, Canvas + SwiftUI Labels)
struct RadarChart: View {
    let dimensions: [LifeDimension]
    let gridLines: Int = 4

    var body: some View {
        let scores = dimensions.map { CGFloat($0.score) / 100.0 }

        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let radius = min(cx, cy) * 0.75
            let sides = dimensions.count
            let angleStep = 2.0 * .pi / CGFloat(sides)

            ZStack {
                // Canvas for chart
                Canvas { context, size in
                    // Grid circles
                    for g in 1...gridLines {
                        let r = radius * CGFloat(g) / CGFloat(gridLines)
                        var gridPath = Path()
                        for i in 0..<sides {
                            let angle = -CGFloat.pi / 2 + angleStep * CGFloat(i)
                            let x = cx + r * cos(angle)
                            let y = cy + r * sin(angle)
                            if i == 0 { gridPath.move(to: CGPoint(x: x, y: y)) }
                            else { gridPath.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        gridPath.closeSubpath()
                        context.stroke(gridPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                    }

                    // Axis lines
                    for i in 0..<sides {
                        let angle = -CGFloat.pi / 2 + angleStep * CGFloat(i)
                        let x = cx + radius * cos(angle)
                        let y = cy + radius * sin(angle)
                        var line = Path()
                        line.move(to: CGPoint(x: cx, y: cy))
                        line.addLine(to: CGPoint(x: x, y: y))
                        context.stroke(line, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
                    }

                    // Data polygon
                    var dataPath = Path()
                    for i in 0..<sides {
                        let score = min(max(scores[i], 0.05), 1.0)
                        let angle = -CGFloat.pi / 2 + angleStep * CGFloat(i)
                        let r = radius * score
                        let x = cx + r * cos(angle)
                        let y = cy + r * sin(angle)
                        if i == 0 { dataPath.move(to: CGPoint(x: x, y: y)) }
                        else { dataPath.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    dataPath.closeSubpath()
                    context.fill(dataPath, with: .color(.ncCyan.opacity(0.15)))
                    context.stroke(dataPath, with: .color(.ncCyan.opacity(0.4)), lineWidth: 1.5)

                    // Score points
                    for i in 0..<sides {
                        let score = min(max(scores[i], 0.05), 1.0)
                        let angle = -CGFloat.pi / 2 + angleStep * CGFloat(i)
                        let r = radius * score
                        let x = cx + r * cos(angle)
                        let y = cy + r * sin(angle)
                        let rect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                        context.fill(Path(ellipseIn: rect), with: .color(dimensions[i].color))
                    }
                }

                // SwiftUI Labels (Icons + Text) positioned around chart
                ForEach(Array(dimensions.enumerated()), id: \.element.id) { i, dim in
                    let angle = -CGFloat.pi / 2 + angleStep * CGFloat(i)
                    let labelR = radius + 28
                    let x = cx + labelR * cos(angle)
                    let y = cy + labelR * sin(angle)

                    VStack(spacing: 2) {
                        Image(systemName: dim.icon)
                            .font(.system(size: 10))
                            .foregroundColor(dim.color)
                        Text(dim.label)
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    .position(x: x, y: y)
                }
            }
        }
        .frame(height: 240)
    }
}

// MARK: - Preview
#Preview {
    RadarChart(dimensions: [
        LifeDimension(id: "a", icon: "heart.fill", label: "Gesundheit", score: 80, trend: .up, detail: "80%"),
        LifeDimension(id: "b", icon: "briefcase.fill", label: "Arbeit", score: 60, trend: .flat, detail: "60%"),
        LifeDimension(id: "c", icon: "person.2.fill", label: "Beziehungen", score: 40, trend: .down, detail: "40%"),
        LifeDimension(id: "d", icon: "house.fill", label: "Alltag", score: 90, trend: .up, detail: "90%"),
        LifeDimension(id: "e", icon: "creditcard.fill", label: "Finanzen", score: 50, trend: .flat, detail: "50%"),
        LifeDimension(id: "f", icon: "lightbulb.fill", label: "Kreativität", score: 70, trend: .up, detail: "70%"),
    ])
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}