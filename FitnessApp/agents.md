# AI Agents & Responsibilities

This repository uses a team-of-agents approach. Each agent has clear responsibilities and must work incrementally. Do not generate large implementations in one step.

## Architect
- Defines architecture, dependency boundaries, project structure, and technical decisions.
- Ensures modularity, scalability, and testability.
- Produces plans before implementation.

## Swift Engineer
- Implements Swift, SwiftUI, and MVVM features following the architecture.
- Extracts reusable components; keeps Views thin and testable via ViewModels.

## HealthKit Engineer
- Manages HealthKit availability, permissions, queries, observers, synchronization, and privacy.
- Builds small, focused query components (StepCountQuery, ActiveEnergyQuery, WorkoutQuery, etc.).
- Provides DTOs and mapping to domain models.

## CloudKit Engineer
- Designs CloudKit schema, repositories, sync, conflict handling, offline support, and restoration.
- Ensures CloudKit logic is outside Views; uses repositories and services.

## UI/UX Engineer
- Designs screens, layout, design system, accessibility, animations, and visual consistency.
- Follows Apple’s Human Interface Guidelines.

## Watch Engineer
- Plans and implements Watch app and WatchConnectivity when needed.
- Keeps Watch-specific code isolated; avoids duplicating HealthKit unnecessarily.

## Music Engineer
- Implements MusicKit as an optional, non-blocking feature.
- Provides a `MusicService` abstraction; never couples music to workout logic directly.

## Performance Engineer
- Uses Instruments to measure memory, CPU, rendering, and query efficiency.
- Proposes targeted optimizations based on evidence.

## QA Engineer
- Writes unit, integration, and UI tests.
- Covers edge cases; builds mocks/fakes for HealthKit/CloudKit/MusicKit/WatchConnectivity.

## Security & Privacy Engineer
- Oversees permissions, entitlements, sensitive data handling, and logging policies.
- Ensures compliance with HealthKit/CloudKit privacy requirements.

## Reviewer
- Reviews architecture, code quality, duplication, naming, test coverage, performance, security, and accessibility before milestones are complete.

---

# Workflow

Phased development: Phase 0 → approval → Phase 1 → approval → Phase 2, etc.

For any request like “Implement Phase X”, agents should:

PLAN
- Identify files to create/modify, dependencies, architecture impact, and tests.

IMPLEMENT
- Deliver the smallest complete increment.

VERIFY
- Build, run tests, and static checks.

REVIEW
- Evaluate SOLID, performance, privacy, accessibility, and maintainability.

REPORT
- Summarize implemented scope, changed files, tests, known limitations, and next increment.

Do not proceed to the next major phase without explicit approval.

---

# Feature Flags

Use feature flags to keep features pluggable and independently removable, for example:
- healthKitEnabled
- cloudKitEnabled
- watchEnabled
- musicEnabled
- sleepEnabled
- heartRateEnabled

---

# Golden Rules (Abbreviated)
- Native Apple tech first; no custom backend.
- HealthKit is source of truth for health metrics; CloudKit is the cloud store for app-owned data.
- SwiftData is local/offline cache where available.
- UI never talks directly to HealthKit/CloudKit.
- One responsibility per service; testability is mandatory.
- Performance is measured; privacy and accessibility are non-negotiable.
- Prefer small, reversible changes.

This document is intended for both human contributors and AI assistants (Copilot, Claude, Codex, Gemini) to coordinate effectively.
