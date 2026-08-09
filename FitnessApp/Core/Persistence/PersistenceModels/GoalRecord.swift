//
//  GoalRecord.swift
//  Arovia
//
//  SwiftData persistence model. Framework detail — never exposed to Views or ViewModels directly;
//  GoalsRepository maps to/from the domain model `FitnessGoal`.
//

import Foundation
import SwiftData

@Model
final class GoalRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetValue: Double
    var currentValue: Double
    var unit: String
    var metricRaw: String
    var createdAt: Date
    var updatedAt: Date

    /// Set once the record has a corresponding CloudKit record so we can update instead of re-create.
    var cloudRecordName: String?
    /// True when local changes haven't been confirmed as synced to CloudKit yet.
    var pendingSync: Bool

    init(
        id: UUID,
        title: String,
        targetValue: Double,
        currentValue: Double,
        unit: String,
        metricRaw: String,
        createdAt: Date,
        updatedAt: Date,
        cloudRecordName: String? = nil,
        pendingSync: Bool = true
    ) {
        self.id = id
        self.title = title
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.metricRaw = metricRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cloudRecordName = cloudRecordName
        self.pendingSync = pendingSync
    }
}

extension GoalRecord {
    var asDomainModel: FitnessGoal {
        FitnessGoal(
            id: id,
            title: title,
            targetValue: targetValue,
            unit: unit,
            metric: GoalMetric(rawValue: metricRaw) ?? .custom,
            currentValue: currentValue,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ goal: FitnessGoal) {
        title = goal.title
        targetValue = goal.targetValue
        currentValue = goal.currentValue
        unit = goal.unit
        metricRaw = goal.metric.rawValue
        updatedAt = goal.updatedAt
        pendingSync = true
    }

    convenience init(_ goal: FitnessGoal) {
        self.init(
            id: goal.id,
            title: goal.title,
            targetValue: goal.targetValue,
            currentValue: goal.currentValue,
            unit: goal.unit,
            metricRaw: goal.metric.rawValue,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt
        )
    }
}
