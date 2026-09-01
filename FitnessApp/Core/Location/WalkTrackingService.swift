//
//  WalkTrackingService.swift
//  Arovia
//
//  Foreground-only outdoor walk tracker (Phase 1). Deliberately CoreLocation-only at this layer —
//  no HealthKit here — so it can be previewed/tested without HealthKit entitlements, matching the
//  "UI never talks directly to HealthKit" rule: OutdoorWalkView asks HealthStore to persist the
//  finished walk, the same way ActivityView asks it to save a manual workout.
//

import Foundation
import Combine
import CoreLocation

@MainActor
final class WalkTrackingService: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case tracking
        case paused
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var route: [CLLocationCoordinate2D] = []
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var authorizationDenied = false

    /// Minutes per kilometer; 0 when there's not yet enough distance/time to mean anything.
    var paceMinutesPerKm: Double {
        guard distanceMeters > 10 else { return 0 }
        return (elapsed / 60) / (distanceMeters / 1000)
    }

    var startDate: Date? { sessionStart }

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var timer: Timer?
    private var sessionStart: Date?
    private var pausedAccumulated: TimeInterval = 0
    private var resumedAt: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 5 // meters — avoids noisy sub-5m GPS jitter inflating distance
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func start() {
        route = []
        distanceMeters = 0
        elapsed = 0
        pausedAccumulated = 0
        lastLocation = nil
        sessionStart = .now
        resumedAt = .now
        state = .tracking
        locationManager.startUpdatingLocation()
        startTimer()
    }

    func pause() {
        guard state == .tracking else { return }
        if let resumedAt {
            pausedAccumulated += Date.now.timeIntervalSince(resumedAt)
        }
        state = .paused
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
    }

    func resume() {
        guard state == .paused else { return }
        resumedAt = .now
        lastLocation = nil // avoid counting the GPS gap while paused as distance travelled
        state = .tracking
        locationManager.startUpdatingLocation()
        startTimer()
    }

    /// Stops tracking and returns a finished summary for the caller (HealthStore) to persist.
    /// Returns nil if the walk was too short to be worth saving.
    func end() -> FinishedWalk? {
        if state == .tracking, let resumedAt {
            pausedAccumulated += Date.now.timeIntervalSince(resumedAt)
        }
        locationManager.stopUpdatingLocation()
        timer?.invalidate()

        defer { state = .idle }

        guard let start = sessionStart, pausedAccumulated > 5 else { return nil }
        return FinishedWalk(
            start: start,
            end: start.addingTimeInterval(pausedAccumulated),
            distanceMeters: distanceMeters,
            route: route
        )
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let resumedAt = self.resumedAt else { return }
                self.elapsed = self.pausedAccumulated + Date.now.timeIntervalSince(resumedAt)
            }
        }
    }
}

/// Plain domain model handed to HealthStore — mirrors how DetectedActivitySession keeps
/// CoreMotion/CoreLocation types out of anything downstream.
struct FinishedWalk {
    let start: Date
    let end: Date
    let distanceMeters: Double
    let route: [CLLocationCoordinate2D]
}

extension WalkTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last, newLocation.horizontalAccuracy < 50 else { return }
        Task { @MainActor in
            if let last = self.lastLocation {
                self.distanceMeters += newLocation.distance(from: last)
            }
            self.lastLocation = newLocation
            self.route.append(newLocation.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationDenied = (status == .denied || status == .restricted)
        }
    }
}
