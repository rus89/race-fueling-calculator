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

**v1.1 Phases D–F (Plan canvas + Diagnostics rail + Assembly): pending.**

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

## Flutter app conventions (Phases B + C)

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

### Phase F prerequisite — PB-DATA-1 (must land before F1 wires real UI mutators)

Currently the data layer is silently fault-tolerant: storage errors collapse to seed via `value` getter, and the first mutation post-error overwrites the recoverable corrupted blob. Race-day silent data loss risk. Before F1, land:

1. `planProvider` returns `AsyncValue<FuelingPlan>` (preserve error state).
2. `isSeedFallback` flag on `PlannerState` (or sibling provider) — set when `build()` returns seed because storage was empty OR errored.
3. `PlannerNotifier._emit` refuses to save while in error state until user explicitly opts in.
4. F1 surfaces an error banner (WCAG 3.3.1).

### Other Phase F carry-overs (deferred from Phase C reviews)

- **PB-SCROLL** — `setup_rail_test.dart`'s `_pumpTall` (360×2400 surface) workaround masks a production scroll-handling ambiguity (parent `SingleChildScrollView` + each `BonkTextInput`'s `EditableText` viewport fight for gestures at small viewports). F1 fix: set `BonkTextInput.scrollPhysics: NeverScrollableScrollPhysics()` for single-line inputs, or wrap rail with `PrimaryScrollController`.
- **PC-AID-VALIDATOR** — toggle-clear in `AidStationRow` uses `0` / `0.0` sentinels because `validateAidStationDefinitions` requires one of timeMinutes/distanceKm to be non-null. v1.x could relax the validator to accept "user-pending" states.
- **PC-OUTLINED-BUTTON** — `+ Add aid station` uses Material 3 OutlinedButton default; stylistically inconsistent with brutalist Bonk widgets. F1 polish: introduce `BonkButton` if a second secondary action lands.
- **PC-DOT-COLORS** — `_KindDot`'s 5-color mapping (gel→accent, liquid→ink2, chew→ink, solid→ink3, realFood→rule) gives three dark-on-cream dots that look pairwise similar at 10×10 px. Aesthetic polish since the dot is now decorative (Q1=C: type signal carried by mono subline + Semantics label). F1 polish.

## Custom Claude Tooling

- `tdd-dart` skill — invoke with the Skill tool before writing any Dart implementation code.
- `dart-quality-reviewer` subagent — run before merging any branch to main; checks ABOUTME headers, force-unwrap usage, TDD coverage, and naming rules.

## Testing

- Run `dart test` in each package and `dart analyze` from root before committing.
- Test output must be pristine. If a test intentionally triggers an error, capture and assert on the expected output.
- No mocks in end-to-end tests. Never write tests that assert mocked behavior.

## Build Tagging

When bumping the version in a package's `pubspec.yaml`, tag the commit: `git tag v<version> <commit-hash>`. The tag goes on the commit that sets the new version.
