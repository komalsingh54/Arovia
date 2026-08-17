//
//  FitnessTrendsView.swift
//  Arovia
//

import SwiftUI
import Charts

struct FitnessTrendsView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var localStore: LocalStore
    @State private var selectedDate = Date.now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Trends")
                        .font(.largeTitle.weight(.bold))
                    Text("A clear view of your activity and consistency.")
                        .foregroundStyle(AppTheme.secondaryText)
                }

                ActivityRingsView(
                    date: selectedDate,
                    steps: dayValue(in: healthStore.weeklyTrends.steps, on: selectedDate, liveFallback: healthStore.metrics.steps),
                    activeEnergy: dayValue(in: healthStore.weeklyTrends.activeEnergy, on: selectedDate, liveFallback: healthStore.metrics.activeEnergy),
                    exerciseMinutes: dayValue(in: healthStore.weeklyTrends.exerciseMinutes, on: selectedDate, liveFallback: healthStore.metrics.exerciseMinutes),
                    isInChartedRange: isDateInChartedRange(selectedDate)
                )

                WeeklyTrendChart(
                    title: "Distance",
                    points: healthStore.weeklyTrends.distanceMeters.map { DailyMetricPoint(date: $0.date, value: $0.value / 1000) },
                    unit: "km",
                    color: .cyan,
                    style: .bar
                )

                WeeklyTrendChart(
                    title: "Resting Heart Rate",
                    points: healthStore.weeklyTrends.restingHeartRate.filter { $0.value > 0 },
                    unit: "bpm",
                    color: AppTheme.energy,
                    style: .line
                )

                WeeklyTrendChart(
                    title: "Sleep",
                    points: healthStore.weeklyTrends.sleepHours,
                    unit: "hrs",
                    color: .indigo,
                    style: .bar
                )

                JournalBarChart(entries: localStore.journalEntries)

                JournalCalendar(entries: localStore.journalEntries, selectedDate: $selectedDate)

                SelectedDayDetail(date: selectedDate, entries: localStore.journalEntries, trends: healthStore.weeklyTrends)
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
        .clearsFloatingTabBar()
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .task { await healthStore.refresh() }
        .refreshable { await healthStore.refresh() }
    }

    /// Looks up a day's value from the 7-day trend series (which is what actually changes when a
    /// different calendar date is selected). Falls back to the live `metrics` snapshot only for
    /// today, and only if the trend array hasn't loaded yet — otherwise a selected date would
    /// silently keep showing today's numbers, which was the original bug.
    private func dayValue(in points: [DailyMetricPoint], on date: Date, liveFallback: Double) -> Double {
        if let match = points.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return match.value
        }
        return Calendar.current.isDateInToday(date) ? liveFallback : 0
    }

    private func isDateInChartedRange(_ date: Date) -> Bool {
        healthStore.weeklyTrends.steps.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

private struct WeeklyTrendChart: View {
    enum Style { case bar, line }

    let title: String
    let points: [DailyMetricPoint]
    let unit: String
    let color: Color
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))

            if points.isEmpty || points.allSatisfy({ $0.value == 0 }) {
                Text("Not enough data yet — this fills in automatically from Apple Health.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Chart(points) { point in
                    switch style {
                    case .bar:
                        BarMark(x: .value("Day", point.date, unit: .day), y: .value(unit, point.value))
                            .foregroundStyle(color.gradient)
                            .cornerRadius(6)
                    case .line:
                        LineMark(x: .value("Day", point.date, unit: .day), y: .value(unit, point.value))
                            .foregroundStyle(color)
                            .symbol(Circle())
                        AreaMark(x: .value("Day", point.date, unit: .day), y: .value(unit, point.value))
                            .foregroundStyle(color.opacity(0.12))
                    }
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                .frame(height: 160)
                .accessibilityLabel("\(title) over the last 7 days")
            }
        }
        .padding()
        .softCard(radius: 24)
    }
}

private struct ActivityRingsView: View {
    let date: Date
    let steps: Double
    let activeEnergy: Double
    let exerciseMinutes: Double
    let isInChartedRange: Bool

    private var moveProgress: Double { min(activeEnergy / 500, 1) }
    private var exerciseProgress: Double { min(exerciseMinutes / 30, 1) }
    private var standProgress: Double { min(steps / 10_000, 1) }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var titleText: String {
        isToday ? "Today’s Activity" : date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(titleText)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            if !isInChartedRange && !isToday {
                Text("Only the last 7 days have activity data charted here — select a more recent date to see rings for it.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ZStack {
                    AnimatedRing(progress: standProgress, color: AppTheme.tint, lineWidth: 14)
                        .frame(width: 208, height: 208)
                    AnimatedRing(progress: exerciseProgress, color: .cyan, lineWidth: 14)
                        .frame(width: 164, height: 164)
                    AnimatedRing(progress: moveProgress, color: AppTheme.energy, lineWidth: 14, celebratesCompletion: true)
                        .frame(width: 120, height: 120)
                    VStack(spacing: 2) {
                        Text("MOVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.secondaryText)
                        AnimatedNumberText(value: activeEnergy)
                            .font(.title.bold())
                        Text("kcal")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(titleText) activity rings")
                .accessibilityValue("\(Int(moveProgress * 100)) percent move, \(Int(exerciseProgress * 100)) percent exercise, \(Int(standProgress * 100)) percent steps")

                HStack {
                    RingLegend(title: "Move", value: "\(Int(activeEnergy))/500 kcal", color: AppTheme.energy)
                    RingLegend(title: "Exercise", value: "\(Int(exerciseMinutes))/30 min", color: .cyan)
                    RingLegend(title: "Steps", value: "\(Int(steps))/10k", color: AppTheme.tint)
                }
            }
        }
        .padding()
        .softCard(radius: 24)
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
        .softCard(radius: 24)
    }
}

private struct CategoryCount: Identifiable {
    let category: JournalCategory
    let count: Int
    var id: JournalCategory { category }
}

private struct JournalCalendar: View {
    let entries: [JournalEntry]
    @Binding var selectedDate: Date
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
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        Button {
                            selectedDate = date
                        } label: {
                            Text(date, format: .dateTime.day())
                                .font(.caption.weight(.semibold))
                                .frame(width: 30, height: 30)
                                .background(hasEntry ? AppTheme.tint : .clear, in: Circle())
                                .foregroundStyle(hasEntry ? AppTheme.screenBackground : .primary)
                                .overlay {
                                    if isSelected {
                                        Circle().stroke(AppTheme.tint, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(hasEntry ? "Journal entry recorded" : "No journal entry")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    } else {
                        Color.clear.frame(width: 30, height: 30)
                    }
                }
            }
        }
        .padding()
        .softCard(radius: 24)
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

/// Shown below the calendar once a date is tapped — pulls from the same journal entries and
/// weekly trend arrays that back the charts above, so selecting a date actually reflects real data
/// instead of the calendar being a decorative, non-interactive grid.
private struct SelectedDayDetail: View {
    let date: Date
    let entries: [JournalEntry]
    let trends: WeeklyHealthTrends
    private let calendar = Calendar.current

    private var dayEntries: [JournalEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func value(in points: [DailyMetricPoint]) -> Double? {
        points.first { calendar.isDate($0.date, inSameDayAs: date) }?.value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.title3.weight(.bold))

            let steps = value(in: trends.steps)
            let distance = value(in: trends.distanceMeters)
            let restingHR = value(in: trends.restingHeartRate)
            let sleep = value(in: trends.sleepHours)
            let hasMetrics = [steps, distance, restingHR, sleep].contains { ($0 ?? 0) > 0 }

            if hasMetrics {
                HStack(spacing: 16) {
                    if let steps, steps > 0 { DayStat(label: "Steps", value: "\(Int(steps))") }
                    if let distance, distance > 0 { DayStat(label: "Distance", value: String(format: "%.1f km", distance / 1000)) }
                    if let restingHR, restingHR > 0 { DayStat(label: "Resting HR", value: "\(Int(restingHR)) bpm") }
                    if let sleep, sleep > 0 { DayStat(label: "Sleep", value: String(format: "%.1f hrs", sleep)) }
                }
            } else {
                Text("No Health metrics for this day — only the last 7 days are charted.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if dayEntries.isEmpty {
                Text("No journal entries logged this day.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(dayEntries) { entry in
                        HStack(alignment: .top) {
                            Label(entry.title, systemImage: entry.category.systemImage)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(entry.date, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        if !entry.details.isEmpty {
                            Text(entry.details)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
        }
        .padding()
        .softCard(radius: 24)
    }
}

private struct DayStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(AppTheme.secondaryText)
        }
    }
}
