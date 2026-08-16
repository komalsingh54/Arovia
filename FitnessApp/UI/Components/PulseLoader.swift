//
//  PulseLoader.swift
//  Arovia
//
//  A looping EKG-style pulse line, echoing the app icon's heartbeat motif. Used in place of a
//  plain ProgressView wherever the app is actively fetching something — a small branded moment
//  instead of a generic system spinner.
//

import SwiftUI

struct PulseLoader: View {
    var color: Color = AppTheme.tint
    var lineWidth: CGFloat = 3

    @State private var trimEnd: CGFloat = 0

    var body: some View {
        PulseShape()
            .trim(from: 0, to: trimEnd)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: 64, height: 28)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    trimEnd = 1
                }
            }
            .accessibilityHidden(true)
    }
}

/// A simple EKG trace: flat, small bump, sharp spike, flat.
private struct PulseShape: Shape {
    func path(in rect: CGRect) -> Path {
        let midY = rect.midY
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: rect.width * 0.22, y: midY))
        path.addLine(to: CGPoint(x: rect.width * 0.32, y: midY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.width * 0.40, y: midY + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.width * 0.48, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.56, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.64, y: midY - rect.height * 0.1))
        path.addLine(to: CGPoint(x: rect.width * 0.76, y: midY))
        path.addLine(to: CGPoint(x: rect.width, y: midY))
        return path
    }
}

/// Small inline variant with a label, for use in list rows / loading states.
struct PulseLoadingRow: View {
    let text: String
    var color: Color = AppTheme.tint

    var body: some View {
        HStack(spacing: 10) {
            PulseLoader(color: color, lineWidth: 2.5)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        PulseLoader()
        PulseLoadingRow(text: "Looking up product…")
    }
    .padding()
    .background(AppTheme.screenBackground)
}
