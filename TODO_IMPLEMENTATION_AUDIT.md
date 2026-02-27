# Workout Logger Implementation Audit

This document lists functionality that is currently incomplete or actions that are wired to placeholders/no-op behavior.

## 2) HealthKit toggle does not connect to HealthKit APIs

- **Type:** Action visually wired, integration missing
- **Evidence:**
  - UI presents **Connect HealthKit** toggle in `Milestone/SettingsView.swift:62-65`.
  - Toggle writes `isHealthConnected` in user defaults (`save()`), but no HealthKit authorization/read/write flow exists in `Milestone/SettingsView.swift:324-337`.
  - No HealthKit integration calls are present; only a local toggle state is stored.
- **Current behavior:** Toggle changes a local flag only; does not request permissions or sync data.
- **Detailed TODO:**
  - Add a HealthKit service layer (authorization status, request authorization, read/write permissions).
  - Update toggle flow to reflect real authorization state and surface denied/restricted states.
  - Decide sync scope (workouts only vs workouts + body metrics).
  - Add error handling for unavailable HealthKit environments.
  - Add tests (or integration mocks) for permission state transitions.

## 3) `defaultRestDurationSec` setting is persisted but unused

- **Type:** Partially implemented preference (storage only)
- **Evidence:**
  - `defaultRestDurationSec` is loaded/saved in `Milestone/SettingsView.swift:283,319,334,437`.
  - No UI control in settings currently edits this value.
  - No exercise/session logging flow reads this value.
- **Current behavior:** Value exists in persisted state, but has no effect.
- **Detailed TODO:**
  - Add a settings control to view/edit default rest duration.
  - Define where this value is applied (e.g., between sets in `ExerciseLoggingView` / active session timers).
  - Add runtime usage (timer defaults, per-exercise override strategy).
  - Validate allowed range and input format.
  - Add tests ensuring persisted value is consumed by logging/timer flow.

## 4) Body metrics schema/model exists but feature flow is missing

- **Type:** Data model implemented, feature not wired
- **Evidence:**
  - Migration creates `body_metrics` table in `Milestone/Migrations.swift:88-96`.
  - Model exists as `BodyMetric` in `Milestone/Models.swift:485-533`.
  - Current app usage found is only deletion during reset in `Milestone/SettingsView.swift:419`.
- **Current behavior:** No UI/service/repository path to create, edit, or view body metrics.
- **Detailed TODO:**
  - Add `BodyMetricRepository` (CRUD + time-series query).
  - Add UI to log body weight/body fat entries.
  - Add history/visualization (e.g., trend chart in dashboard or settings).
  - Connect any related profile fields to body metrics (if intended).
  - Add import/export coverage for this dataset.

## 5) Session category tagging is not implemented in persistence

- **Type:** API surface ahead of schema/logic
- **Evidence:**
  - `SessionRepository.startSession(name:categoryTag:)` accepts `categoryTag`, but explicitly discards it with comment in `Milestone/SessionRepository.swift:11-13`.
  - `sessions` table/model has no category column.
- **Current behavior:** Category is only reflected in session `name`; structured category data is lost.
- **Detailed TODO:**
  - Decide canonical modeling: add `category_tag` column vs infer from name.
  - If adding column: create migration + model updates + repository write/read updates.
  - Update category selection flow to persist a normalized enum/tag.
  - Backfill existing sessions where possible.
  - Use category data in filtering/analytics where appropriate.

## 6) Exercise reorder backend exists but no UI/action wiring uses it

- **Type:** Backend capability not connected to product flow
- **Evidence:**
  - `SessionExerciseRepository.reorderSessionExercises(...)` is implemented in `Milestone/SessionExerciseRepository.swift:34-68`.
  - No call sites in the app reference this method.
- **Current behavior:** Exercise order can only be append order; no reorder interaction is exposed.
- **Detailed TODO:**
  - Add reorder UI in active session exercise list.
  - Wire reorder commit to `reorderSessionExercises`.
  - Ensure post-reorder list refresh updates both active and detail screens.
  - Add tests for ordering persistence and invalid reorder payload handling.

## 7) Minor follow-up: `reorderSessionExercises` writes 0-based order index

- **Type:** Behavior mismatch/risk in an otherwise unwired path
- **Evidence:**
  - Loop writes `order_index = index` where `index` is 0-based in `Milestone/SessionExerciseRepository.swift:54-62`.
  - Other insertion paths use 1-based ordering (`offset + 1` / `count + 1`).
- **Current behavior:** If wired as-is, reorder may create mixed ordering conventions.
- **Detailed TODO:**
  - Confirm expected indexing convention (1-based appears to be current norm).
  - Change reorder write to `index + 1` if 1-based is intended.
  - Add regression tests for consistent ordering after create + reorder sequences.

---

## Quick Priority Suggestion

1. Implement data export/restore (`#1`) before broader sync/integration work.
2. Resolve settings dead paths (`#2`, `#3`) to avoid misleading UX.
3. Decide data-model direction for category/body metrics (`#4`, `#5`).
4. Wire reorder (`#6`) and fix indexing (`#7`) together.
