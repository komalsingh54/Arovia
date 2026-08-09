# Personal Health & Fitness iOS App

A production-quality, modular iOS app for a single user’s health and fitness, built on Apple’s native ecosystem: Swift, SwiftUI, HealthKit, CloudKit, and SwiftData (where deployment allows). The project prioritizes privacy, performance, accessibility, and maintainability.

## Objective
- Personal dashboard with steps, active energy, workout minutes/count, and goal progress
- HealthKit as source of truth for health data
- CloudKit for app-owned personal data (logs, goals, preferences, summaries)
- SwiftData (iOS 17+) as local cache/offline store when available
- Optional integrations: Apple Watch, MusicKit, Widgets, Live Activities
- iOS-first, no third-party backends

## Tech Stack
- Swift, SwiftUI, Swift Concurrency
- HealthKit, CloudKit, SwiftData (iOS 17+), WatchConnectivity (optional), MusicKit (optional)
- WidgetKit, ActivityKit (as needed)
- Testing: Swift Testing / XCTest
- Minimum target: iOS 16+ (prefer newer APIs when available)

## Architecture
- Feature-oriented MVVM with strict separation of concerns
- Dependency Injection via an `AppDependencies` container and protocol-first design
- Repositories mediate between domain and services (Apple frameworks)
- Domain models separate from framework models (no HK/CK types in UI)
- Concurrency with async/await, use Actors where appropriate
- Logging abstraction backed by Apple’s Logger; explicit error types

### High-Level Layers
- UI (SwiftUI Views)
- ViewModels (MVVM)
- Repositories (domain-facing)
- Services (framework adapters: HealthKit, CloudKit, MusicKit)
- Models (Domain + DTOs + Persistence)
- Core (Architecture, Logging, Errors, Utilities, Design System)
- App (Entry, Dependencies, Environment)

## Project Structure
- App/
  - AppEntry/
  - AppEnvironment/
  - AppDependencies/
- Core/
  - Architecture/
  - Errors/
  - Logging/
  - Utilities/
  - Extensions/
  - Constants/
  - DesignSystem/
- Features/
  - Dashboard/ Activity/ Workouts/ Goals/ Logs/ History/ Profile/ Settings/ Music/ Watch/
- Health/
  - HealthKitService/ HealthQueries/ HealthModels/ HealthAuthorization/
- Persistence/
  - CloudKit/ SwiftData/ Repositories/ PersistenceModels/
- Watch/
  - WatchApp/ WatchConnectivity/ WatchModels/
- Music/
  - MusicKitService/ MusicModels/
- UI/
  - Components/ Charts/ Cards/ Navigation/
- Tests/
  - Unit/ Integration/ UI/
- Docs/
  - README.md, ARCHITECTURE.md, DATA_MODEL.md, HEALTHKIT.md, CLOUDKIT.md, WATCH.md, MUSIC.md, TESTING.md, DECISIONS.md
- skills/
  - See `skiks.md` for consolidated skills (or split files if desired)

Note: This structure is a guide. Keep files small and focused; extract reusable components early.

## Development Phases
1. Phase 0 — Architecture: structure, dependencies, logging, errors, DI, docs
2. Phase 1 — App Shell: entry, navigation, theme, reusable components, empty/loading/error states
3. Phase 2 — HealthKit: availability, permissions, step/energy/workout queries, domain models, repository, mocks
4. Phase 3 — Dashboard: connect real data, refresh, loading/empty/error UX
5. Phase 4 — CloudKit: container, records, repositories, sync, offline, restore
6. Phase 5 — Personal Logs: CRUD for notes/measurements/custom activity
7. Phase 6 — History & Analytics: summaries, trends, charts
8. Phase 7 — Apple Watch (optional)
9. Phase 8 — Music (optional)
10. Phase 9 — Performance (Instruments-driven)
11. Phase 10 — Final Quality (accessibility, privacy, offline/restore)

## Golden Rules
1. Native Apple technologies first; no backend.
2. HealthKit is the health-data source; CloudKit is the app cloud store.
3. SwiftData is local/offline cache where available.
4. UI never talks directly to HealthKit/CloudKit.
5. Features must be modular; one responsibility per service.
6. Testability is required; use protocols and mocks.
7. Measure performance; don’t optimize blindly.
8. Privacy and accessibility are mandatory.
9. Prefer small, reversible changes and incremental phases.

## Command Format for AI Agents
When prompted with: "Implement Phase X"

PLAN
- Files to create/modify
- Dependencies and architecture impact
- Tests to add

IMPLEMENT
- Smallest complete increment only

VERIFY
- Build, run tests, static checks

REVIEW
- SOLID, performance, privacy, accessibility, maintainability

REPORT
- Implemented scope, changed files, tests, known limitations, next increment

Do not proceed to the next major phase without approval.

## HealthKit & CloudKit Scope
- HealthKit: steps, active energy, workouts, exercise time, distance, heart rate (optional), sleep (optional)
- CloudKit: goals, logs, settings, app-specific daily summaries, workout notes (not raw HealthKit samples)
- Incremental sync; handle denied/restricted permissions gracefully; never crash due to missing data

## Local Storage Strategy
- SwiftData (iOS 17+) for caching/offline when available
- If targeting iOS 16+, use a LocalStore protocol with a simple fallback; enable SwiftData conditionally

## Accessibility & Privacy
- Dynamic Type, VoiceOver, contrast, labels/values/actions, reduced motion
- Request minimum permissions; store minimum necessary data; never log sensitive health data

## Getting Started
- Xcode 15+ (prefer latest)
- iOS 16+ deployment (consider iOS 17+ to use SwiftData)
- Enable required capabilities per phase (HealthKit/CloudKit later)
- Run on a physical device to validate HealthKit

## Testing
- Use Swift Testing/XCTest
- Unit tests for calculations, summaries, repositories, error handling, sync logic
- Integration tests for critical workflows
- UI tests for dashboard, navigation, refresh, empty/error states

## Documentation
- See Docs/ for architecture, data models, platform specifics, and decisions
- See `agents.md` for roles and responsibilities
- See `skiks.md` for consolidated AI skills and guardrails

---

This README is designed for both human developers and AI coding agents (Copilot, Claude, Codex, Gemini) to understand the project’s goals, constraints, and workflow.
