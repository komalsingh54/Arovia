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
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Insights")
                                .font(.largeTitle.weight(.bold))
                            Text("Patterns and comparisons, not just numbers.")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        NavigationLink { WeeklyRecapView() } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.tint)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.elevatedCardBackground, in: Circle())
                        }
                        .accessibilityLabel("Weekly Recap")
                    }
                }

                WeekRingStrip(
                    selectedDate: $selectedDate,
                    trends: healthStore.weeklyTrends,
                    liveMetrics: healthStore.metrics
                )

                ActivityRingsView(
                    date: selectedDate,
                    steps: dayValue(in: healthStore.weeklyTrends.steps, on: selectedDate, liveFallback: healthStore.metrics.steps),
                    activeEnergy: dayValue(in: healthStore.weeklyTrends.activeEnergy, on: selectedDate, liveFallback: healthStore.metrics.activeEnergy),
                    exerciseMinutes: dayValue(in: healthStore.weeklyTrends.exerciseMinutes, on: selectedDate, liveFallback: healthStore.metrics.exerciseMinutes),
                    isInChartedRange: isDateInChartedRange(selectedDate)
                )

                if let insight = weeklyInsight {
                    InsightBanner(text: insight)
                }

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

                JournalWeekSummary(entries: localStore.journalEntries)

                // The week strip above already handles date selection (with rings, so it
                // doubles as a mini activity summary) — a separate month grid was a second,
                // redundant way to pick a date and made the screen feel more complicated
                // than it needed to be.
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

    /// Surfaces whichever of the three ring metrics deviates most from its own 7-day average
    /// today — that's the one worth a sentence, rather than printing all three every time.
    private var weeklyInsight: String? {
        let insights = HealthInsights(metrics: healthStore.metrics, trends: healthStore.weeklyTrends, calorieTarget: 2_000)
        let candidates = [insights.stepsTrendInsight, insights.activeEnergyTrendInsight, insights.exerciseTrendInsight].compactMap { $0 }
        return candidates.first
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
                    AnimatedRing(progress: moveProgress, color: AppTheme.ringMove, lineWidth: 14, celebratesCompletion: true)
                        .frame(width: 208, height: 208)
                    AnimatedRing(progress: exerciseProgress, color: AppTheme.ringExercise, lineWidth: 14)
                        .frame(width: 164, height: 164)
                    AnimatedRing(progress: standProgress, color: AppTheme.ringStand, lineWidth: 14)
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
                    RingLegend(title: "Move", value: "\(Int(activeEnergy))/500 kcal", color: AppTheme.ringMove)
                    RingLegend(title: "Exercise", value: "\(Int(exerciseMinutes))/30 min", color: AppTheme.ringExercise)
                    RingLegend(title: "Steps", value: "\(Int(steps))/10k", color: AppTheme.ringStand)
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

private struct InsightBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(AppTheme.tint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding()
        .softCard(radius: 18)
    }
}

/// Replaces the old separate "Insights" tab, which computed this exact same
/// `JournalAnalytics` data and displayed it a second time with different chrome. One screen,
/// one job: this is now the only place the weekly journal breakdown lives.
private struct JournalWeekSummary: View {
    let entries: [JournalEntry]

    private var analytics: JournalAnalytics { JournalAnalytics(entries: entries) }
    private var data: [CategoryCount] { analytics.categoryCounts.map { CategoryCount(category: $0.category, count: $0.count) } }

    private var streakInsight: String {
        let streak = analytics.currentStreak
        if streak == 0 { return "No journal streak yet — log something today to start one." }
        if streak == 1 { return "You've journaled today — log tomorrow too to start a streak." }
        return "You're on a \(streak)-day journaling streak. Keep it going."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Journal")
                .font(.title3.weight(.bold))

            HStack(spacing: 12) {
                JournalStatCard(value: analytics.entriesThisWeek.count.formatted(), label: "Entries this week", icon: "note.text")
                JournalStatCard(value: analytics.currentStreak.formatted(), label: "Day streak", icon: "flame.fill")
            }

            Text(streakInsight)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)

            Chart(data) { item in
                BarMark(
                    x: .value("Category", item.category.title),
                    y: .value("Entries", item.count)
                )
                .foregroundStyle(AppTheme.tint.gradient)
                .cornerRadius(6)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 160)
            .accessibilityLabel("Weekly journal entries by category")
        }
        .padding()
        .softCard(radius: 24)
    }
}

private struct JournalStatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.tint)
            Text(value).font(.title2.bold()).foregroundStyle(AppTheme.primaryText)
            Text(label).font(.caption).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CategoryCount: Identifiable {
    let category: JournalCategory
    let count: Int
    var id: JournalCategory { category }
}

/// A week-at-a-glance date picker where each day is its own tiny three-ring glyph — the same
/// pattern Apple's own Fitness app uses for its weekly summary. Doubles as both a calendar and
/// a "how did each day go" snapshot, so there's no separate month grid competing for the same job.
private struct WeekRingStrip: View {
    @Binding var selectedDate: Date
    let trends: WeeklyHealthTrends
    let liveMetrics: DailyMetrics
    private let calendar = Calendar.current

    private var weekDays: [Date] {
        guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func progress(in points: [DailyMetricPoint], on date: Date, goal: Double, liveFallback: Double) -> Double {
        let value = points.first { calendar.isDate($0.date, inSameDayAs: date) }?.value
            ?? (calendar.isDateInToday(date) ? liveFallback : 0)
        return min(value / goal, 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                Button {
                    withAnimation(.snappy) { selectedDate = date }
                } label: {
                    VStack(spacing: 8) {
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(calendar.isDateInToday(date) ? AppTheme.tint : AppTheme.secondaryText)
                        MiniRingGlyph(
                            move: progress(in: trends.activeEnergy, on: date, goal: 500, liveFallback: liveMetrics.activeEnergy),
                            exercise: progress(in: trends.exerciseMinutes, on: date, goal: 30, liveFallback: liveMetrics.exerciseMinutes),
                            stand: progress(in: trends.steps, on: date, goal: 10_000, liveFallback: liveMetrics.steps)
                        )
                        .frame(width: 34, height: 34)
                        Text(date, format: .dateTime.day())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.elevatedCardBackground)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .softCard(radius: 22)
    }
}

/// Small static three-ring icon (no animation — these render seven at once in a row) using
/// Apple's canonical Move-outer/Exercise-middle/Stand-inner order and colors.
private struct MiniRingGlyph: View {
    let move: Double
    let exercise: Double
    let stand: Double

    var body: some View {
        ZStack {
            ring(progress: 1, color: AppTheme.ringMove.opacity(0.18), diameter: 34)
            ring(progress: move, color: AppTheme.ringMove, diameter: 34)
            ring(progress: 1, color: AppTheme.ringExercise.opacity(0.18), diameter: 24)
            ring(progress: exercise, color: AppTheme.ringExercise, diameter: 24)
            ring(progress: 1, color: AppTheme.ringStand.opacity(0.18), diameter: 14)
            ring(progress: stand, color: AppTheme.ringStand, diameter: 14)
        }
    }

    private func ring(progress: Double, color: Color, diameter: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: max(progress, 0.001))
            .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: diameter, height: diameter)
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
