# Race Fueling Calculator — Project Context

> Global development rules live in `~/.claude/CLAUDE.md` and are loaded automatically. This file only covers project-specific context.

## Architecture

Dart 3.x workspace with two packages:

- `packages/core` — pure Dart domain logic (models, plan engine, storage interface). Zero I/O dependencies. Reusable by the Flutter app planned for Phases B–F.
- `packages/cli` — CLI interface using `args`. Depends on `core`. Provides `FileStorageAdapter` and terminal formatting.

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

**v1.1 Phases B–F (Flutter app): pending.** Adds `packages/app` Flutter package; not started.

## Commands

Requires Dart SDK ≥ 3.8.0 (workspace feature plus `json_serializable`'s null-aware-element codegen used by `@JsonKey(includeIfNull: false)`).

```bash
dart pub get                                              # install deps (resolves workspace)
dart analyze                                              # static analysis (from root)
cd packages/core && dart test                             # core tests
cd packages/cli  && dart test                             # CLI tests
dart test test/engine/timeline_builder_test.dart          # single test file (from a package)
dart run packages/cli/bin/fuel.dart                       # run CLI
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

## Custom Claude Tooling

- `tdd-dart` skill — invoke with the Skill tool before writing any Dart implementation code.
- `dart-quality-reviewer` subagent — run before merging any branch to main; checks ABOUTME headers, force-unwrap usage, TDD coverage, and naming rules.

## Testing

- Run `dart test` in each package and `dart analyze` from root before committing.
- Test output must be pristine. If a test intentionally triggers an error, capture and assert on the expected output.
- No mocks in end-to-end tests. Never write tests that assert mocked behavior.

## Build Tagging

When bumping the version in a package's `pubspec.yaml`, tag the commit: `git tag v<version> <commit-hash>`. The tag goes on the commit that sets the new version.
