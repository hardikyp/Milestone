# Milestone Contributor Guardrails

This file is the implementation contract for future Codex and contributor work in this repository. Use it to match the existing app architecture, data flow, and UI system instead of inventing new abstractions.

## Project Overview

- Milestone is a single-target iOS SwiftUI app under `Milestone/`.
- The app is local-first. Persistent data is stored in SQLite through GRDB.
- The app boots from `MilestoneApp`, uses `AppContainer` for shared dependencies, and renders a tab-based shell from `ContentView`.
- Reusable visual primitives belong in `Milestone/UIAssets/`.
- This guide is intentionally prescriptive. If code and this file disagree, prefer the code and update this file.

## Architecture Map

### App Bootstrap

- `Milestone/MilestoneApp.swift`
  - Configures typography with `AppTypography.configure()`.
  - Initializes `DatabaseManager`.
  - Builds `AppContainer`.
  - Seeds bundled exercises through `ExerciseSeedService`.
  - Injects `AppContainer` via `environmentObject`.
  - Triggers automatic backup when the scene becomes active.

- `Milestone/AppContainer.swift`
  - Holds the shared `DatabaseManager`, `DatabaseQueue`, repositories, selected tab state, and history navigation state.
  - This is the shared dependency source for feature screens.

- `Milestone/ContentView.swift`
  - Hosts the bottom-tab shell.
  - Current top-level tabs are:
    - Dashboard
    - History
    - Exercises
    - Settings

### Feature Flow

- Top-level screens own their own local navigation and modal presentation state.
- The app does not use a central router or coordinator.
- Existing navigation patterns are local `NavigationStack`, `sheet`, `NavigationLink`, and `navigationDestination`.
- Detail flows are pushed or presented from feature screens, not centralized elsewhere.

### Current Feature Surface

- Dashboard
  - `Milestone/DashboardView.swift`
  - Uses `DashboardViewModel`.
  - Starts sessions directly or from templates.
  - Navigates to active session and session detail flows.

- History
  - `Milestone/HistoryView.swift`
  - Uses `HistoryViewModel`.
  - Lists sessions, supports end/delete actions, and navigates to session detail.

- Exercises
  - `Milestone/ExercisesView.swift`
  - Uses `ExercisesViewModel`.
  - Lists exercises, presents create flow, and navigates to exercise detail.

- Settings
  - `Milestone/SettingsView.swift`
  - Uses `SettingsViewModel`.
  - Owns preferences, data handling, profile editing, and UI assets catalog access.

- Session and exercise flows
  - `Milestone/ActiveSessionView.swift`
  - `Milestone/ExercisePickerView.swift`
  - `Milestone/ExerciseLoggingView.swift`
  - `Milestone/SessionDetailView.swift`
  - `Milestone/TemplatesView.swift`
  - `Milestone/TemplatePickerView.swift`
  - `Milestone/CreateExerciseView.swift`

## Dependency And Data Rules

### Source Of Truth

- Shared runtime dependencies come from `AppContainer`.
- Persistent storage goes through GRDB and the app database in `DatabaseManager`.
- Schema changes are declared in `Milestone/Migrations.swift`.
- Persisted entities live in `Milestone/Models.swift`.

### Repository Boundaries

- Repositories own write operations and CRUD-style persistence logic.
- Current repositories are:
  - `ExerciseRepository`
  - `SessionRepository`
  - `SessionExerciseRepository`
  - `SetRepository`
  - `TemplateRepository`

- Do not bypass repositories for writes.
- Do not add ad hoc write SQL to views.
- If a new persisted capability is introduced, prefer putting mutation logic in a repository or an existing service that already owns that area.

### View Model Read Rules

- Feature view models own screen state, async loading, and UI-facing transformations.
- Direct `dbQueue.read` queries inside view models are allowed only for screen-specific read models that match the current codebase pattern.
- Existing examples of view-model-level read composition:
  - `ActiveSessionViewModel`
  - `SessionDetailViewModel`
  - `SessionDetailEditViewModel`
  - `TemplateDetailViewModel`

- Do not use this exception as a reason to move writes out of repositories.

### Persistence Change Rules

When adding or changing persisted data, update all affected layers together:

1. Migration in `Milestone/Migrations.swift`
2. Model decode/encode in `Milestone/Models.swift`
3. Repository or service logic that reads/writes the data
4. Any formatting or unit-conversion logic used by the UI
5. Import/export or backup behavior if the dataset participates there

### Formatting And Preferences

- Use existing helpers for unit and value formatting:
  - `UnitDisplayFormatter`
  - `UnitConverter`
  - `AppUnitPreferences`
  - `AppAppearancePreferences`

- Do not duplicate weight, distance, duration, or volume formatting logic in new screens when an existing helper already covers it.

## UI System Rules

### UIAssets Is Mandatory For Reusable UI

- All reusable UI elements in this app belong in `Milestone/UIAssets/`.
- This is the design-system surface for Milestone.
- If a new button, card, input, row pattern, or token is meant to be reused, add it in `UIAssets` first.
- After adding it:
  1. Use the `UIAsset...` prefix.
  2. Add a visual example to `UIAssetsCatalogView`.
  3. Consume the primitive from feature screens.

- Do not create screen-local reusable controls when the change belongs in `UIAssets`.
- Do not create a second design system or alternate token layer.

### Reuse Existing Tokens First

Before introducing screen-local styling, check whether the current design system already supports the need.

Existing token and helper surface:

- Colors and surfaces
  - `UIAssetColors`
  - `UIAssetControlBorderColors`
  - `UIAssetShadows`

- Typography and sizing
  - `UIAssetTextStyle`
  - `UIAssetMetrics`
  - `AppTypography`

- Common view helpers
  - `uiAssetText(_:)`
  - `uiAssetCardSurface(fill:)`

Do not introduce new ad hoc colors, typography, spacing, corner radius, borders, or shadows without checking these first.

### Current Reusable UI Inventory

Current reusable UI primitives already available in `Milestone/UIAssets/UIAssetsCatalogView.swift`:

- Buttons and actions
  - `UIAssetButtonStyle`
  - `UIAssetFloatingActionButtonStyle`
  - `UIAssetDestructiveFloatingActionButtonStyle`
  - `UIAssetTextActionButtonStyle`
  - `UIAssetTiledButton`
  - `UIAssetRowSlideActionButton`

- Inputs and selectors
  - `UIAssetTextField`
  - `UIAssetSelectField`
  - `UIAssetSettingsInlineDropdown`
  - `UIAssetInlineDropdownHost`
  - `UIAssetSlidingToggle`
  - `UIAssetSettingsInlineToggle`

- Selection controls
  - `UIAssetRadioCard`
  - `UIAssetCheckboxCard`
  - `UIAssetTabFilter`

- Content and layout surfaces
  - `UIAssetBadge`
  - `UIAssetExerciseCard`
  - `UIAssetSettingsRow`
  - `UIAssetSettingsCategoryCard`
  - `UIAssetAlertDialog`

### Typography Rule

- Use `AppTypography` and `UIAssetTextStyle` for app-facing text.
- The app’s typography is based on the bundled Inter font.
- Do not introduce ad hoc font families or screen-specific font systems unless the repo evolves to support that explicitly.

## Screen Implementation Rules

### Ownership

- Top-level screens own:
  - navigation state
  - modal presentation state
  - local dialog state

- Screen view models own:
  - async loading
  - derived UI state
  - error/status state
  - screen-specific transformation logic

- Repositories and services own:
  - persistence mutations
  - transactional writes
  - data import/export/backup behavior

### New Screen Pattern

For a new feature screen or view:

1. Start with the nearest existing screen pattern.
2. Keep navigation local to the feature screen.
3. Use `@EnvironmentObject` `AppContainer` when shared dependencies are needed.
4. Add or extend a feature view model when async state or screen logic exists.
5. Use existing `UIAssets` tokens and primitives before inventing new UI.
6. Use existing formatters and preference helpers for displayed values.

### Previews

- Add a SwiftUI preview when practical and consistent with nearby code.
- For reusable UI in `UIAssets`, always add or update the catalog example.

## Do / Do Not Rules

### Do

- Do match the existing single-app-target structure.
- Do use `AppContainer` as the dependency source.
- Do use repositories for writes.
- Do match existing navigation patterns: local `NavigationStack`, `sheet`, `NavigationLink`, `navigationDestination`.
- Do add reusable UI to `UIAssets`.
- Do verify assumptions against the current code before implementing.

### Do Not

- Do not invent new modules, coordinators, routers, services, or design systems unless the repository already establishes them.
- Do not bypass repositories for writes.
- Do not assume placeholder settings or toggles are fully implemented features.
- Do not add screen-local reusable controls if they should live in `UIAssets`.
- Do not add schema changes without updating models and repository logic together.

## Known Non-Implemented Or Placeholder Areas

These areas are intentionally called out so future work does not assume they already exist:

- HealthKit toggle is only a local settings toggle today.
  - There is no real HealthKit authorization or sync flow yet.

- `defaultRestDurationSec` is persisted but currently unused.
  - It is stored in settings state but not applied in exercise/session flows.

- Body metrics schema exists without a product flow.
  - The `body_metrics` table and `BodyMetric` model exist, but there is no full feature path for create/edit/view.

- Session category tagging is not persisted structurally.
  - `SessionRepository.startSession(name:categoryTag:)` accepts `categoryTag`, but the current schema does not store it.

- Exercise reorder backend exists but is not wired to UI.
  - `SessionExerciseRepository.reorderSessionExercises(...)` exists, but there is no current UI flow using it.

- Reorder indexing convention is inconsistent.
  - Existing insertion flows are effectively 1-based, while the reorder path writes 0-based indices.

If future work closes one of these gaps, update both the code and this section.

## Contributor Workflow

### New Feature Checklist

- Identify which existing feature flow is closest and extend that pattern.
- Decide whether the feature is:
  - pure UI
  - UI plus view-model logic
  - persistence-affecting
  - import/export/backup-affecting

- Reuse `UIAssets` primitives before building anything new.
- Route all writes through repositories or the existing owning service.
- Check unit formatting, preferences, seeded-vs-user data behavior, and existing placeholder constraints.
- Update docs or audit notes if the feature changes a known gap.

### New View Checklist

- Identify the owning screen or feature flow.
- Reuse `UIAssets` tokens and primitives.
- Add or update a screen view model if the view has async or derived state.
- Keep navigation and sheet state local to the feature screen.
- Add a preview if practical.

### New Persistence Field Or Table Checklist

- Add the migration in `Migrations.swift`.
- Update the affected model encode/decode in `Models.swift`.
- Update the owning repository or service.
- Review formatting and unit conversion impact in the UI.
- Review import/export and backup impact.
- Avoid partial schema work that leaves model and repository code out of sync.

### New Reusable UI Primitive Checklist

- Add the token or component to `Milestone/UIAssets/`.
- Use the `UIAsset...` naming pattern.
- Add a catalog example to `UIAssetsCatalogView`.
- Replace duplicated styling in touched screens where appropriate.

### Settings Or Preferences Change Checklist

- Store and read through the existing preferences pattern.
- Reuse `AppUnitPreferences`, `AppAppearancePreferences`, `UserDefaults`, and related helpers where appropriate.
- Verify whether the setting is cosmetic only or must drive runtime behavior.
- Do not ship a setting that implies a complete integration if the underlying behavior does not exist.

### Import / Export / Backup Change Checklist

- Keep changes in the `DataTransferService` and `AutomaticBackupService` area unless the architecture changes deliberately.
- Verify export destination behavior, restore behavior, and backup behavior together.
- Check how the change affects app-local vs external export folders.
- Confirm whether new persisted data must be included in transfer flows.

## Verification Expectations

Before finishing a task in this repository:

- Verify every architectural claim against the current codebase.
- State assumptions explicitly instead of inventing missing systems.
- Confirm whether the task touches:
  - migrations
  - models
  - repositories
  - view models
  - `UIAssets`
  - settings/preferences
  - data transfer or backup

- If the requested change does not fit the current architecture, prefer the smallest change that matches existing patterns.
- If a larger architectural change is truly required, call that out explicitly rather than quietly introducing it.

## Fast Reference

- App bootstrap: `Milestone/MilestoneApp.swift`
- Shared dependency container: `Milestone/AppContainer.swift`
- App shell: `Milestone/ContentView.swift`
- Persistence setup: `Milestone/DatabaseManager.swift`
- Schema migrations: `Milestone/Migrations.swift`
- Persisted models: `Milestone/Models.swift`
- Reusable UI: `Milestone/UIAssets/`
- UI catalog: `Milestone/UIAssets/UIAssetsCatalogView.swift`
- Typography: `Milestone/AppTypography.swift`
- Formatting helpers: `Milestone/UnitDisplayFormatter.swift`
- Implementation audit: `TODO_IMPLEMENTATION_AUDIT.md`
