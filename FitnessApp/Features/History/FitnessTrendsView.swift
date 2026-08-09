//
//  FitnessTrendsView.swift
//  Arovia
//

import SwiftUI
import Charts

struct FitnessTrendsView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Trends")
                        .font(.largeTitle.weight(.bold))
                    Text("A clear view of your activity and consistency.")
                        .foregroundStyle(AppTheme.secondaryText)
                }

                ActivityRingsView(metrics: healthStore.metrics)

                JournalBarChart(entries: localStore.journalEntries)

                JournalCalendar(entries: localStore.journalEntries)
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .task { await healthStore.refresh() }
    }
}

private struct ActivityRingsView: View {
    let metrics: DailyMetrics

    private var moveProgress: Double { min(metrics.activeEnergy / 500, 1) }
    private var exerciseProgress: Double { min(metrics.exerciseMinutes / 30, 1) }
    private var standProgress: Double { min(metrics.steps / 10_000, 1) }

    var body: some View {
        VStack(spacing: 16) {
            Text("Today’s Activity")
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                ActivityRing(progress: standProgress, color: AppTheme.tint, diameter: 208)
                ActivityRing(progress: exerciseProgress, color: .cyan, diameter: 164)
                ActivityRing(progress: moveProgress, color: AppTheme.energy, diameter: 120)
                VStack(spacing: 2) {
                    Text("MOVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("\(metrics.activeEnergy.formatted(.number.precision(.fractionLength(0))))")
                        .font(.title.bold())
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today’s activity rings")
            .accessibilityValue("\(Int(moveProgress * 100)) percent move, \(Int(exerciseProgress * 100)) percent exercise, \(Int(standProgress * 100)) percent steps")

            HStack {
                RingLegend(title: "Move", value: "\(Int(metrics.activeEnergy))/500 kcal", color: AppTheme.energy)
                RingLegend(title: "Exercise", value: "\(Int(metrics.exerciseMinutes))/30 min", color: .cyan)
                RingLegend(title: "Steps", value: "\(Int(metrics.steps))/10k", color: AppTheme.tint)
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }
}

private struct ActivityRing: View {
    let progress: Double
    let color: Color
    let diameter: CGFloat

    var body: some View {
        Circle()
            .stroke(color.opacity(0.14), lineWidth: 14)
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
            }
    }
}

private struct RingLegend: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption.weight(.semibold))
            Text(value).font(.caption2).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct JournalBarChart: View {
    let entries: [JournalEntry]

    private var data: [CategoryCount] {
        let analytics = JournalAnalytics(entries: entries)
        return analytics.categoryCounts.map { CategoryCount(category: $0.category, count: $0.count) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Journal")
                .font(.title3.weight(.bold))
            Chart(data) { item in
                BarMark(
                    x: .value("Category", item.category.title),
                    y: .value("Entries", item.count)
                )
                .foregroundStyle(AppTheme.tint.gradient)
                .cornerRadius(6)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
            .accessibilityLabel("Weekly journal entries by category")
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }
}

private struct CategoryCount: Identifiable {
    let category: JournalCategory
    let count: Int
    var id: JournalCategory { category }
}

private struct JournalCalendar: View {
    let entries: [JournalEntry]
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Date.now, format: .dateTime.month(.wide).year())
                .font(.title3.weight(.bold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday.prefix(1)).font(.caption.weight(.bold)).foregroundStyle(AppTheme.secondaryText)
                }
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let hasEntry = entries.contains { calendar.isDate($0.date, inSameDayAs: date) }
                        Text(date, format: .dateTime.day())
                            .font(.caption.weight(.semibold))
                            .frame(width: 30, height: 30)
                            .background(hasEntry ? AppTheme.tint : .clear, in: Circle())
                            .foregroundStyle(hasEntry ? AppTheme.screenBackground : .primary)
                            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                            .accessibilityValue(hasEntry ? "Journal entry recorded" : "No journal entry")
                    } else {
                        Color.clear.frame(width: 30, height: 30)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border) }
    }

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: .now),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) else { return [] }
        let weekdayOffset = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: weekdayOffset) + range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: monthStart)
        }
    }
}
