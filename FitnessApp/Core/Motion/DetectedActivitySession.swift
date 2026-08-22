//
//  DetectedActivitySession.swift
//  Arovia
//
//  Plain domain model, kept CoreMotion-free (mirrors how ManualWorkoutType keeps HealthKit out
//  of the View layer) — MotionActivityDetector maps CMMotionActivity into this internally.
//

import Foundation

struct DetectedActivitySession: Identifiable, Equatable {
    let id: String
    let type: ManualWorkoutType
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}
