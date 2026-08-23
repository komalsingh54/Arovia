//
//  BentoCard.swift
//  Arovia
//
//  Icon-badge + mixed-size card family for the Dashboard bento grid — same compositional
//  pattern as the reference (a featured ring card, a tall accent card, compact stat cards),
//  built from Arovia's own color system rather than copying the reference's palette.
//

import SwiftUI

/// The featured card — a bold fill in the accent color (not just a tinted icon on a neutral
/// card), matching the reference's solid black "Walk" card that's impossible to miss. Text and
/// ring track use `AppTheme.screenBackground` for contrast — the same on-accent convention
/// already used on filled buttons elsewhere, so it reads correctly in both Light and Dark mode.
struct BentoRingCard: View {
    let title: String
    let value: Double
    let unit: String
    let systemImage: String
    let color: Color
    let goalValue: Double
    var precision: Int = 0

    private var progress: Double { goalValue > 0 ? min(value / goalValue, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            iconBadge
            Spacer(minLength: 0)
            ZStack {
                AnimatedRing(progress: progress, color: AppTheme.screenBackground, lineWidth: 9)
                    .frame(width: 84, height: 84)
                VStack(spacing: 0) {
                    AnimatedNumberText(value: value, precision: precision)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.screenBackground)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.screenBackground.opacity(0.7))
                }
                .padding(.horizontal, 6)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.screenBackground)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 220)
        .background(color, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value)) \(unit), \(Int(progress * 100)) percent of goal")
    }

    private var iconBadge: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.screenBackground)
            .frame(width: 34, height: 34)
            .background(AppTheme.screenBackground.opacity(0.18), in: Circle())
    }
}

/// Tall accent card — bold fill, same on-accent contrast convention as BentoRingCard — mirrors
/// the reference's solid blue "Water" card. Used for hydration on Arovia's dashboard.
struct BentoTallCard: View {
    let title: String
    let value: Double
    let unit: String
    let systemImage: String
    let color: Color
    let goalValue: Double
    var precision: Int = 0

    private var progress: Double { goalValue > 0 ? min(value / goalValue, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.screenBackground)
                .frame(width: 34, height: 34)
                .background(AppTheme.screenBackground.opacity(0.18), in: Circle())

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                AnimatedNumberText(value: value, precision: precision)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.screenBackground)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(AppTheme.screenBackground.opacity(0.7))
            }

            Capsule()
                .fill(AppTheme.screenBackground.opacity(0.22))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(AppTheme.screenBackground)
                            .frame(width: proxy.size.width * progress)
                            .animation(.spring(response: 0.7, dampingFraction: 0.85), value: progress)
                    }
                }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.screenBackground)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 220)
        .background(color, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value)) \(unit), \(Int(progress * 100)) percent of goal")
    }
}

/// Compact stat card — icon badge, number, title. The bento grid's "filler" cells.
struct BentoStatCard: View {
    let title: String
    let value: Double
    let unit: String
    let systemImage: String
    let color: Color
    var precision: Int = 0
    var placeholder: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.16), in: Circle())
            if placeholder {
                Text("—")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                AnimatedNumberText(value: value, precision: precision)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
            }
            Text(placeholder ? title : "\(title) · \(unit)")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 104)
        .softCard(radius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(placeholder ? "no data" : "\(Int(value)) \(unit)")
    }
}
