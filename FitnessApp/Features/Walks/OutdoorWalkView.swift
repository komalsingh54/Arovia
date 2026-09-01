//
//  OutdoorWalkView.swift
//  Arovia
//
//  Phase 1: foreground-only outdoor walk tracking (live map + distance/time/pace, saved to
//  Apple Health with a GPS route on completion). Background tracking + Live Activity are a
//  separate, later increment per agents.md's "smallest complete increment" rule.
//

import SwiftUI
import MapKit

struct OutdoorWalkView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @StateObject private var tracker = WalkTrackingService()
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    if tracker.route.count > 1 {
                        MapPolyline(coordinates: tracker.route)
                            .stroke(AppTheme.tint, lineWidth: 5)
                    }
                    UserAnnotation()
                }
                .mapControls { MapUserLocationButton() }
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 16) {
                    if tracker.authorizationDenied {
                        permissionWarning
                    }
                    if let saveError {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.energy)
                    }
                    statsRow
                    controls
                }
                .padding()
                .padding(.bottom, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding()
            }
            .navigationTitle("Outdoor Walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { tracker.requestPermission() }
        }
    }

    private var permissionWarning: some View {
        Label("Location access is needed to map your walk. Enable it in Settings.", systemImage: "location.slash")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.energy)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            StatColumn(title: "Distance", value: String(format: "%.2f km", tracker.distanceMeters / 1000))
            StatColumn(title: "Time", value: formattedElapsed)
            StatColumn(
                title: "Pace",
                value: tracker.paceMinutesPerKm > 0 ? String(format: "%.1f min/km", tracker.paceMinutesPerKm) : "–"
            )
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch tracker.state {
        case .idle where !isSaving:
            Button("Start Walk") { tracker.start() }
                .buttonStyle(.appPrimary)
        case .idle:
            ProgressView("Saving walk…")
        case .tracking:
            HStack(spacing: 12) {
                Button("Pause") { tracker.pause() }
                    .buttonStyle(.appSecondary)
                Button("End Walk", action: endWalk)
                    .buttonStyle(.appPrimary)
            }
        case .paused:
            HStack(spacing: 12) {
                Button("Resume") { tracker.resume() }
                    .buttonStyle(.appPrimary)
                Button("End Walk", action: endWalk)
                    .buttonStyle(.appSecondary)
            }
        }
    }

    private func endWalk() {
        guard let walk = tracker.end() else {
            dismiss()
            return
        }
        isSaving = true
        Task {
            do {
                try await healthStore.saveOutdoorWalk(walk)
                dismiss()
            } catch {
                saveError = "Couldn't save to Apple Health: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private var formattedElapsed: String {
        let minutes = Int(tracker.elapsed) / 60
        let seconds = Int(tracker.elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct StatColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OutdoorWalkView()
        .environmentObject(HealthStore())
}
