# Milestone TODO

This file combines the implementation-gap audit with a performance plan for the current app.

## Task ID Scheme

- Performance work uses `P#-A#`.
  - Example: `P1-A1`
- Feature-gap work uses `F#-A#`.
  - Example: `F2-A1`

## Log Update Rule

For every task below, append new bullets under `Performance Log` when work is done.

Use this format:
- `YYYY-MM-DD — Agent/owner — Status`
  - What changed
  - What was measured
  - What regressed or still needs follow-up

Initial status legend:
- `Not started`
- `In progress`
- `Blocked`
- `Done`

## Guardrails

- Preserve the existing single-target SwiftUI structure.
- Keep `AppContainer` as the dependency source.
- Keep writes inside repositories and existing data-transfer services.
- Do not break implemented features or the unimplemented feature paths called out in `AGENTS.md`.
- Prioritize fixes that improve perceived smoothness first: tab switches, navigation transitions, swipe interactions, scroll performance, and data-entry responsiveness.

## Highest-Probability Root Causes

1. Main-thread database work from `@MainActor` view models and UI actions.
2. Tab switches recreate whole top-level screens.
3. N+1 query patterns for totals and derived row state.
4. Heavy row composition in scrolling screens: repeated swipe rows, `GeometryReader`, shadows, extra surface layers.
5. Input-time fan-out updates in exercise logging.
6. Broad observable-object invalidation in settings and other large screens.
7. Custom calendar transitions doing more work than necessary during interaction.
8. Indexing is decent, but not tuned for every hot path.

## Performance Tasks

### P0. Measurement Baseline

#### P0-A1. Create the profiling checklist and repeatable benchmark pass

Scope:
- Time Profiler on launch, tab switch, open session, open history, swipe rows, open exercise logger, finish session.
- Core Animation / SwiftUI Instruments for FPS drops, hitches, body recomputation, and offscreen rendering.
- SQLite query timing for dashboard, history, active session, and session detail loads.
- Memory allocation check for repeated tab switching and exercise-detail GIF loading.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Task created from repository scan.
  - No benchmarks recorded yet.

#### P0-A2. Record baseline metrics for the current app

Scope:
- Capture average tab-switch duration.
- Capture dashboard first-render time.
- Capture history initial-load and load-more latency.
- Capture session-detail open time.
- Capture active-session add/remove exercise latency.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Baseline metric slots defined.
  - No measurements recorded yet.

#### P0-A3. Define pass/fail acceptance criteria for the performance pass

Scope:
- No obvious hitch on tab change or sheet presentation.
- No visible main-thread stall during swipe gestures.
- No keyboard/input lag in exercise logging with larger set counts.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Acceptance targets documented conceptually.
  - Numeric thresholds still need to be chosen after baseline capture.

### P1. Move Database Work Off The Main Actor

#### P1-A1. Move dashboard loading off the main actor and batch its state publication

References:
- [DashboardViewModel.swift](/Users/hardik/Repositories/workout-logger/Milestone/DashboardViewModel.swift#L24)

Scope:
- Stop doing synchronous repository and stats reads directly inside the `@MainActor` load path.
- Publish one coherent post-load state update instead of several separate UI mutations where possible.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found synchronous read work on the main actor.
  - No mitigation implemented yet.

#### P1-A2. Move history initial load and pagination off the main actor

References:
- [HistoryView.swift](/Users/hardik/Repositories/workout-logger/Milestone/HistoryView.swift#L447)

Scope:
- Move initial page fetch and load-more work off the main actor.
- Keep existing pagination behavior and row ordering.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found synchronous fetch and per-row total work on the main actor.
  - No mitigation implemented yet.

#### P1-A3. Move active-session and session-detail loading off the main actor

References:
- [ActiveSessionView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ActiveSessionView.swift#L243)
- [SessionDetailView.swift](/Users/hardik/Repositories/workout-logger/Milestone/SessionDetailView.swift#L445)

Scope:
- Remove direct heavy `dbQueue.read` work from the main actor for these detail screens.
- Keep the current read-model composition pattern, but run the work away from animation and gesture handling.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found direct synchronous DB reads in both view models.
  - No mitigation implemented yet.

#### P1-A4. Move secondary list and picker loads off the main actor and codify the pattern

References:
- [ExercisesView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ExercisesView.swift#L333)
- [ExercisePickerView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ExercisePickerView.swift#L210)
- [TemplatePickerView.swift](/Users/hardik/Repositories/workout-logger/Milestone/TemplatePickerView.swift#L215)
- [TemplatesView.swift](/Users/hardik/Repositories/workout-logger/Milestone/TemplatesView.swift#L106)

Scope:
- Apply the same async-load pattern to exercise, template, and picker flows.
- Leave repository ownership and existing screen boundaries intact.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found repeated synchronous list-loading paths on the main actor.
  - No mitigation implemented yet.

### P2. Keep Top-Level Tabs Alive

#### P2-A1. Replace the switch-driven tab host with a persistent screen host

References:
- [ContentView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ContentView.swift#L20)

Scope:
- Stop recreating `DashboardView`, `HistoryView`, `ExercisesView`, and `SettingsView` on every tab change.
- Preserve the current bottom menu UI.
- Preserve local `NavigationStack` ownership and existing `AppContainer.selectedTab` behavior.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found top-level screen recreation on each tab switch.
  - No mitigation implemented yet.

### P3. Remove N+1 Queries And Duplicate Fetch Work

#### P3-A1. Replace dashboard per-session volume lookups with one aggregated read

References:
- [DashboardViewModel.swift](/Users/hardik/Repositories/workout-logger/Milestone/DashboardViewModel.swift#L37)

Scope:
- Replace the per-session `StatsService.totalVolumeKg(sessionId:)` loop with one query for the last 7 days.
- Keep the existing chart output and unit handling.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found an N+1 volume aggregation pattern on dashboard load.
  - No mitigation implemented yet.

#### P3-A2. Replace history per-row volume lookups with a page-level read model query

References:
- [HistoryView.swift](/Users/hardik/Repositories/workout-logger/Milestone/HistoryView.swift#L456)

Scope:
- Load session rows, duration, and total volume in one page-level query.
- Preserve pagination and in-progress session handling.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found N+1 totals per visible page.
  - No mitigation implemented yet.

#### P3-A3. Merge session-detail detail load and total-volume load

References:
- [SessionDetailView.swift](/Users/hardik/Repositories/workout-logger/Milestone/SessionDetailView.swift#L453)
- [SessionDetailView.swift](/Users/hardik/Repositories/workout-logger/Milestone/SessionDetailView.swift#L534)

Scope:
- Remove the separate total-volume fetch if one joined/batched read can provide the same result.
- Preserve current summary formatting and section ordering.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found duplicate session-detail query work.
  - No mitigation implemented yet.

#### P3-A4. Add a targeted next-order helper for session-exercise insertion

References:
- [ExercisePickerView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ExercisePickerView.swift#L239)
- [ExercisePickerView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ExercisePickerView.swift#L272)

Scope:
- Stop fetching all session exercises solely to compute the next `orderIndex`.
- Add a narrow repository/helper path instead.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found unnecessary full fetches for append-order calculation.
  - No mitigation implemented yet.

### P4. Reduce Render Cost In Scrollable Screens

#### P4-A1. Build one reusable `UIAsset` swipe-row primitive and migrate duplicated implementations

References:
- [HistoryView.swift](/Users/hardik/Repositories/workout-logger/Milestone/HistoryView.swift#L266)
- [ExercisesView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ExercisesView.swift#L195)
- [ActiveSessionView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ActiveSessionView.swift#L323)
- [TemplatePickerView.swift](/Users/hardik/Repositories/workout-logger/Milestone/TemplatePickerView.swift#L233)

Scope:
- Move the reusable swipe-row behavior into `Milestone/UIAssets/`.
- Keep the current visual design and gesture semantics.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found four separate swipe-row implementations with similar cost profile.
  - No mitigation implemented yet.

#### P4-A2. Remove per-row `GeometryReader` measurement where row height is effectively fixed

References:
- [ExercisesView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ExercisesView.swift#L255)
- [ActiveSessionView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ActiveSessionView.swift#L381)
- [TemplatePickerView.swift](/Users/hardik/Repositories/workout-logger/Milestone/TemplatePickerView.swift#L284)
- [HistoryView.swift](/Users/hardik/Repositories/workout-logger/Milestone/HistoryView.swift#L340)

Scope:
- Remove row-by-row geometry observation where the design system already constrains the row.
- If measurement must remain, replace with a lighter one-pass preference-based approach.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found repeated per-row geometry tracking in list-like screens.
  - No mitigation implemented yet.

#### P4-A3. Simplify reusable surface layers, shadows, and zero-width strokes

References:
- [UIAssetsCatalogView.swift](/Users/hardik/Repositories/workout-logger/Milestone/UIAssets/UIAssetsCatalogView.swift#L305)
- [UIAssetsCatalogView.swift](/Users/hardik/Repositories/workout-logger/Milestone/UIAssets/UIAssetsCatalogView.swift#L315)

Scope:
- Collapse duplicated exercise-card background layers.
- Remove `stroke(..., lineWidth: 0)` throughout reusable assets and touched screens.
- Audit broad shadow usage in list cells and buttons.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found duplicate rounded-rectangle layers and many unnecessary zero-width strokes.
  - No mitigation implemented yet.

#### P4-A4. Rebalance shadows in dense scrolling contexts without changing the design language

Scope:
- Keep hero cards and dialogs visually rich.
- Reduce offscreen-render pressure in long scrolling lists if profiling confirms it.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit flagged heavy shadow use as a likely contributing factor.
  - Profiling confirmation still needed.

### P5. Reduce Input-Time State Churn

#### P5-A1. Rework “same reps/weight for all” so it does not mutate many rows on every keystroke

References:
- [ExerciseLoggingView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ExerciseLoggingView.swift#L664)

Scope:
- Replace per-character O(n) propagation with a cheaper model.
- Preserve current UX intent.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found multi-row mutation on each text change.
  - No mitigation implemented yet.

#### P5-A2. Remove `GeometryReader` from the distance-time input row if a static layout can work

References:
- [ExerciseLoggingView.swift](/Users/hardik/Repositories/workout-logger/Milestone/ExerciseLoggingView.swift#L456)

Scope:
- Replace geometry-driven layout with a fixed or simpler adaptive layout if it preserves the current UI.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found geometry work inside a repeated input row.
  - No mitigation implemented yet.

#### P5-A3. Reduce settings-screen invalidation and immediate-save churn

References:
- [SettingsView.swift](/Users/hardik/Repositories/workout-logger/Milestone/SettingsView.swift#L95)
- [SettingsView.swift](/Users/hardik/Repositories/workout-logger/Milestone/SettingsView.swift#L365)

Scope:
- Keep settings behavior intact.
- Reduce unnecessary broad invalidation and repeated save calls where profiling shows value.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found a large `ObservableObject` and immediate save-on-change behavior.
  - No mitigation implemented yet.

### P6. Make Screen Refreshes More Intentional

#### P6-A1. Audit all `.task` and refresh-trigger paths and classify them

Scope:
- Distinguish one-time initial load vs mutation refresh vs identity-change refresh.
- Document which ones should remain and which should be removed.

Performance Log:
- 2026-03-25 — Audit — Not started
  - The audit identified many `.task` and `.onChange` refresh paths.
  - No classification pass recorded yet.

#### P6-A2. Remove unnecessary whole-screen reload triggers and prefer local mutation

References:
- [DashboardView.swift](/Users/hardik/Repositories/workout-logger/Milestone/DashboardView.swift#L186)

Scope:
- Remove refreshes that are not actually tied to data changes.
- Prefer targeted mutation for add/delete/end flows where safe.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found several broad reloads that may be avoidable.
  - No mitigation implemented yet.

### P7. Query Plan And Index Follow-Up

#### P7-A1. Run `EXPLAIN QUERY PLAN` on hot reads after earlier fixes land

Scope:
- Validate whether remaining bottlenecks are SQL/index related after main-thread and N+1 fixes.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Existing indexes were reviewed at a high level.
  - Query-plan validation still needs to happen after the bigger wins.

#### P7-A2. Add measured indexes only for validated hotspots

References:
- [Migrations.swift](/Users/hardik/Repositories/workout-logger/Milestone/Migrations.swift#L98)

Scope:
- Consider active-session lookup indexing.
- Consider template sort indexing.
- Consider exercise list/search indexing only if profiling proves it matters.

Performance Log:
- 2026-03-25 — Audit — Not started
  - No new indexes proposed yet.
  - This remains intentionally deferred until measured evidence exists.

### P8. Animation And Transition Polish

#### P8-A1. Make monthly calendar transitions state-driven instead of timer-driven

References:
- [MonthlyCalendarView.swift](/Users/hardik/Repositories/workout-logger/Milestone/MonthlyCalendarView.swift#L260)

Scope:
- Remove `DispatchQueue.main.asyncAfter` handoff if possible.
- Keep the current visual interaction unless profiling proves the approach is too expensive.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found timer-based completion logic in the swipe transition.
  - No mitigation implemented yet.

#### P8-A2. Audit overlay and press-animation cost in dense interaction flows

Scope:
- Review dialogs, dimming overlays, and button press animations in long lists and sheets.
- Reduce over-animation only where measurements justify it.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit flagged these as secondary polish candidates.
  - No mitigation implemented yet.

### P9. Media And Detail-Screen Follow-Up

#### P9-A1. Measure `WKWebView` GIF rendering cost in exercise detail

Scope:
- Measure open-time, memory, and scrolling impact before changing the implementation.
- Only replace it if the current path is materially harming UX.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit noted the `WKWebView` path as a potential secondary cost center.
  - No measurements recorded yet.

## Feature-Gap Tasks

### F1. HealthKit

#### F1-A1. Replace the placeholder HealthKit toggle with a real integration path

Scope:
- Add HealthKit authorization and sync-status handling.
- Reflect denied, restricted, and unavailable states in settings.
- Decide sync scope before implementation.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Existing toggle is only a local flag.
  - No integration work done yet.

### F2. Default Rest Duration

#### F2-A1. Add a settings control for `defaultRestDurationSec`

Scope:
- Surface the persisted value in settings.
- Validate range and input format.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Setting exists in storage but lacks a real control.
  - No implementation work done yet.

#### F2-A2. Apply `defaultRestDurationSec` in exercise/session logging flows

Scope:
- Define where the value should be consumed.
- Decide override behavior and validation rules.
- Add tests covering persistence-to-runtime usage.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Stored value is currently unused at runtime.
  - No implementation work done yet.

### F3. Body Metrics

#### F3-A1. Add `BodyMetricRepository` and persistence-facing read/write paths

Scope:
- Add CRUD and likely time-series query support.
- Keep backup/export/restore behavior aligned with the schema.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Table and model exist without repository support.
  - No implementation work done yet.

#### F3-A2. Build the body-metrics feature flow

Scope:
- Add create/edit/view UI.
- Add trend/history presentation.
- Confirm data-transfer coverage.

Performance Log:
- 2026-03-25 — Audit — Not started
  - No product flow exists yet for body metrics.
  - No implementation work done yet.

### F4. Session Category Tagging

#### F4-A1. Decide and implement structural persistence for session category tagging

References:
- [SessionRepository.swift](/Users/hardik/Repositories/workout-logger/Milestone/SessionRepository.swift#L11)

Scope:
- Decide whether to add a `category_tag` column.
- Update migration, model, repository, and consumers together.
- Backfill where sensible if a new column is added.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Repository API already accepts a category tag, but the schema does not store it.
  - No implementation work done yet.

### F5. Session Exercise Reorder

#### F5-A1. Wire the existing reorder backend to an active-session UI flow

Scope:
- Add reorder UI in active session flows.
- Keep active and detail screens in sync after reorder.
- Add tests for reorder persistence.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Reorder repository support exists but has no UI integration.
  - No implementation work done yet.

#### F5-A2. Standardize reorder index semantics before shipping reorder

Scope:
- Resolve the 0-based vs 1-based mismatch.
- Add regression tests for create + reorder sequences.

Performance Log:
- 2026-03-25 — Audit — Not started
  - Audit found indexing inconsistency in the unwired reorder path.
  - No implementation work done yet.

## Recommended Execution Order

1. `P0-A1`
2. `P0-A2`
3. `P0-A3`
4. `P1-A1`
5. `P1-A2`
6. `P1-A3`
7. `P2-A1`
8. `P3-A1`
9. `P3-A2`
10. `P3-A3`
11. `P4-A1`
12. `P4-A2`
13. `P4-A3`
14. `P5-A1`
15. `P5-A2`
16. `P6-A1`
17. `P6-A2`
18. `P8-A1`
19. `P7-A1`
20. `P7-A2`
21. `P9-A1`
22. Resume feature-gap work, starting with `F2-A1`, `F2-A2`, and `F1-A1`

## Completion Criteria For The Performance Pass

- Tab switches feel immediate and preserve context.
- History, exercises, template picker, and active session rows scroll and swipe without visible hitching.
- Opening dashboard, active session, and session detail does not visibly stall navigation.
- Exercise logging remains responsive during typing and row edits.
- No repository-boundary violations, no broken transfer flows, and no regressions against placeholder future features called out in `AGENTS.md`.
