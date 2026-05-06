# Race Fueling Calculator — Project Context

> Global development rules live in `~/.claude/CLAUDE.md` and are loaded automatically. This file only covers project-specific context.

## Architecture

Dart 3.x workspace with three packages:

- `packages/core` — pure Dart domain logic (models, plan engine, storage interface). Zero I/O dependencies. Consumed by both the CLI and the Flutter app via `package:race_fueling_core/core.dart`.
- `packages/cli` — CLI interface using `args`. Depends on `core`. Provides `FileStorageAdapter` and terminal formatting.
- `packages/app` — Flutter app (Bonk Race Fueling Planner UI). Depends on `core`. Light-only Material 3 theme; Riverpod 3.x for state; `shared_preferences` for the working plan; web is the v1.1 target. Layered as `lib/{domain,data,presentation}/`.

The engine is composed of pure functions: `generatePlan()` computes environmental adjustments first, then runs timeline building → carb distribution (rate scaled by altitude) → product allocation → per-entry water adjustment → validation (including aid-station definition checks). No state, trivially testable.

The allocator (`packages/core/lib/src/engine/product_allocator.dart`) is the heart of the engine. As of v1.1 it implements:

- **Drinks as sip background.** Each liquid product with `Product.sipMinutes` is consumed across `sipMinutes / stepMin` slots, contributing `carbsPerServing / drinkSteps` per slot.
- **65% drink cap.** Per-slot drink contribution is capped at `0.65 × target` so gels stay in the rotation.
- **Gel-debt accumulator.** Unmet target accumulates across slots; gels fire when the pool justifies a well-fitting one (threshold + oversize cutoff).
- **Aid-station refill.** Stations refill inventory at the slot whose `timeMark` matches the projected minute (`projectAidStationMin`). `AidStation.refill` is a list of product IDs.

The constants (`_drinkCapFraction`, `_gelDebtFireThreshold`, `_gelOversizeFactor`, `_gelOversizeCushion`, `_drinkStartGramsPerHr`, `_gelDebtFloorFactor`, `_slotOverageAdvisoryThreshold`, `_maxGelPicksPerSlot`) live at the top of the file with one-paragraph docstrings each.

## Progress & Source of Truth

- `JOURNAL.md` — phase-by-phase progress log. Read at session start. Also contains a "Known Issues" catalogue from earlier reviews (some superseded by v1.1; KI-64 is now obsolete).
- `docs/superpowers/plans/2026-04-30-v1.1-flutter-app.md` — current implementation plan (Phases A–F).
- `docs/superpowers/plans/v1.md` — original v1.0 plan (Phases 0–8 complete).
- `docs/superpowers/specs/2026-04-02-race-fueling-calculator-design.md` — original engine spec.
- `docs/superpowers/specs/2026-04-30-flutter-app-design.md` — Flutter app spec for Phases B–F.

**v1.0 (Phases 0–8): complete.** Tagged `v1.0.0`.

**v1.1 Phase A (engine port): complete.** Tagged `v1.1.0-rc.1` on commit `76b3928` of branch `feat/v1.1-phase-a-engine`. Drink-as-sip + 65% cap + gel-debt allocator, `Product.sipMinutes`, `RaceConfig.discipline`, `AidStation.refill`, schema v2 with migration, aid-station validator, CLI sip/aid markers.

**v1.1 Phase B (Flutter scaffolding): complete** on branch `feat/v1.1-phase-b-scaffolding`. `packages/app` 0.1.0 with workspace pubspec, domain re-exports, `BonkTokens` design tokens (24 colors / 3 radii / 10 spacing + `topbarHeight` alias), `BonkType` typography (Inter Tight + JetBrains Mono via google_fonts), `BonkBreakpoint` 5-tier responsive enum, `PlanStorageLocal` (shared_preferences-backed `PlannerState` blob), 5 Riverpod providers (storage / library / planner notifier / plan / warnings), `BonkApp` MaterialApp bootstrap with full M3 theme override, stub `PlannerPage`. Web platform configured. Browser smoke test verified.

**v1.1 Phase C (Setup rail): complete** on branch `feat/v1.1-phase-c-setup-rail`. The left-pane `SetupRail` panel and its 4 reusable widgets shipped: `BonkSegControl<T extends Object>` (keyboard-focusable pill picker with `Semantics(button, selected, inMutuallyExclusiveGroup)` per option), `BonkStepper` (28×28 visual + 44×44 hit area + adjustable Semantics + disabled visual + optional `keyPrefix` for tests), `BonkFieldShell` (label+child column wrapped in `Semantics(container, label)`), and `BonkTextInput` (cursor-preserving controller, `inputFormatters`, `labelText` for accessible name, ink-color borders). The rail composes them into 5 sections: race (name/duration/body-mass/distance/discipline), carb-strategy (target slider + gut-trained slider + distribution seg control), inventory (one `InventoryRow` per built-in product with `BonkStepper`), aid stations (one `AidStationRow` per station with time/distance toggle + refill chips + remove). All inputs route through `PlannerNotifier`. The rail is **not yet wired into `PlannerPage`** — F1 (Phase F assembly) does the three-pane layout. 135 widget/unit tests in `packages/app`.

**v1.1 PB-DATA-1 (data-layer hardening) + Phase D (plan canvas): complete** on branch `feat/v1.1-phase-d-plan-canvas`. PB-DATA-1: `planProvider` returns `AsyncValue<FuelingPlan>` via `unwrapPrevious().whenData(...)` (PB-ARCH-10 superseded), typed `PlanStorageException` with `cause`/`causeStack`/`rawBytes` distinguishes empty drive from corrupt blob, `PlannerNotifier` refuses save while `AsyncError` (with `discardCorruptedAndUseSeed` and `retryLoad` recovery hooks), `PlanStorageLocal` auto-backs up corrupted bytes to `${_key}.bak` once before destructive overwrite, `SaveStatus` provider (Idle/InFlight/Failed with sticky-Failed-until-next-success policy + in-flight counter for queued-saves correctness), `isSeedFallback` field on `PlannerState` is persisted and auto-flips to false on first user mutation. Phase D: `StatCard` (label + value + unit + sub + hero variant + `StatSeverity` glyph affordance + Semantics composed label), `TimelineRow` (clock + dual-bar + items + cumulative + row-level Semantics; AID STATION row uses ink text + warn left-bar per color doctrine; consumes structural `ProductServing.isDrinkStart` marker, no string match), `PlanCanvas` (race-name `Semantics(header)` + `maxLines: 2` cap + 6-card stat grid + vertical timeline; static error fallback via `_ErrorFallback`; loading indicator with `Semantics(liveRegion)`). Engine added `PlanSummary.glucoseToFructoseRatio` (canonical UI direction; inverse of `glucoseFructoseRatio`) plus `totalGlucose`/`totalFructose` fields. PlanCanvas is **not yet wired into `PlannerPage`** — F1 does the three-pane layout. 210 app + 266 core + 279 cli tests.

**v1.1 Phases E + F1 (Diagnostics rail + Assembly): pending.**

## Commands

Requires Dart SDK ≥ 3.8.0 (workspace feature plus `json_serializable`'s null-aware-element codegen used by `@JsonKey(includeIfNull: false)`).

```bash
flutter pub get                                           # install deps (resolves workspace; required when packages/app is present)
dart analyze                                              # static analysis (from root)
cd packages/core && dart test                             # core tests
cd packages/cli  && dart test                             # CLI tests
cd packages/app  && flutter test                          # Flutter app tests
cd packages/app  && flutter analyze                       # Flutter analyzer (separate from dart analyze)
dart test test/engine/timeline_builder_test.dart          # single test file (from a package)
dart run packages/cli/bin/fuel.dart                       # run CLI
cd packages/app  && flutter run -d chrome                 # run app in browser (smoke)
cd packages/app  && flutter build web                     # produce static web build
```

### Code generation

Models use `json_serializable`. The generated `.g.dart` files **are committed** to git. Regenerate after changing any annotated model:

```bash
cd packages/core && dart run build_runner build --delete-conflicting-outputs
```

## Storage

`FileStorageAdapter` writes JSON files to `~/.race-fueling/` (path hardcoded in `packages/cli/lib/src/storage/file_storage_adapter.dart`, overridable via `FUEL_HOME` env var).

Every JSON file carries a `schema_version` field. `RaceConfig` is at v2 as of v1.1; `AthleteProfile` and the user-products envelope remain at v1. To bump a schema: change the default `schemaVersion` in the model, bump the `currentVersion: N` argument at the relevant `validateSchemaVersion()` call in `file_storage_adapter.dart`, and extend `migrateRaceConfig` (or add a sibling migrator) in `packages/core/lib/src/storage/schema_migration.dart` with the new `if (v >= N) return ...` guard.

The first save of a previously-v1 race config triggers a `<name>.json.v1.bak` backup of the original bytes. Backup happens once per file (never overwrites an existing `.bak`).

The product library is two-tier: built-in defaults (Dart constants in `packages/core/lib/src/data/built_in_products.dart`) merged with user overrides at load time. Each liquid built-in carries `sipMinutes: 60` (500 ml drink mixes sipped over an hour); non-liquid products keep `sipMinutes: null`.

## Flutter app conventions (Phases B + C + D)

### Phase B foundations

- **Riverpod 3.x.** Plan code samples in `docs/superpowers/plans/2026-04-30-v1.1-flutter-app.md` were written for 2.x. When pasting from the plan: `valueOrNull` is gone (use `value` — returns `T?`); `AsyncNotifier.update(...)` is inherited (don't shadow it with a public sync setter).
- **Color-usage doctrine** (codified in `packages/app/lib/presentation/theme/tokens.dart` header): severity TEXT (CRITICAL / ADVISORY labels) is always `ink` or `ink2`. Color carries severity through left bars, dots, or icons only — never text foreground. Decorative-only hues (`accent`, `glu`, `fru`) FAIL contrast as text; use `accentInk` for accent text.
- **Dark mode** is deferred to v2 per spec §13. A `// TODO(dark-mode):` block in `tokens.dart` documents the retrofit trigger: if more than ~5 widget files reference these tokens before dark mode lands, do the `ThemeExtension<BonkTokens>` extraction proactively.
- **GoogleFonts in tests:** any widget test that touches `BonkType` must call `setUpGoogleFontsForTests()` from `packages/app/test/test_helpers/google_fonts_setup.dart` in `setUpAll`. It disables runtime font fetching and stubs the asset manifest.
- **`BonkType` role helpers are `static final TextStyle` fields** (memoized) — call as `BonkType.railTitle`, NOT `BonkType.railTitle()`. The two parameterized builders (`sans({size, w})`, `mono({size, w})`) remain methods.
- **Layering:** `lib/domain/` imports from `domain.dart` barrel only (which re-exports `package:race_fueling_core/core.dart`); `lib/data/` and `lib/presentation/` import from the barrel; never reach into core internals directly.
- **Migration runs at the storage adapter boundary**, not in `PlannerState.fromJson`. `PlanStorageLocal.load()` calls `migrateRaceConfig` before constructing `PlannerState` (mirrors `FileStorageAdapter` in `packages/cli`).

### Phase C reusable widgets (in `lib/presentation/widgets/`)

- **`BonkTextInput`** is the canonical text input. Use it everywhere instead of bare `TextField`. Accepts `value`, `onChanged`, `labelText` (accessible name + visible floating label), `maxLength`, `inputFormatters`, `keyboardType`, `monoFont`. Cursor-preserving `didUpdateWidget` syncs against external state without resetting selection. Material `OutlineInputBorder` with `BonkTokens.ink3` enabled border (3:1 contrast) and `BonkTokens.ink` 2px focused border.
- **`BonkSegControl<T extends Object>`** — pill-row picker. Each option wrapped in `Semantics(button, selected, inMutuallyExclusiveGroup, label, excludeSemantics)`. Re-tap of the currently-selected option is a no-op. Optional `groupLabel` adds outer `Semantics(container, label)`.
- **`BonkStepper`** — minus/count/plus row. 28×28 visual with 44×44 hit area via outer `Padding(EdgeInsets.all(8))`. `Semantics(value, increasedValue, decreasedValue, onIncrease, onDecrease)` outside, `ExcludeSemantics` on inner glyph row. Disabled state at min/max boundary uses `bg2` background + `rule2` border + `ink3` glyph. Optional `semanticLabel` (e.g. "Maurten Gel 100 quantity") and `keyPrefix` (`Key('$keyPrefix.minus')` / `'.plus'`).
- **`BonkFieldShell`** — label + child column. Wraps in `Semantics(container, label)` so screen readers associate the visible label with the child input. `ExcludeSemantics` on inner Text label avoids double-announce. Spacing via `BonkTokens.space6`.

### Phase C panel patterns (in `lib/presentation/panels/`)

- **Section panels are private `ConsumerWidget`s** that read state via `ref.watch(plannerNotifierProvider).requireValue` and the notifier via `ref.read(plannerNotifierProvider.notifier)`. No prop drilling. `_RailBody` composes them as `const _InventorySection()` / `const _AidStationsSection()`.
- **`Semantics(header: true)` on `_SectionLabel`** so screen readers can jump-by-heading.
- **AidStationRow toggle clears the active value** rather than auto-converting between time/distance with a magic km-per-hour assumption. User re-types fresh.
- **Inventory order preservation** — incrementing `+` replaces in place rather than removing-then-appending. `selectedProducts` ordering is stable.

### Phase C test conventions

- **Widget tests use `setUpGoogleFontsForTests()`** in `setUpAll` (Phase B convention extends).
- **`_pump(tester)` returns `ProviderContainer`** so widget tests can assert state directly via `c.read(plannerNotifierProvider).requireValue.<...>`. Pattern lives in `setup_rail_test.dart`.
- **`FakePlanStorage`** at `test/test_helpers/fake_plan_storage.dart` — supports `loaded`, `loadError`, `loadGate` (Completer for AsyncLoading branch testing), `lastSaved`, `saveCount`.
- **`Semantics` assertions** use `tester.ensureSemantics()` + `tester.getSemantics(find.byType(...)).getSemanticsData()` for `value`/`label`/`flagsCollection` (Tristate via `dart:ui`).
- **Setup-rail addressing convention**: `Key('setup.<field>')` (race_name, body_mass, distance_km, duration_hours, duration_minutes, discipline). Inventory keys: `Key('inv.${product.id}.minus')` / `'.plus'`.

### Phase C breadcrumb convention (`PC-*`)

Phase C shipped multiple known-deferred runtime concerns marked with inline `PC-*` comments. Each is locked by a test that pins the documented behavior so F1 can intentionally flip:

- **PC-RESPONSIVE** — `setup_rail.dart` hardcoded 320px width. F1 wires `BonkBreakpoint.setupRailWidth`.
- **PC-PRESERVE-DIST** — `RaceConfig.copyWith(distanceKm: null)` is a no-op (null-as-no-change). User can't clear distance via input. F1 fixes via sentinel-aware copyWith or explicit Clear button.
- **PC-UNIT-CONVERSION** — body mass / distance unit labels hardcoded to "kg" / "km" regardless of `unitSystem`. Imperial users see metric labels (accurate to stored value). F1 wires real unit conversion.
- **PC-ERROR-UI** — `SetupRail`'s error stub has no recovery action. F1 replaces with actionable banner per PB-DATA-1.

### Phase D widgets (in `lib/presentation/widgets/`) and panel (`lib/presentation/panels/plan_canvas.dart`)

- **`StatCard`** — label + RichText value + optional unit suffix + optional sub. `isHero` swaps `BonkType.statValue` for `BonkType.statHero`. `StatSeverity` enum (`ok` / `warn` / `bad`); when set, the card prepends a leading mono glyph (`✓` / `!` / `×`) at `BonkTokens.ink` AND draws a 3px severity-colored side rule. Both signals carry severity (PB-A11Y-1 doctrine). `Semantics(container, label: '$label: $value $unit, $sub, $severity', child: ExcludeSemantics(...))`. Test addressing key: `Key('stat-severity-${severity.name}')`.
- **`TimelineRow`** — clock + dual-bar (target band + actual fill) + items column + cumulative readout. Bar containers carry `Key('bar.target')` / `Key('bar.actual')` so width-math regression tests use `tester.getSize`. Bar geometry guards on `peakG > 0`. AID STATION marker: ink text + 4×14 `BonkTokens.warn` left bar (color carries severity via the bar, NOT the text — color doctrine). Consumes structural `ProductServing.isDrinkStart` marker (no string match). Row wrapped in `Semantics(container, label: _composedLabel())` with `ExcludeSemantics` on inner content.
- **`PlanCanvas`** — center pane. Reads `plannerNotifierProvider` AND `planProvider` (the latter is engine output; F1 will read the notifier separately for `isSeedFallback`). Race-name `Semantics(header: true)` + `maxLines: 2, overflow: ellipsis`. 6-card stat grid (Avg carbs/hr hero, Total carbs, Glu:Fru, Caffeine, Fluid w/ fuel, Items) — `IntrinsicHeight + Row + Expanded` so the hero sets row height. Glu:Fru flag fires when `summary.glucoseToFructoseRatio` falls outside `[_ratioOkLow, _ratioOkHigh]` (`0.9..1.5`, sports-nutrition consensus citation in code). `_ErrorFallback` shows static "Plan unavailable. Please reload." in `ink` with a `bad` left bar; `debugPrint` carries `$error` for L1 telemetry — never interpolated into UI text. Loading indicator wrapped in `Semantics(liveRegion: true, label: 'Loading plan')`.

### Phase D core additions

- **`PlanSummary.glucoseToFructoseRatio`** — canonical UI direction (glucose / fructose). Returns 0 when fructose ≤ 0 (UI renders "—" via the `ratio == 0` guard).
- **`PlanSummary.totalGlucose` / `totalFructose`** — engine populates from per-entry sums. `@JsonKey(defaultValue: 0.0)` for round-trip safety with legacy blobs.
- **`ProductServing.isDrinkStart`** — structural marker emitted by `product_allocator.dart` for the synthetic drink-start serving. UI consumes via `s.isDrinkStart` instead of substring-matching the `(sip start)` suffix on `productName`. The suffix is preserved on `productName` for backward compat (CLI prints it directly; no semantic dependency).

### Phase D color-doctrine compliance

Every severity-color usage (`accent`, `warn`, `bad`, `hydro`, `fru`) in Phase D is strictly decorative — left bars, dots, fill regions. Every severity TEXT goes through `ink`, `ink2`, or `ink3`. Severity affordance also has a redundant text/glyph signal (StatCard glyph; TimelineRow item-label text; AID STATION + `_ErrorFallback` copy in ink). PB-A11Y-1, PB-A11Y-4, and PB-A11Y-8 closed by Phase D.

### Phase D data-layer contract (PB-DATA-1)

- **`planProvider`** is `Provider<AsyncValue<FuelingPlan>>` — reads `plannerNotifierProvider` and pipes through `asyncState.unwrapPrevious().whenData((s) => generatePlan(s.raceConfig, s.athleteProfile, library))`. `unwrapPrevious()` keeps the previous AsyncData visible during transient errors per PB-ARCH-10.
- **`PlanStorageException`** (in `packages/app/lib/data/plan_storage.dart`) carries `message`, `cause`, `causeStack`, `rawBytes`. Thrown by `PlanStorageLocal.load()` when the key is present but the payload is malformed (FormatException / SchemaVersionException / TypeError / ArgumentError caught) or when the storage plugin fails to initialize (MissingPluginException). Empty key still returns `null`.
- **`PlannerNotifier._emit` AsyncError guard.** While `state is AsyncError`, mutators no-op (no save). `_emitForce` is the bypass used by `build()` (seed path) and by `discardCorruptedAndUseSeed`. `@visibleForTesting void debugEmit(state)` exposes the guard for unit-test reach.
- **Recovery hooks:** `Future<void> retryLoad()` invalidates the notifier and awaits the new build (rethrows on still-broken storage); `void discardCorruptedAndUseSeed()` writes the seed over the unreadable blob (the `${_key}.bak` backup is auto-created once by `PlanStorageLocal.save()` before the first overwrite). Both are wired by F1's recovery banner.
- **`SaveStatus` provider** (`saveStatusProvider` in `lib/presentation/providers/save_status_provider.dart`) — `Idle / InFlight / Failed`. In-flight counter ensures `markSuccess` only flips to `Idle` when the chain has fully drained. Sticky-Failed-until-next-success policy. Internal API: only `PlannerNotifier._emitForce` should call `beginSave / endSaveSuccess / endSaveFailure`.
- **`PlannerState.isSeedFallback`** — persisted (`@JsonKey(defaultValue: false)` for legacy blobs). `seed()` sets `true`. `_emit` auto-flips to `false` on the first user edit. Loaded blob with `true` (post-recovery, pre-edit user closed the app) survives the reload — F1's banner has continuity.

### Phase D test conventions

- **`Semantics(container, label) + ExcludeSemantics(inner)`** is the row/card-level AT pattern. Composed labels include time, totals, items, severity. Used by `StatCard` and `TimelineRow`.
- **`tester.getSize(find.byKey(Key('bar.actual')))`** for bar-geometry width-math assertions. Production keys are intentional documentation of the test contract.
- **`MediaQueryData(textScaler: TextScaler.linear(2.0))`** wrapper for textScaler tests (NOT `platformDispatcher.textScaleFactorTestValue` — less stable across versions). Tests assert `expect(tester.takeException(), isNull)` on desktop-sized surfaces (1200×1600 panel, 2400×3200 textScaler-200%). F1 owns narrow-surface responsive collapse.
- **`saveGate: Completer<void>?`** on `FakePlanStorage` for testing `inFlight` state observably (mirrors existing `loadGate`).
- **Static glyph + Semantics name** — StatCard severity tests assert both `find.text('!')` (visual) and the composed Semantics label including `'warn'` (AT).

### Active F1 / E1 / PB-DATA-2 carry-overs (breadcrumbed in code, grep-able)

- **F1-RESPONSIVE** (`plan_canvas.dart`) — collapse stat grid to `Wrap` at <880px. F1 owns the `BonkBreakpoint`-aware layout.
- **F1-EMPTY-PLAN** (`plan_canvas.dart`) — empty-state CTA when `entries.isEmpty`.
- **F1-ERROR-COPY** (`plan_canvas.dart`) — replace static "Plan unavailable" with typed-error bucketing per PB-DATA-1.
- **F1-DOTS-SHAPE** (`timeline_row.dart`) — migrate item dots from color-only to shape-encoded glyphs (PC-DOT-COLORS rationale; not blocking — text labels carry type signal redundantly).
- **E1-METRICS** (`plan_canvas.dart`) — promote `peak`/`perStepTarget` to a `Provider` when E1's diagnostics rail lands so both consumers share one computation.
- **PC-RESPONSIVE / PC-PRESERVE-DIST / PC-UNIT-CONVERSION / PB-SCROLL / PC-OUTLINED-BUTTON / PC-AID-VALIDATOR** — unchanged from Phase C.
- **PB-DATA-2 backlog** (TODO breadcrumbs in `planner_state.dart`, `plan_storage_local.dart`): field-bound validation in `fromJson`, localStorage quota DoS bucketing, integrity tag/checksum on saved blob.

## Custom Claude Tooling

- `tdd-dart` skill — invoke with the Skill tool before writing any Dart implementation code.
- `dart-quality-reviewer` subagent — run before merging any branch to main; checks ABOUTME headers, force-unwrap usage, TDD coverage, and naming rules.

## Testing

- Run `dart test` in each package and `dart analyze` from root before committing.
- Test output must be pristine. If a test intentionally triggers an error, capture and assert on the expected output.
- No mocks in end-to-end tests. Never write tests that assert mocked behavior.

## Build Tagging

When bumping the version in a package's `pubspec.yaml`, tag the commit: `git tag v<version> <commit-hash>`. The tag goes on the commit that sets the new version.
