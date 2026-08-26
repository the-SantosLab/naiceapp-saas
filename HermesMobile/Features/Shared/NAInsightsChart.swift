import SwiftUI

// MARK: - Line Graph for Spending Trends (ported from Dime)
struct NALineGraph: View {
    let dataPoints: [GraphPoint]
    let lineColor: Color
    let title: String

    @State private var graphProgress: CGFloat = 0
    @State private var showPlot = false
    @State private var currentPlot: GraphPoint?
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.gray)

            // Header with current value
            if let plot = currentPlot {
                HStack(spacing: 6) {
                    Text(plot.label)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.gray)
                    Text("€\(Int(plot.value))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 4)
            }

            GeometryReader { proxy in
                let height = proxy.size.height
                let width = proxy.size.width / CGFloat(max(dataPoints.count - 1, 1))
                let values = dataPoints.map { $0.value }
                let maxValue = max(values.max() ?? 1, 1)
                let minValue = min(values.min() ?? 0, 0)

                let points: [CGPoint] = dataPoints.enumerated().map { i, point in
                    let progress = (point.value - minValue) / (maxValue - minValue)
                    let x = width * CGFloat(i)
                    let y = height - (progress * height)
                    return CGPoint(x: x, y: y)
                }

                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { i in
                            Divider()
                                .overlay(Color.white.opacity(0.04))
                            if i < 3 { Spacer() }
                        }
                    }

                    // Line
                    AnimatedLine(points: points, progress: graphProgress)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Gradient fill under line
                    if graphProgress > 0 {
                        LinearGradient(
                            gradient: Gradient(colors: [lineColor.opacity(0.15), lineColor.opacity(0.01)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: height))
                                path.addLines(points)
                                path.addLine(to: CGPoint(x: points.last?.x ?? proxy.size.width, y: height))
                                path.closeSubpath()
                            }
                        )
                        .opacity(graphProgress)
                    }

                    // Touch overlay
                    if showPlot, let plot = currentPlot, let idx = dataPoints.firstIndex(of: plot) {
                        let point = points[idx]
                        VStack(spacing: 0) {
                            Circle()
                                .fill(lineColor)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        }
                        .offset(x: point.x - 5, y: point.y - 5)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            withAnimation(.easeIn(duration: 0.15)) { showPlot = true }
                            let idx = max(0, min(Int((value.location.x / width).rounded()), dataPoints.count - 1))
                            currentPlot = dataPoints[idx]
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.3)) { showPlot = false }
                        }
                )
            }
            .frame(height: 140)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 1.0)) { graphProgress = 1 }
                }
            }
            .onChange(of: dataPoints) { _ in
                graphProgress = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 1.0)) { graphProgress = 1 }
                }
            }
        }
    }
}

// MARK: - Animated Line Shape
struct AnimatedLine: Shape {
    let points: [CGPoint]
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            guard points.count > 1 else { return }
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
        }
        .trimmedPath(from: 0, to: progress)
    }
}

// MARK: - Data Point
struct GraphPoint: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: Double

    static func == (lhs: GraphPoint, rhs: GraphPoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Suggested Transactions (ported from Dime)
struct NASuggestedTransactions: View {
    let suggestions: [SuggestedExpense]
    let currencySymbol: String
    var onTap: (SuggestedExpense) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vorgeschlagen")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.gray)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions) { item in
                            Button {
                                onTap(item)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(item.label)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    HStack(spacing: 2) {
                                        Text(currencySymbol)
                                            .font(.system(size: 10, weight: .semibold))
                                        Text("\(Int(item.amount))")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(item.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(item.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                                }
                                .padding(6)
                                .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct SuggestedExpense: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let category: String
    let color: Color
}