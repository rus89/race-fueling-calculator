# Flutter App + Engine v1.1 — Design Spec

**Status:** Draft for review
**Date:** 2026-04-30
**Author:** AI (with Milan)
**Source design:** Claude Design handoff bundle (`/tmp/rfp-design/race-fueling-calculator/`) — "Bonk — Race Fueling Planner" prototype
**Predecessor spec:** `docs/superpowers/specs/2026-04-02-race-fueling-calculator-design.md` (v1.0 CLI)

---

## 1. Context and intent

`packages/core` (race_fueling_core 1.0.0) and `packages/cli` (1.0.0) shipped on the `main` branch. The core is pure Dart with zero I/O dependencies, exactly so a UI layer could be added without touching engine internals.

A Claude Design handoff prototype ("Bonk — Race Fueling Planner") was produced as a high-fidelity React HTML mockup with its own JS engine. Two outcomes from analyzing the bundle:

1. The prototype's **visual and interaction design** is the target for a Flutter UI: a three-pane layout (setup rail / plan canvas / diagnostics rail), vertical timeline with target-vs-actual bars, ratio bar, caffeine meter, severity-tagged flag list. Editorial / lab-tool aesthetic with off-white paper, deep ink, electric-lime accent, Inter Tight + JetBrains Mono.
2. The prototype's **algorithm changes** in `engine.js` are not cosmetic. They fix real fueling-strategy problems the per-slot allocator in core 1.0 has: drink-as-sip background contribution across slots, drink contribution capped at 65 % of per-slot target so gels stay in the rotation, and a gel-debt accumulator that pools the unmet target across slots so gels fire when their size justifies the pooled gap. These are better defaults for race fueling than the v1.0 per-slot allocator.

This spec captures a single v1.1 release that does both: an engine port in `packages/core` and a new `packages/app` Flutter package that consumes it.

## 2. Goals

- Ship a Flutter app (web first, mobile/desktop free) that visually matches the prototype 1:1 within the agreed v1.1 cuts.
- Refactor `product_allocator` to the design's algorithm, in place, with TDD-driven tests.
- Reuse 100 % of `packages/core` types in the Flutter app — no parallel JS engine, no model duplication.
- Single page, single working plan, auto-save, no race-switching UI.
- Distance-based aid stations supported alongside time-based, using the existing `AidStation` model fields.
- Existing CLI (`packages/cli`) stays functional under the refactored engine; output reflects the new algorithm.

## 3. Non-goals (deferred to later versions)

- Tweaks panel (theme/accent/density/units toggles)
- Stem card view (printable 60 × 220 mm)
- Bike computer view (animated alert preview)
- Saved-races dashboard / multi-race library
- User-created products and product CRUD
- CSV import for product macros
- Custom strategy curve editor in the UI (engine still supports `Strategy.custom`)
- Dark theme
- Print / PDF export
- GPX file import
- Elevation-weighted km→min projection

These are tracked in §13.

## 4. High-level approach

A two-part v1.1.0 release:

1. **`packages/core` → 1.1.0** — engine port: drink-as-sip, 65 % drink cap, gel-debt accumulator, `sipMinutes` on `Product`, `discipline` on `RaceConfig`, distance-based aid-station projection, refill list on `AidStation`.
2. **`packages/app` → 0.1.0** — new Flutter package; depends on `race_fueling_core` via workspace; ships the three-pane timeline-only UI.

The `packages/cli` package picks up the engine changes automatically — its formatter renders the new `effectiveDrinkCarbs` field as a "sipping bottle" line analogous to the timeline UI; aid-station refills become explicit lines in the table.

In-place refactor (not a sibling allocator) because v1.0 has one user, no public API contract to honor, and dragging two allocators forward is real maintenance cost for no gain. Shape and intent are captured in tests and the JOURNAL.

## 5. Engine changes (`packages/core` 1.1.0)

### 5.1 Model changes

**`Product`** (`packages/core/lib/src/models/product.dart`)
- Adds `final int? sipMinutes` — the minutes over which a serving of this product is consumed. Null for instant items (gels, chews, real food). Set for liquids (typical: 60 for 500 ml drink mixes, 15 for a 250 ml cola).
- Schema bump (existing schema_version is per-file via `RaceConfig` and `AthleteProfile`; `Product` does not have its own schema field — built-ins are read-only Dart constants and user products will be written/read against the new shape).
- All existing `built_in_products.dart` `liquid` entries gain `sipMinutes` (60 for 500 ml mixes, 15 for cola, others assigned per real-world consumption guidance).

**`RaceConfig`** (`packages/core/lib/src/models/race_config.dart`)
- Adds `final Discipline? discipline` enum: `xcm`, `road`, `run`, `tri`, `ultra`. Nullable, no behavior coupled yet — purely carried as data for the UI and for future heat/altitude tables that may key off discipline.
- Schema bumps from 1 → 2. Migration: missing `discipline` in v1 JSON → null in v2 (no-op).

**`AidStation`** (`packages/core/lib/src/models/race_config.dart`)
- Adds `final List<String> refill` — product IDs delivered at the station. Defaults to `const []`.
- Existing `distanceKm` and `timeMinutes` fields stay as-is (both nullable). At least one must be set (validated by the engine).

**`PlanEntry`** (`packages/core/lib/src/models/fueling_plan.dart`)
- Adds `final double effectiveDrinkCarbs` — the capped drink contribution to this slot (≤ 65 % of slot target). UI renders this as the "sipping bottle" running line; not double-counted in `carbsTotal`.
- Adds `final AidStation? aidStation` — the station whose time mark falls inside this slot's window, if any. UI renders the "AID STATION — refill N items" marker.

**`ProductSelection.isAidStationOnly`** is removed. Its purpose is replaced by explicit `AidStation.refill: List<String>`. Schema migration (RaceConfig v1 → v2): if any `ProductSelection.isAidStationOnly == true` exists, drop that flag (the field is silently ignored on read; user is warned to re-enter aid station refills via UI on first load).

### 5.2 Algorithm changes — `product_allocator.dart`

Rewritten to mirror the design's `engine.js` semantics. Per slot of width `step_min`:

1. **Aid-station refill check.** If any `AidStation` falls inside `[t_start, t_end)`, increment the inventory remaining count for each product in `refill` by 1. (Stations defined by `distanceKm` are projected to a minute mark via §5.3 before this comparison.)

2. **Background drink sips.** For each currently active drink, contribute its `carbs_per_step = carbs_g / drink_steps` to this slot's drink contribution (and proportionally for glucose, fructose, caffeine, water). Decrement `steps_remaining`; remove the drink when it hits zero. The drink's first slot gets a `drink-start` marker item (the UI renders this as "START → bottle").

3. **Start a new drink if needed.** If no drink is currently active AND the slot is not the last AND the unmet target ≥ 30 g/hr, pick the highest-`carbs_g` available drink and start it (decrement inventory, add a `drink-start` marker item, contribute its first sip).

4. **Compute `effectiveDrinkCarbs = min(drinkCarbs, target × 0.65)`.** The remainder of the un-capped drink contribution is treated as palate-fatigue / spit-out / overflow and not counted against the slot's deliverables.

5. **Update `gelDebt += target − effectiveDrinkCarbs`.** This pools the unmet target across slots.

6. **Pick gels until `gelDebt < 12 g` or no candidates remain.** Candidates are non-drink items with `remaining > 0`. Sort by `|carbs_g − gelDebt|` (best fit). Skip a candidate if `pick.carbs_g > gelDebt × 1.6 AND pick.carbs_g > gelDebt + 6` (don't fire a 30 g gel for a 7 g gap). On pick: decrement inventory, add to `items[]`, decrement `gelDebt` by `pick.carbs_g`. Hard safety cap of 5 picks per slot.

7. **Cap negative gel debt** at `−target × 0.5` so a big gel doesn't suppress future picks for too many slots.

8. **Compose the slot.** `effectiveDrinkCarbs + solidCarbs` is `carbsTotal`. Glucose / fructose / caffeine / water are scaled proportionally for drinks (the cap shrinks them all by `drinkScale = effectiveDrinkCarbs / drinkCarbs`) and added directly for solids.

This is mathematically the design's `engine.js` `buildPlan`, ported to Dart with the same constants and same cutoffs. Comments in the source attribute the constants to the design's algorithm and explain *why* (palate fatigue, single-mode failure, gut-tolerance).

### 5.3 Distance-based aid-station projection

A small helper (`packages/core/lib/src/engine/aid_station_projection.dart`) projects each aid station to an effective minute mark before the allocator loop:

```
effectiveMin = aidStation.timeMinutes
            ?? linearProjection(aidStation.distanceKm, config.distanceKm, config.duration)
```

Where `linearProjection(km, totalKm, duration) = (km / totalKm) × duration.inMinutes`. If both are set, `timeMinutes` wins (explicit beats derived). If `distanceKm` is set but `RaceConfig.distanceKm` is null, the validator emits a warning ("Aid station at km X needs total race distance set") and the station is dropped from the allocation pass.

### 5.4 Validator

Existing `plan_validator.dart` warnings are kept. The `engine.js` set already maps onto your existing validator (gut-trained excess, ratio out of band, caffeine ceiling, no-fructose-source, plan undershoot/overshoot, hydration-light, no-caffeine-on-long-race). Two new checks land:

- **Aid-station definition.** If any `AidStation` has neither `timeMinutes` nor `distanceKm` set → `Severity.critical` "Aid station has no time or distance defined."
- **Distance projection without total.** If any `AidStation` uses `distanceKm` and `RaceConfig.distanceKm` is null → `Severity.advisory` "Aid station at km X needs race total distance set."

### 5.5 Migration

`schema_migration.dart` gains a v1 → v2 step:

- For each `RaceConfig` JSON loaded with `schema_version: 1`:
  - Drop `selectedProducts[].isAidStationOnly` (silently — field no longer in model).
  - Set `schema_version: 2`.
  - `discipline` not present → null in v2 (no-op).
  - `aidStations[].refill` not present → `[]`.
- New product field `sipMinutes` is part of `Product` shape (no `Product` schema-version migration needed since user-products didn't ship in v1.0; built-ins are constants in code).

## 6. Flutter app architecture (`packages/app` 0.1.0)

### 6.1 Layout

```
packages/app/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── domain/                       # re-exports from core; no widgets here
│   │   └── domain.dart
│   ├── data/
│   │   ├── plan_storage.dart         # interface
│   │   └── plan_storage_local.dart   # shared_preferences impl (web/mobile/desktop)
│   ├── presentation/
│   │   ├── pages/
│   │   │   └── planner_page.dart
│   │   ├── panels/
│   │   │   ├── setup_rail.dart
│   │   │   ├── plan_canvas.dart
│   │   │   └── diagnostics_rail.dart
│   │   ├── widgets/
│   │   │   ├── timeline_row.dart
│   │   │   ├── stat_card.dart
│   │   │   ├── ratio_bar.dart
│   │   │   ├── caffeine_meter.dart
│   │   │   ├── inventory_row.dart
│   │   │   ├── aid_station_row.dart
│   │   │   ├── product_stepper.dart
│   │   │   ├── seg_control.dart
│   │   │   └── flag_card.dart
│   │   ├── theme/
│   │   │   ├── tokens.dart
│   │   │   └── typography.dart
│   │   └── providers/
│   │       ├── planner_notifier.dart
│   │       ├── plan_storage_provider.dart
│   │       └── product_library_provider.dart
│   └── app.dart                       # root widget + ProviderScope
└── test/
    ├── unit/
    │   ├── providers/
    │   └── data/
    ├── widget/
    │   └── panels/
    └── golden/
        └── widgets/
```

### 6.2 Dependencies (`pubspec.yaml`)

```yaml
name: race_fueling_app
environment:
  sdk: ^3.6.0
  flutter: ">=3.24.0"
dependencies:
  flutter:
    sdk: flutter
  race_fueling_core:
    path: ../core
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  shared_preferences: ^2.3.0
  google_fonts: ^6.2.1
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  riverpod_generator: ^2.6.1
  build_runner: ^2.4.13
  custom_lint: ^0.7.0
  riverpod_lint: ^2.6.1
```

### 6.3 State management — Riverpod

A single `PlannerNotifier` (`@riverpod class`) holds the working state:

```dart
@riverpod
class PlannerNotifier extends _$PlannerNotifier {
  @override
  Future<PlannerState> build() async {
    final loaded = await ref.watch(planStorageProvider).load();
    return loaded ?? PlannerState.seed();
  }
  // mutators: updateRaceName, updateDuration, updateBodyMass,
  // updateDiscipline, updateTargetGPerHr, updateGutTrainedGPerHr,
  // updateStrategy, updateInventoryCount, updateTotalDistance,
  // addAidStation, updateAidStation, removeAidStation, etc.
}

@riverpod
FuelingPlan plan(PlanRef ref) {
  final state = ref.watch(plannerNotifierProvider).requireValue;
  final products = ref.watch(productLibraryProvider);
  return generatePlan(state.raceConfig, state.athleteProfile, products);
}

@riverpod
List<Warning> warnings(WarningsRef ref) =>
    ref.watch(planProvider).warnings;
```

UI panels read these computed providers and never call the engine directly. Recompute is automatic on any input change. Engine call is synchronous (single-digit ms for a 4 h 30 race) — no Isolate.

`PlannerState` is a small immutable class:

```dart
class PlannerState {
  final RaceConfig raceConfig;
  final AthleteProfile athleteProfile;
  // …copyWith, fromJson, toJson…
  factory PlannerState.seed() => /* Andalucía Bike Race stage 3 defaults */;
}
```

### 6.4 Persistence

`PlanStorage` interface (in `packages/app/lib/data/`):

```dart
abstract interface class PlanStorage {
  Future<PlannerState?> load();
  Future<void> save(PlannerState state);
}
```

`PlanStorageLocal` writes a single JSON blob to `shared_preferences` under key `working_plan`. Works identically on web (backed by `localStorage`), mobile (NSUserDefaults / SharedPreferences), and desktop. No file I/O needed in the app — file storage stays in `packages/cli`.

Auto-save: a 500 ms debounce per input change. Implemented as a Riverpod `ref.listen` on `plannerNotifierProvider` that schedules `save()` via a `Timer.periodic`-style debouncer.

### 6.5 Theme and tokens

`tokens.dart` mirrors the prototype's CSS custom properties as `ColorScheme` extension and a `BonkTokens` class:

```dart
class BonkTokens {
  static const bg = Color(0xFFf5f3ee);
  static const bg2 = Color(0xFFecebe4);
  static const paper = Color(0xFFfbfaf6);
  static const ink = Color(0xFF0e0e0c);
  static const ink2 = Color(0xFF2a2a26);
  static const ink3 = Color(0xFF5b5b54);
  static const rule = Color(0xFFd8d5cb);
  // accent computed via OKLCH → sRGB at theme construction
  // (oklch(0.88 0.18 120) → approx #c8e85b — locked at token def, no dynamic hue)
  static const accent = Color(0xFFc8e85b);
  static const warn = Color(0xFFc28a4a);
  static const bad = Color(0xFFcd5340);
  static const ok = Color(0xFF6fa169);
  static const hydro = Color(0xFF7fa3c4);
  static const caf = Color(0xFF9d614a);
  static const glu = Color(0xFFa8d24f);
  static const fru = Color(0xFFd4a04a);
}
```

`typography.dart` loads Inter Tight (400/500/600/700) and JetBrains Mono (400/500/600) via `google_fonts`. Base size 14, line height 1.45, mono uses `FontFeature.tabularFigures()`.

### 6.6 Responsive breakpoints (matching prototype)

- ≥ 1480 px: 320 / flex / 300 three-pane.
- 1380–1480 px: 300 / flex / 280; hide stat cols 5 and 6.
- 1080–1380 px: 280 / flex (no diagnostics rail); diagnostics accessible via slide-over button in topbar.
- 880–1080 px: 280 / flex; stats drop to 3 cols.
- < 880 px: single column; setup rail accessible via slide-over.

Implemented with `LayoutBuilder` + a `BonkBreakpoint` enum, not media-query magic.

## 7. UI surface

### 7.1 Topbar (44 px fixed)

- Brand mark (lime dot with ink ring + ink center) + "Bonk" + small mono "v0.1 · race fueling planner".
- Right side: plan summary mono readout `{round(total_carbs)}g · {fmtTime(duration)}` followed by `· auto-saved` (or `· saving…` while debounce timer is pending).

### 7.2 Setup rail (320 px)

Sections separated by dashed hairlines, mono small-caps section labels:

- **Race**
  - Name (text input).
  - Duration (h + m, two narrow numeric inputs side by side).
  - Body mass (numeric, kg or lb based on `AthleteProfile.unitSystem`).
  - **Total distance** (numeric, km or mi based on unitSystem; nullable). Renders inline warning if any aid station uses distance and this is null.
  - Discipline (5-option segmented control: xcm / road / run / tri / ultra).
- **Carb strategy**
  - Target intake — slider 30..120 step 5 with live label `Target intake — {value} g/hr`.
  - Gut-trained ceiling — slider 30..120 step 5 with muted styling and live label.
  - Distribution (3-option segmented: front-load / steady / back-load).
- **Inventory**
  - Section label shows total count (`Inventory ({totalItems} items)`).
  - One row per product in the library: dot (color-coded by `ProductType`) + brand + name + carbs + glu:fru ratio + caffeine badge if any + stepper (− / count / +). Active rows (count > 0) get the lime accent left bar.
- **Aid stations**
  - Empty hint when none.
  - One row per station: time/distance toggle [ Time | Distance ] + numeric input + unit suffix + refill chips (each chip removable) + add-product select + remove button.
  - "+ Add aid station" button at bottom; defaults the new station's mark to the midpoint of the race.

### 7.3 Plan canvas

- **Header**
  - Eyebrow `02 / Plan` (mono small-caps).
  - Title row: race name (large, weight 600) + (no view tabs in v1.1; the layout reserves the slot for v1.2 stem card / bike computer).
  - Stats grid (6 cards):
    - Avg carbs / hr (hero, large lime number, mono, with `target {target}` sub).
    - Total carbs (g).
    - Glu : Fru ratio (mono `1.25:1`; flagged warn if outside [0.9, 1.5] when fructose > 0).
    - Caffeine (mg).
    - Fluid w/ fuel (L, one decimal).
    - Items count.
- **Timeline**
  - Vertical axis ticks at 0g / peak/2 / peak (peak = max slot carbs across the plan, floor target × 0.5).
  - One row per slot:
    - Clock (`HH:MM` time-of-race) + elapsed (`+Hh MM`) on the left.
    - Dual-bar track: target band underlay + actual fill on top; mono readout `{actual}g / {target}g` to the right of the bar.
    - Items list:
      - "sipping bottle" line if `effectiveDrinkCarbs > 0` and no drink-start marker in the slot.
      - "START → {brand} {name}" line with carbs and sip duration for drink-start markers.
      - One line per non-drink item: dot + brand + name + carbs (+ caffeine badge + water sub).
      - "AID STATION — refill N items" marker line if `aidStation` is set.
      - Empty slot fallback "— sip water —".
    - Cumulative readout on the right: `{cumulative}g` with "cumulative" mono label.

### 7.4 Diagnostics rail (300 px)

- **Carb sources**
  - Horizontal ratio bar split into glucose-share + fructose-share.
  - Vertical ideal marker at `1 / 1.8` (the design's idealized 1:0.8 glucose share).
  - Mono legend with absolute glucose / fructose grams.
  - Big mono ratio readout `{ratio.toStringAsFixed(2)} : 1` + sub `ideal 1.25 (1:0.8)`.
- **Caffeine — {total} mg**
  - 5-segment meter (each segment fills as `total / (kg × 6)` reaches its share).
  - Last segment turns hot color when ceiling is reached.
  - Readout `{mgPerKg.toStringAsFixed(1)} mg/kg · ceiling 6.0`.
- **Flags ({count})**
  - Empty state: green dot + "All checks pass. Plan looks executable."
  - Non-empty: one card per warning. Card has a left bar in the severity color (high=bad, med=warn, low=hydro), a mono small-caps severity label, the warning title, and the description. Cards are scrollable when long.

## 8. Data flow

```
User input (Setup rail widget)
  ↓ ref.read(plannerNotifierProvider.notifier).updateX(value)
PlannerNotifier
  ↓ state = AsyncData(state.requireValue.copyWith(...))
  ↓ ref.listen → debounce 500ms → planStorage.save(state)
planProvider (computed)
  ↓ generatePlan(config, profile, products) — synchronous
FuelingPlan
  ├─→ PlanCanvas.stats reads .summary
  ├─→ PlanCanvas.timeline reads .entries
  └─→ DiagnosticsRail reads .summary + .warnings
```

- Engine errors (`ArgumentError`, `FormatException`, `AssertionError`) surface as a top-of-canvas red banner; the rest of the canvas dims and the previous valid plan stays visible. The user can edit inputs to recover.
- Product library starts as `builtInProducts` only. Future user-product CRUD is gated behind a separate provider.

## 9. Testing strategy

### 9.1 Engine port (TDD, in `packages/core`)

Test order (RED → GREEN → REFACTOR):

1. **Sip-as-background**: 500 ml drink with `sipMinutes: 60` + 4 h 30 race + `step_min: 15` should contribute `80 / 4 = 20 g` to each of 4 slots (or proportional under cap).
2. **Drink cap at 65 %**: target = 80 g/hr → per-slot target = 20 g → cap = 13 g; given a drink contributing 20 g per slot, `effectiveDrinkCarbs == 13`, `gelDebt += 7` per slot.
3. **Gel-debt accumulation**: across 4 slots `gelDebt` accumulates to 28 g; a 24 g chew or 25 g gel fires when debt ≥ 12 g and best-fit threshold passes.
4. **Best-fit threshold**: a 40 g gel does not fire when `gelDebt == 7`, but does when `gelDebt == 25`.
5. **Aid-station refill**: a station at min 90 with `refill: ['sis-beta-fuel']` adds 1 to inventory remaining at slot 6 (90/15).
6. **Distance-projected station**: `distanceKm: 30, RaceConfig.distanceKm: 90, duration: 270 min` → effectiveMin = 90.
7. **Distance without total**: `distanceKm: 30, RaceConfig.distanceKm: null` → validator advisory + station dropped from allocation.
8. **Both fields set**: `timeMinutes: 95, distanceKm: 30` → `timeMinutes` wins.
9. **Schema migration v1 → v2**: legacy JSON with `isAidStationOnly: true` round-trips through the migration with that field dropped and `schema_version: 2`.
10. **Andalucía Bike Race seed scenario**: 4 h 30, 80 g/hr target, 75 g/hr gut-trained, 2 SiS Beta Fuel + 4 Maurten 160 + 2 Maurten 100 CAF + 2 PF30 + 1 Clif Bloks, 2 aid stations → average within ±5 g/hr of target, gels appear in the rotation, `Severity.high` "Exceeds gut training" warning fires.

Coverage target: ≥ 80 % line coverage across the engine. Existing per-slot allocator tests are rewritten to the new semantics; obsolete assertions about `isAidStationOnly` are deleted.

### 9.2 Flutter app

- **Unit tests** (`test/unit/`):
  - `PlannerNotifier` mutators round-trip state correctly using `ProviderContainer`.
  - `planProvider` recomputes when state changes.
  - `PlanStorageLocal` round-trips through an in-memory `SharedPreferences` mock.
  - Debouncer fires once per quiescent window.
- **Widget tests** (`test/widget/`):
  - `SetupRail` — every input wires to its mutator; sliders fire continuous updates; segmented controls fire on tap.
  - `PlanCanvas` — given a fixed `FuelingPlan`, renders correct number of timeline rows, correct stat values, correct drink-start vs sipping-bottle vs solid-item rendering.
  - `DiagnosticsRail` — ratio bar geometry, caffeine meter fills, empty/non-empty flag states.
- **Golden tests** (`test/golden/`):
  - `TimelineRow` (drink-start, sipping-only, solid-item, aid-station, empty variants).
  - `RatioBar` (in-band, out-of-band, infinite ratio).
  - `CaffeineMeter` (0/3/5/over-ceiling fills).
- **Integration test** (`integration_test/`):
  - Cold start → seed defaults render → drag target slider from 80 → 100 → assert plan.average increases and "Exceeds gut training" warning is present.

No mocks for the engine — the app integration tests call `generatePlan` for real.

### 9.3 CLI

- Existing CLI tests continue to pass under the refactored allocator (some assertions about specific per-slot counts may need updating).
- One new test: CLI plan output shows the "sipping bottle" line and aid-station refill markers.

## 10. Plan output / CLI parity

The CLI's table formatter (`packages/cli/lib/src/formatting/`) is updated to render the new `effectiveDrinkCarbs` and per-entry `aidStation` fields:

- A row whose only carb contribution is `effectiveDrinkCarbs` shows `~ sip bottle (Xg)` instead of being blank.
- A row with a non-null `aidStation` includes a `── AID @ km Y / +HhMM ──` divider above it, listing the refill products.

The CLI does not gain any new commands or flags in v1.1.

## 11. Versioning and release

- `packages/core/pubspec.yaml`: 1.0.0 → 1.1.0
- `packages/cli/pubspec.yaml`: 1.0.0 → 1.1.0 (lockstep — depends on core 1.1)
- `packages/app/pubspec.yaml`: new at 0.1.0
- Git tags: `v1.1.0` on the merge commit (consistent with existing `v1.0.0` tag policy in CLAUDE.md).

## 12. Risks and open questions

| Risk | Mitigation |
|------|------------|
| OKLCH → sRGB color conversion drift between Flutter and the prototype | Tokens are pre-computed sRGB hex constants; documented in `tokens.dart` with the OKLCH source so the conversion is explicit and reviewable. |
| Riverpod codegen friction (build_runner setup) | Already a project pattern via `json_serializable`; no new tooling. Documented in CLAUDE.md update. |
| Engine port breaks existing CLI tests | TDD with rewrites; planned in §9.1 / §9.3. |
| `shared_preferences` key collision on web (multiple Flutter apps under same origin) | Use a namespaced key `bonk_v1.working_plan`. |
| google_fonts cold-fetch on first web load | Acceptable for v1.1; if it's painful, switch to bundled `.ttf` assets in v1.2. |
| Slider re-renders on every drag pixel cause expensive plan recomputation | Engine is fast, but if needed, debounce slider via `onChangeEnd` for the recompute (not for the visual label). |

## 13. Future work (logged, not in v1.1)

Drawn from the design's chat transcript and discussion with Milan during this design session:

- **Tweaks panel** — theme (light/dark), accent hue slider, density (compact/comfortable), units (metric/imperial), target-guide visibility toggle.
- **Stem card view** — printable 60 × 220 mm stem-tape strip, monospace, ready for `Cmd-P`.
- **Bike computer view** — animated cycling alert preview with NEXT readout.
- **Saved-races dashboard** — multi-race library; named race CRUD; switching between active plans.
- **User-created products** — UI to add/edit user product overrides on top of `builtInProducts`.
- **CSV import** — import real product macros from a CSV file.
- **Custom strategy curve editor** — UI for `Strategy.custom` with `CurveSegment` list (engine already supports it).
- **Dark theme** — tokens already in CSS; needs a settings screen to toggle.
- **Print / PDF export** — for the stem card and full plan summary.
- **GPX file import** — parse `.gpx` for total distance, elevation profile, and named waypoints; auto-populate `RaceConfig.distanceKm` and pre-fill aid stations from waypoint markers.
- **Elevation-weighted aid-station projection** — bias the linear km→min mapping using GPX climb/descent profile.
- **Mobile-specific gestures** — swipe between rails on phones beyond the breakpoint slide-overs.
- **Workout / training-plan integration** — gut-training progression tracker.

## 14. Implementation phases (preview)

Detailed phase breakdown belongs in the implementation plan (next step). High level:

- **Phase A — engine port** in `packages/core`: model changes (5.1), allocator rewrite (5.2), distance projection (5.3), validator additions (5.4), schema migration (5.5), test suite (9.1). Lands on its own branch, merges to `main` with `v1.1.0-rc.1` tag for the engine.
- **Phase B — Flutter scaffolding**: package creation, dependencies, theme tokens, typography, root widget, breakpoint enum.
- **Phase C — Setup rail**: every input + auto-save + state plumbing.
- **Phase D — Plan canvas**: stats grid + timeline rendering.
- **Phase E — Diagnostics rail**: ratio bar + caffeine meter + flag list.
- **Phase F — Polish, golden tests, integration test, CLI parity check**: ships `v1.1.0`.

Each phase has its own commit cadence and runs `dart test` + `dart analyze` + `flutter test` + `flutter analyze` clean before moving to the next.

---

*End of spec. Implementation plan generated separately via the `superpowers:writing-plans` skill.*
