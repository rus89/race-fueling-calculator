# Project Journal

## 2026-04-02 — Project Kickoff

### What we're building
Race Fueling Calculator — a CLI tool (Dart) that generates time-based race nutrition plans for endurance athletes. Helps plan what to eat/drink, when, and how much during races. Tracks carbs (glucose:fructose split), caffeine, hydration, and flags common mistakes.

### Key design decisions
- **Dart monorepo**: `packages/core` (pure domain logic, zero I/O deps) + `packages/cli` (CLI interface). Core designed for reuse by a future Flutter web/mobile app.
- **Engine is pure functions**: `generatePlan()` composes timeline building → carb distribution → product allocation → validation → environmental adjustments. No state, trivially testable.
- **Storage abstraction**: `StorageAdapter` interface in core, `FileStorageAdapter` in CLI (local JSON at `~/.race-fueling/`). Flutter will provide its own adapter.
- **Built-in products as Dart constants**: ~25 popular gels/drinks/bars/chews/real food. No JSON asset loading needed for pure Dart.
- **Schema versioning**: Every JSON file has `schemaVersion` for future migrations.
- **Two-tier product library**: Built-in defaults + user overrides, merged at load time.

### V1 scope
Core plan generation + terminal output only. Exports (markdown, CSV, PDF stem card) and Flutter app deferred to v2+.

### Key files
- Spec: `docs/superpowers/specs/2026-04-02-race-fueling-calculator-design.md`
- Implementation plan: `docs/superpowers/plans/v1.md`

### Milan's context
XCM mountain bike racer, progressing gut training from 60g→90g carbs/hour with maltodextrin/fructose. Building this for personal use first, then broader endurance community.
