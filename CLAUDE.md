# Race Fueling Calculator — Project Context

> Global development rules live in `~/.claude/CLAUDE.md` and are loaded automatically. This file only covers project-specific context.

## Architecture

Dart 3.x workspace with two packages:

- `packages/core` — pure Dart domain logic (models, plan engine, storage interface). Zero I/O dependencies. Reusable by a future Flutter app.
- `packages/cli` — CLI interface using `args`. Depends on `core`. Provides `FileStorageAdapter` and terminal formatting.

The engine is composed of pure functions: `generatePlan()` computes environmental adjustments first, then runs timeline building → carb distribution (rate scaled by altitude) → product allocation → per-entry water adjustment → validation. No state, trivially testable.

## Progress & Source of Truth

- `JOURNAL.md` — phase-by-phase progress log. Read at session start. Also contains a "Known Issues — Address After Phase 8" catalogue (16 items: allocator over-allocation, heat-index formula, coverage gaps); check before starting bug-fix work.
- `docs/superpowers/plans/v1.md` — implementation plan with per-task checkboxes.
- `docs/superpowers/specs/2026-04-02-race-fueling-calculator-design.md` — design spec.

Phases 0–5 complete (scaffolding, models, engine + integration, built-in products, storage). Phase 6 (CLI commands) is current; a worktree for it lives at `.worktrees/phase6-cli` on branch `feat/v1-phase6-cli`. Phases 7 (output formatting) and 8 (integration & polish) follow.

## Commands

Requires Dart SDK ≥ 3.0 (for the workspace feature).

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

`FileStorageAdapter` writes JSON files to `~/.race-fueling/` (path hardcoded in `packages/cli/lib/src/storage/file_storage_adapter.dart`).

Every JSON file carries a `schema_version` field. To introduce a breaking format change: bump the `schemaVersion` default in the relevant model (`race_config.dart`, `athlete_profile.dart`), update callers that pass `currentVersion` to `validateSchemaVersion()`, and add migration logic at the `TODO(migration)` marker in `packages/core/lib/src/storage/schema_migration.dart`.

The product library is two-tier: built-in defaults (Dart constants in `packages/core/lib/src/data/built_in_products.dart`) merged with user overrides at load time.

## Custom Claude Tooling

- `tdd-dart` skill — invoke with the Skill tool before writing any Dart implementation code.
- `dart-quality-reviewer` subagent — run before merging any branch to main; checks ABOUTME headers, force-unwrap usage, TDD coverage, and naming rules.

## Testing

- Run `dart test` in each package and `dart analyze` from root before committing.
- Test output must be pristine. If a test intentionally triggers an error, capture and assert on the expected output.
- No mocks in end-to-end tests. Never write tests that assert mocked behavior.

## Build Tagging

When bumping the version in a package's `pubspec.yaml`, tag the commit: `git tag v<version> <commit-hash>`. The tag goes on the commit that sets the new version.
