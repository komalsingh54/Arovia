//
//  GlowHeroCard.swift
//  Arovia
//
//  A single hero stat with a soft blurred glow behind it, echoing the glucose "blob" from the
//  reference design. Dashboard shows several of these in a swipeable carousel ("all of them")
//  instead of picking one metric to feature over the others.
//

import SwiftUI

struct GlowHeroCard: View {
    let title: String
    let value: Double
    let unit: String
    let systemImage: String
    let color: Color
    var goalValue: Double? = nil
    var precision: Int = 0
    var placeholder: Bool = false

    private var progress: Double {
        guard let goalValue, goalValue > 0 else { return 0 }
        return min(value / goalValue, 1)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                AppTheme.glow(color)
                    .frame(width: 190, height: 190)
                    .blur(radius: 6)

                if goalValue != nil {
                    AnimatedRing(progress: progress, color: color, lineWidth: 10)
                        .frame(width: 128, height: 128)
                }

                VStack(spacing: 2) {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                    if placeholder {
                        Text("—").font(.system(size: 34, weight: .bold, design: .rounded))
                    } else {
                        AnimatedNumberText(value: value, precision: precision)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(height: 150)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            if let goalValue {
                Text(placeholder ? "No data yet" : "\(Int(progress * 100))% of \(Int(goalValue)) \(unit) goal")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.vertical, 20)
        .frame(width: 176)
        .softCard(radius: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(placeholder ? "no data" : "\(Int(value)) \(unit)")
    }
}

/// Horizontal, swipeable row of hero cards — "all of them" get the featured treatment,
/// the user just pages between them instead of everything competing for space at once.
struct GlowHeroCarousel<Data: RandomAccessCollection>: View where Data.Element: Identifiable {
    let items: Data
    let content: (Data.Element) -> GlowHeroCard

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(items) { item in
                    content(item)
                }
            }
            .padding(.horizontal, 2)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 2, for: .scrollContent)
    }
}
