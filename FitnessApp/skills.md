# AI Skills (Consolidated)

This file provides reusable skills/guardrails for AI agents (Copilot, Claude, Codex, Gemini, etc.) working on this repository. Use these skills to keep changes modular, testable, and aligned with the architecture.

## ios-architecture
- Use feature-oriented MVVM.
- Enforce separation of concerns and single responsibility.
- Depend on protocols; inject dependencies via `AppDependencies`.
- Keep files small and focused; avoid god objects.
- Domain models are independent of Apple frameworks.

## swiftui-development
- SwiftUI Views are declarative and lightweight.
- No business logic in Views; use ViewModels.
- Prefer `@MainActor` for UI state only; keep heavy work off main thread.
- Use `#Preview` for previews.
- Extract reusable components early (MetricCard, ProgressRing, etc.).

## healthkit-development
- HealthKit is the source of truth for health data.
- Request permissions only when needed; explain clearly; handle denial/restriction.
- Use dedicated query components: StepCountQuery, ActiveEnergyQuery, WorkoutQuery, etc.
- Use observer/anchored queries where appropriate; avoid duplicate queries.
- Never crash if data is missing; handle partial permissions.

## cloudkit-development
- Use the private database; design minimal record types (Goals, Logs, DailySummary, Settings, WorkoutNote).
- Use a custom zone; stable identifiers and `updatedAt` timestamps.
- Handle offline, retries, conflicts; last-writer-wins with app-level merge rules when needed.
- Keep CloudKit logic out of Views; use repositories.

## apple-watch-development
- Keep watch-specific code isolated in Watch/.
- Use WatchConnectivity only when needed; avoid duplicating HealthKit data.
- Start with iPhone app stable; add Watch later.

## musickit-development
- Music is optional; never block health features.
- Use a `MusicService` protocol with graceful degradation when unauthorized/unavailable.

## ios-ui-design
- Follow HIG: clean, modern, minimal, accessible, information-dense.
- Use native components, SF Symbols, system materials.
- Support Dynamic Type, Dark Mode, reduced motion.
- Avoid excessive gradients/shadows/borders.

## ios-performance
- Use async/await and Actors for concurrency.
- Avoid main-thread heavy work; minimize SwiftUI recomputation.
- Cache expensive computations; paginate historical queries.
- Measure using Instruments; don’t optimize blindly.

## ios-testing
- Every significant business rule must be testable.
- Unit tests for calculations, summaries, repositories, errors, sync logic.
- Use mocks/fakes for HealthKit, CloudKit, MusicKit.
- Integration tests for critical workflows; UI tests for dashboard/navigation/refresh.

## ios-security-privacy
- Request minimal permissions; store minimal necessary data.
- Never log sensitive health data; use appropriate log levels.
- Use CloudKit private database; follow HealthKit privacy requirements.

## code-review
- Check: architecture boundaries, naming, duplication, test coverage, performance, privacy, accessibility.
- Avoid unrelated refactors during feature work.
- Prefer small, reversible changes; maintain high signal-to-noise in diffs.

---

Usage: When implementing a change, state which skills you are applying and follow the Phase process (PLAN → IMPLEMENT → VERIFY → REVIEW → REPORT).
