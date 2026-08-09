//
//  FitnessGoal.swift
//  Arovia
//

import Foundation

enum GoalMetric: String, Codable, CaseIterable, Identifiable {
    case steps
    case activeEnergy
    case exerciseMinutes
    case workouts
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: "Steps"
        case .activeEnergy: "Active Energy"
        case .exerciseMinutes: "Exercise Minutes"
        case .workouts: "Workouts"
        case .custom: "Custom"
        }
    }

    var defaultUnit: String {
        switch self {
        case .steps: "steps"
        case .activeEnergy: "kcal"
        case .exerciseMinutes: "minutes"
        case .workouts: "workouts"
        case .custom: "units"
        }
    }
}

struct FitnessGoal: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let createdAt: Date
    let metric: GoalMetric

    init(title: String, targetValue: Double, unit: String, metric: GoalMetric = .custom, currentValue: Double = 0, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.createdAt = createdAt
        self.metric = metric
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1)
    }

    func currentValue(using metrics: DailyMetrics) -> Double {
        switch metric {
        case .steps: metrics.steps
        case .activeEnergy: metrics.activeEnergy
        case .exerciseMinutes: metrics.exerciseMinutes
        case .workouts: Double(metrics.workoutCount)
        case .custom: currentValue
        }
    }

    func progress(using metrics: DailyMetrics) -> Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue(using: metrics) / targetValue, 1)
    }

    func updatingCurrentValue(to value: Double) -> FitnessGoal {
        FitnessGoal(
            id: id,
            title: title,
            targetValue: targetValue,
            unit: unit,
            metric: metric,
            currentValue: value,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, targetValue, currentValue, unit, createdAt, metric
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetValue = try container.decode(Double.self, forKey: .targetValue)
        currentValue = try container.decode(Double.self, forKey: .currentValue)
        unit = try container.decode(String.self, forKey: .unit)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        metric = try container.decodeIfPresent(GoalMetric.self, forKey: .metric) ?? .custom
    }

    private init(id: UUID, title: String, targetValue: Double, unit: String, metric: GoalMetric, currentValue: Double, createdAt: Date) {
        self.id = id
        self.title = title
        self.targetValue = targetValue
        self.unit = unit
        self.metric = metric
        self.currentValue = currentValue
        self.createdAt = createdAt
    }
}
