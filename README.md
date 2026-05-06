# Race Fueling Calculator

A command-line race-day nutrition planner for endurance athletes. Generates
minute-by-minute carb, caffeine, and water targets from a race profile,
your gut tolerance, and your product library — then flags every spot where
the plan exceeds physiological limits before race day.

Built for cyclists, marathon runners, ultrarunners, triathletes, and XC
mountain bikers who want to dial in fueling without spreadsheet math.

```bash
$ fuel plan generate --plan xcm-race
Time     │ Dist  │ Product               │ Carbs (G+F)    │ Cumul.   │ Caffeine   │ Water
─────────────────────────────────────────────────────────────────────────────────────────────────────
0:20     │ 7km   │ Maurten Gel 100       │ 25g (14+11)    │ 25g      │ —          │ 100ml
0:40     │ 14km  │ Maurten Drink Mix 320 │ 80g (44+36)    │ 105g     │ —          │ 500ml
1:00     │ 21km  │ Maurten Gel 100       │ 25g (14+11)    │ 130g     │ —          │ 100ml
...

═══ SUMMARY ═══
Total carbs:      315g
Average:          70.0g/hr
Total caffeine:   0mg
G:F ratio:        1:0.78
Total water:      1900ml

  High altitude (2000m): +2.5% carb target
  Caution: possible fatigue with prolonged exposure

═══ WARNINGS ═══
ADVISORY:
  • Plan delivers only 87% of altitude-adjusted carb target — add more product to fully compensate.
```

## Features

- **Time-based and distance-based timelines.** Pick whichever fits your
  race plan; the engine builds entry slots at fixed minute or kilometer
  intervals.
- **Three distribution strategies.** `steady`, `front-load`, `back-load`,
  plus support for custom carb-rate curves.
- **Environmental adjustments.**
  - **Heat:** NWS Rothfusz heat index with banded advisories (Caution /
    Extreme Caution / Danger / Extreme Danger) and per-band water ramps.
  - **Altitude:** piecewise-linear carb-need curve from 1500m to 5500m,
    capped at +20% above 5500m, derived from ACSM Position Stand on
    altitude (2008).
- **Validation suite.** Catches gut-tolerance overshoots, glucose:fructose
  ratios outside [0.5, 1.0], excessive caffeine, and under-delivery
  versus altitude-adjusted carb targets.
- **Built-in product library.** 25 ready-to-use products (Maurten, SiS,
  GU, Skratch, Precision, Torq, etc.) plus custom user products.
- **Plan persistence.** Store profiles, custom products, and named race
  plans in `~/.race-fueling/` — or override with `FUEL_HOME` for testing.
- **Pipe-friendly output.** Honors `NO_COLOR` env var and the `--no-color`
  flag; emits ASCII fallbacks for box-drawing glyphs when color is off.

## Installation

Requires the **Dart SDK ≥ 3.8.0** (workspace feature, plus
`json_serializable`'s null-aware-element codegen).

```bash
git clone <repo-url> race-fueling-calculator
cd race-fueling-calculator
dart pub get
```

Run the CLI in development:

```bash
dart run packages/cli/bin/fuel.dart --help
```

Compile a standalone executable:

```bash
dart compile exe packages/cli/bin/fuel.dart -o fuel
./fuel --help
```

## Quick start

```bash
# 1. One-time profile setup (75 kg athlete with 90 g/hr gut tolerance)
fuel profile setup --weight 75 --tolerance 90 --units metric

# 2. Create a race plan
fuel plan create \
  --name "XCM Race" \
  --duration 4h30m \
  --distance 95 --mode distance \
  --target 80 \
  --strategy front-load \
  --temp 28 \
  --altitude 1800

# 3. Add products to the plan
fuel plan products add "Maurten Gel 100" --plan xcm-race --quantity 8
fuel plan products add "Maurten Drink Mix 320" --plan xcm-race --quantity 2

# 4. Generate the fueling timeline
fuel plan generate --plan xcm-race
```

Use `FUEL_HOME=/tmp/some-dir` to keep test runs out of your real history.

## Commands

| Command                         | Purpose                                     |
|---------------------------------|---------------------------------------------|
| `fuel profile setup`            | Create athlete profile                      |
| `fuel profile show`             | Print current profile                       |
| `fuel profile set`              | Update one or more profile fields           |
| `fuel products list`            | List built-in + user products               |
| `fuel products show <id>`       | Show full product details                   |
| `fuel products add`             | Add a custom product                        |
| `fuel products edit <id>`       | Edit a custom product                       |
| `fuel products remove <id>`     | Remove a custom product                     |
| `fuel products reset`           | Remove all custom products                  |
| `fuel plan create`              | Create a named race plan                    |
| `fuel plan list`                | List saved plans                            |
| `fuel plan show <name>`         | Show a saved plan's config                  |
| `fuel plan delete <name>`       | Delete a saved plan                         |
| `fuel plan products add`        | Add a product to a plan                     |
| `fuel plan products list`       | List products in a plan                     |
| `fuel plan generate`            | Compute and print the fueling timeline      |

Run `fuel help <command>` for full flag documentation.

## How it works

The plan engine is a sequence of pure functions:

```
RaceConfig + AthleteProfile + Products
        │
        ▼
1. Environmental adjustments (Rothfusz heat index, piecewise altitude)
        │
        ▼
2. Build timeline (time- or distance-based slots)
        │
        ▼
3. Distribute carbs (steady / front-load / back-load / custom curve)
        │
        ▼
4. Allocate products
   • Drinks contribute as a sip background spread across each product's
     `sipMinutes`, capped at 65% of the per-slot target so gels stay in
     the rotation.
   • Unmet target accumulates into a gel-debt pool across slots; gels
     fire when the pool justifies a well-fitting one.
   • Aid stations refill inventory at their projected minute mark via
     `AidStation.refill` (a list of product IDs).
        │
        ▼
5. Per-entry water adjustment (additional ml/slot from heat)
        │
        ▼
6. Validate (aid-station definitions, gut tolerance, G:F ratio,
   caffeine, under-delivery)
        │
        ▼
       FuelingPlan with entries, summary, warnings
```

No mutation, no state — easy to test, shared end-to-end with the
Flutter app via the `core.dart` barrel.

## Flutter app (in progress)

`packages/app` hosts the Bonk Race Fueling Planner — a Material 3 web
app that consumes the same engine. v1.1 Phase B shipped the
scaffolding (design tokens, typography, breakpoints, storage, Riverpod
provider chain, MaterialApp bootstrap). v1.1 Phase C shipped the
**Setup rail** — race / carb-strategy / inventory / aid-stations input
sections — plus four reusable widgets (`BonkTextInput`,
`BonkSegControl`, `BonkStepper`, `BonkFieldShell`). v1.1 Phase D
shipped the **plan canvas** — `StatCard`, `TimelineRow`, and
`PlanCanvas` that render the active fueling plan as a 6-card stat
header plus a vertical timeline. PB-DATA-1 (data-layer hardening) also
shipped alongside Phase D: typed `PlanStorageException`, `SaveStatus`
provider, `discardCorruptedAndUseSeed` / `retryLoad` recovery hooks,
backup-corrupted-bytes-before-overwrite, persisted `isSeedFallback`
flag. Phase E (diagnostics rail) and Phase F (three-pane assembly)
are pending — until F1 lands, the SetupRail and PlanCanvas are fully
built and tested but not yet wired into `PlannerPage`. Run the current
state in a browser:

```bash
cd packages/app
flutter pub get
flutter run -d chrome
```

You should see a cream background with `Bonk planner — coming online…`
centered in Inter Tight ink. That's the stub `PlannerPage` waiting for
Phase F.

## Project structure

```
race-fueling-calculator/
├── packages/
│   ├── core/              # Pure Dart domain logic
│   │   ├── lib/src/
│   │   │   ├── models/    # AthleteProfile, RaceConfig, FuelingPlan, ...
│   │   │   ├── engine/    # timeline, distributor, allocator, validator
│   │   │   ├── data/      # built-in products
│   │   │   └── storage/   # adapter interface + schema migration
│   │   └── test/
│   ├── cli/               # CLI on top of core
│   │   ├── bin/fuel.dart
│   │   ├── lib/
│   │   │   ├── cli_api.dart      # Embedder-safe public surface
│   │   │   ├── cli_runner.dart   # Adds Command<void> classes
│   │   │   └── src/
│   │   │       ├── commands/
│   │   │       ├── formatting/   # color, plan_table, summary_block
│   │   │       ├── prompts/
│   │   │       ├── products/     # product_resolver
│   │   │       └── storage/      # FileStorageAdapter
│   │   └── test/
│   └── app/               # Flutter app (Bonk planner UI)
│       ├── lib/
│       │   ├── main.dart           # ProviderScope + BonkApp
│       │   ├── app.dart            # MaterialApp with full M3 theme
│       │   ├── domain/             # Re-exports + PlannerState
│       │   ├── data/               # PlanStorage + PlanStorageLocal
│       │   └── presentation/
│       │       ├── theme/          # tokens, typography, breakpoints
│       │       ├── widgets/        # BonkSegControl, BonkStepper,
│       │       │                   # BonkFieldShell, BonkTextInput,
│       │       │                   # InventoryRow, AidStationRow,
│       │       │                   # StatCard, TimelineRow
│       │       ├── panels/         # SetupRail, PlanCanvas
│       │       ├── pages/          # PlannerPage (stub until F1)
│       │       └── providers/      # Riverpod 3.x chain
│       │                           # (incl. SaveStatus + plan/warnings)
│       ├── test/
│       │   └── test_helpers/       # google_fonts_setup, fake_plan_storage
│       └── web/                    # index.html, manifest, icons
├── docs/superpowers/
│   ├── plans/v1.md                                  # v1.0 plan
│   ├── plans/2026-04-30-v1.1-flutter-app.md         # current plan
│   └── specs/                                       # design specs
├── JOURNAL.md                 # Phase log + Known Issues backlog
└── CLAUDE.md                  # Project rules for AI assistants
```

## Development

```bash
# Install dependencies (workspace-aware; use flutter pub get when packages/app exists)
flutter pub get

# Static analysis (must be clean)
dart analyze                                # workspace-wide
cd packages/app && flutter analyze          # Flutter-specific (separate analyzer)

# Run all tests
cd packages/core && dart test               # 266 tests
cd packages/cli  && dart test               # 279 tests
cd packages/app  && flutter test            # 210 tests

# Single test file
dart test test/engine/timeline_builder_test.dart

# Regenerate JSON serialization
cd packages/core && dart run build_runner build --delete-conflicting-outputs

# Smoke-build the web app
cd packages/app && flutter build web
```

Generated `*.g.dart` files are committed to source. After changing any
annotated model, regenerate before committing.

## Storage

Plans, profiles, and custom products are JSON files under
`~/.race-fueling/` (override with `FUEL_HOME=/path`). Each file carries a
`schema_version` field; the storage layer rejects files written with
versions newer than the running binary supports.

`RaceConfig` is at schema v2 as of v1.1. Loading a v1 file transparently
upgrades it on read (drops the obsolete `isAidStationOnly` flag, defaults
empty `refill` lists on aid stations). The first save after a migration
also writes the original bytes to `<name>.json.v1.bak` so a future
migration regression is recoverable.

## Versioning

Semantic versioning. The current release is **v1.1.0-rc.1** (engine RC,
tagged on the version-bump commit). The full v1.1.0 ships when the
Flutter app (Phases B–F) lands.

- **Phase B (scaffolding)** — complete (`packages/app` 0.1.0; tokens,
  typography, breakpoints, storage, Riverpod chain, BonkApp bootstrap).
- **Phase C (Setup rail)** — complete (4 reusable widgets +
  `SetupRail` panel with race / carb-strategy / inventory /
  aid-stations sections).
- **PB-DATA-1 (data-layer hardening)** — complete (`AsyncValue<FuelingPlan>`,
  typed `PlanStorageException`, `SaveStatus` provider, recovery hooks,
  backup-bytes, persisted `isSeedFallback`).
- **Phase D (Plan canvas)** — complete (`StatCard` + `TimelineRow` +
  `PlanCanvas`; 210 widget/unit tests). PlanCanvas is built and tested
  but not yet wired into `PlannerPage` — F1 does that.
- **Phases E + F (Diagnostics rail + Assembly)** — pending.

Known limitations (tracked in `JOURNAL.md`):

- Caffeine validation is one-size-fits-all (400 mg cap, 6 mg/kg) — no
  per-athlete sensitivity field. Tracked as KI-9.
- The under-delivery advisory covers carbs only; an analogous
  water-side advisory is tracked as KI-69.
- A refill landing on the very last slot is silently unused — the
  drink-start guard skips the final slot to avoid wasting inventory on
  a single sip step. Pinned by test in `product_allocator_test.dart`,
  deferred per the v1.1 plan-review.
- Distance-based timelines round slot times to integer minutes; the
  allocator's per-slot window can drift ±1 at the rounding boundary
  for a station whose projected minute lands on a slot edge. Documented
  for revisit when distance mode becomes a primary user-facing path.
- The CLI cannot set `RaceConfig.discipline` or `AidStation.refill` —
  those fields are forward-prep for the Flutter UI (Phases B–F). They
  read/write through storage correctly; only the input surface is
  missing.

KI-64 (allocator round-down silent under-delivery) is **obsoleted** by
the v1.1 allocator rewrite — the gel-debt pool absorbs slot-level
shortfalls across the timeline.

See `JOURNAL.md` for the full backlog.

## License

Not yet licensed. Contact the author before redistributing.
