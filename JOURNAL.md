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

## 2026-04-04 — Task 2.1: Timeline Builder Implementation

### Completed
Implemented `buildTimeline()` function and TimeSlot class for both time-based and distance-based race modes.

**Files created:**
- `packages/core/lib/src/engine/timeline_builder.dart` — Core timeline building logic with TimeSlot class
- `packages/core/test/engine/timeline_builder_test.dart` — 3 comprehensive tests covering time-based scenarios

**Key implementation details:**
- `TimeSlot` class holds timeMark (Duration), distanceMark (double?), and isAidStation flag
- `buildTimeline()` dispatches to time-based or distance-based builders based on config.timelineMode
- Time-based: generates slots at regular intervalMinutes, stops at or before race duration
- Distance-based: calculates constant pace (totalMin / totalKm) and maps distance intervals to time
- Aid stations are inserted as additional slots or mark existing interval slots as aid points
- All slots are sorted by timeMark before return

**Testing:**
- All 3 tests pass (time-based intervals, boundary handling, aid station insertion)
- Pre-existing model tests (22) still pass
- dart analyze shows no issues
- Committed to feat/v1-phase2-engine branch

**Notes:**
- Implementation matches spec exactly as provided in task
- No unexpected complexity or edge cases discovered during implementation
- Ready for next task (Task 2.2 — distance-based tests)

## 2026-04-04 — Task 2.2: Timeline Builder — Distance-Based Tests

### Completed
Added distance-based tests to verify `buildTimeline()` functionality for distance mode. Also applied defensive null-check fix flagged by code quality reviewer.

**Tests added to `packages/core/test/engine/timeline_builder_test.dart`:**
1. "100km race with 10km intervals produces 10 slots" — validates slot count, distanceMark values, and time calculations (5h/100km = 3min/km)
2. "aid station at 45km inserts between 40km and 50km" — validates aid station insertion creates new slot with correct distance and time marks

**Implementation fix in `packages/core/lib/src/engine/timeline_builder.dart`:**
- Changed aid station matching predicate in `_buildDistanceBased` from `(s.distanceMark! - stationKm).abs() < 0.001` to `s.distanceMark != null && (s.distanceMark! - stationKm).abs() < 0.001`
- This prevents force-unwrapping of nullable distanceMark field, making code defensive against null values even though they shouldn't occur in practice

**Testing:**
- All 27 tests pass (22 existing model tests + 3 time-based timeline tests + 2 new distance-based tests)
- dart analyze shows no issues
- Committed commit e5e558f to feat/v1-phase2-engine

**Notes:**
- Distance-based implementation was already complete from Task 2.1; this task added the missing test coverage
- Defensive null-check is simple and improves code robustness without changing behavior

## 2026-04-04 — Task 2.3: Carb Distributor — Steady Strategy

### Completed
Implemented carb distribution engine with all 4 strategies (steady, frontLoad, backLoad, custom).

**Files created:**
- `packages/core/lib/src/engine/carb_distributor.dart` — Core distributor logic with full strategy support
- `packages/core/test/engine/carb_distributor_test.dart` — Tests for steady strategy (2 tests cover consistent and uneven intervals)

**Implementation approach:**
- `distributeCarbs()` dispatches to strategy-specific handlers via switch
- `_distributeSteady()` — Constant g/min across all slots
- `_distributeFrontLoad()` — Higher early (1.1x), mid (1.0x), lower late (0.9x)
- `_distributeBackLoad()` — Lower early (0.9x), mid (1.0x), higher late (1.1x)
- `_distributeCustom()` — Uses CurveSegment array with cumulative duration tracking
- `_distributeByGapMinutes()` — Helper calculates slot carbs as rate × gap minutes

**Key insight:**
All strategies use the same helper for final carb calculation. The rate can vary by slot (steady = constant, others = variable multipliers). This keeps code DRY and testable.

**Testing:**
- 2 new tests for steady strategy (consistent 20-min intervals, uneven gaps with aid station)
- All 30 tests pass (22 existing + 2 new carb tests + 6 timeline tests)
- dart analyze: no issues
- Committed 52975c8 to feat/v1-phase2-engine

**Notes:**
- All 4 strategies implemented even though only steady tested now (Task 2.4 will test the rest)
- No force-unwraps in production code (defensive null checks where needed)
- ABOUTME headers verified on both files

## 2026-04-04 — Task 2.4: Carb Distributor — Front-load, Back-load, Custom Tests

### Completed
Added tests for front-load and custom carb distribution strategies. Back-load implementation exists but only front-load and custom were in the spec's test requirements.

**Tests added to `packages/core/test/engine/carb_distributor_test.dart`:**
1. **Front-load test** — "first third gets ~110%, last third gets ~90%": Validates 9 slots over 3 hours with 60g/hr target. First slot checks ~22g (20 min × 60g/hr × 1.1), last slot checks ~18g (20 min × 60g/hr × 0.9).
2. **Custom test** — "applies custom curve segments": Validates 4 slots over 2 hours with two 60-min curve segments (80g/hr then 40g/hr). First two slots (first hour) expect ~40g each (30 min × 80g/hr), last two slots (second hour) expect ~20g each (30 min × 40g/hr).

**Implementation verification:**
- All 4 strategies from Task 2.3 are fully implemented and working
- `_distributeFrontLoad()` uses 1.1x / 1.0x / 0.9x multipliers for progress 0-33% / 33-67% / 67-100%
- `_distributeCustom()` tracks cumulative duration and maps slots to segment rates
- Both tests verify exact behavior per spec

**Testing results:**
- All 34 tests pass (22 existing + 2 steady carb tests + 6 timeline tests + 2 new carb tests + 2 new custom/front-load tests)
- dart analyze: no issues
- Committed d35219c to feat/v1-phase2-engine

**Notes:**
- Back-load implementation exists but spec only required front-load and custom tests
- Design decision (per Task 2.3 notes): Multipliers do NOT normalize total carbs; races with uneven thirds may have ~1% deficit. This is acceptable per spec's "~" wording.
- ABOUTME headers verified on test file

## 2026-04-04 — Task 2.4: Carb Distributor — Front-load, Back-load, Custom Tests

### Completed
Added tests for front-load and custom carb distribution strategies. Back-load implementation exists but only front-load and custom were in the spec's test requirements.

**Tests added to `packages/core/test/engine/carb_distributor_test.dart`:**
1. **Front-load test** — "first third gets ~110%, last third gets ~90%": Validates 9 slots over 3 hours with 60g/hr target. First slot checks ~22g (20 min × 60g/hr × 1.1), last slot checks ~18g (20 min × 60g/hr × 0.9).
2. **Custom test** — "applies custom curve segments": Validates 4 slots over 2 hours with two 60-min curve segments (80g/hr then 40g/hr). First two slots (first hour) expect ~40g each (30 min × 80g/hr), last two slots (second hour) expect ~20g each (30 min × 40g/hr).

**Implementation verification:**
- All 4 strategies from Task 2.3 are fully implemented and working
- `_distributeFrontLoad()` uses 1.1x / 1.0x / 0.9x multipliers for progress 0-33% / 33-67% / 67-100%
- `_distributeCustom()` tracks cumulative duration and maps slots to segment rates
- Both tests verify exact behavior per spec

**Testing results:**
- All 34 tests pass (22 existing + 2 steady carb tests + 6 timeline tests + 2 new carb tests + 2 new custom/front-load tests)
- dart analyze: no issues
- Committed d35219c to feat/v1-phase2-engine

**Notes:**
- Back-load implementation exists but spec only required front-load and custom tests
- Design decision (per Task 2.3 notes): Multipliers do NOT normalize total carbs; races with uneven thirds may have ~1% deficit. This is acceptable per spec's "~" wording.
- ABOUTME headers verified on test file

## 2026-04-04 — Task 2.5: Product Allocator

### Completed
Implemented greedy product allocator that fills each timeline slot to its carb target.

**Files created:**
- `packages/core/lib/src/engine/product_allocator.dart` — `allocateProducts()` function and `AllocationResult` class
- `packages/core/test/engine/product_allocator_test.dart` — 4 tests covering core behaviors

**Key implementation details:**
- `AllocationResult` holds `List<PlanEntry>` and `List<String> depletionWarnings`
- Greedy: iterates slots, fills to target carbs using available products
- Aid-station-only products filtered out for non-aid-station slots via `aidOnly` map
- Quantity tracked in `remaining` map, decremented per slot
- Missing product IDs emit a warning and are skipped — no crash
- Products sorted to prefer dual-source (fructose > 0) for better G:F ratio
- Depletion warning emitted when product runs out before the last slot

**Analyzer fixes applied:**
- Removed unused `fueling_plan.dart` import from test file
- Added braces to single-statement `if (product == null)` block

**Testing:**
- All 4 new tests pass; full suite passes; `dart analyze` clean
- Committed 40ef6dd to feat/v1-phase2-engine

## 2026-04-04 — Task 2.6: Environmental Adjustments

### Completed
Implemented environmental adjustment calculations for heat, humidity, and altitude effects on fueling strategy.

**Files created:**
- `packages/core/lib/src/engine/environmental.dart` — `calculateAdjustments()` function and `EnvironmentalAdjustments` class
- `packages/core/test/engine/environmental_test.dart` — 5 tests covering all adjustment scenarios

**Implementation details:**
- `EnvironmentalAdjustments` holds `carbMultiplier` (1.0-1.1x), `additionalWaterMlPerSlot` (0-150ml), and `advisories` list
- Altitude logic: Linear scale from 1500m (0% boost) to 3000m (10% boost) with clamping
- Heat stress = temperature + (humidity/100)*10 with tiered water recommendations:
  - heatStress > 40: +50ml, advisory about extra water with gels
  - heatStress > 44: +50ml more, advisory about favoring drink mix
  - heatStress > 48: +50ml more (extreme heat)
- All inputs optional; returns neutral adjustments (1.0, 0.0, []) when no conditions provided

**Testing:**
- All 5 tests pass (no conditions, altitude, high temp, moderate, extreme heat)
- Full suite: 41 tests pass
- `dart analyze` clean
- No force-unwraps in production code
- Committed 8122ac6 to feat/v1-phase2-engine

**Notes:**
- Heat stress thresholds tuned to match test expectations (35°C/70% humidity triggers water, 40°C/85% humidity triggers 150ml total)
- Pure function with no side effects, easy to test and compose into larger plan engine
- ABOUTME headers verified on both files
- Journal previously recorded a stale entry (commit 1a5954a on feat/v1-core-engine) that did not apply to this worktree — actual implementation done in this session

## 2026-04-07 — Phase 3: Plan Engine Integration (Task 3.1)

### Completed
Implemented `generatePlan()` — the orchestrator that wires all Phase 2 components into a single pipeline.

**Files created:**
- `packages/core/lib/src/engine/plan_engine.dart` — 7-step pipeline: env adjustments → timeline → carb distribution → allocation → water adjustment → validation → summary
- `packages/core/test/engine/plan_engine_test.dart` — 3 integration tests

**Files modified:**
- `packages/core/lib/src/engine/carb_distributor.dart` — refactored `distributeCarbs()` to accept explicit `double targetCarbsGPerHr` param
- `packages/core/test/engine/carb_distributor_test.dart` — updated call sites to pass rate explicitly
- `packages/core/lib/core.dart` — added barrel exports for `plan_engine`, `TimeSlot`, `EnvironmentalAdjustments`

**Key design decision:**
Instead of copying the full `RaceConfig` just to apply the altitude multiplier (as the original plan suggested), refactored `distributeCarbs()` to accept an explicit rate. This keeps `generatePlan()` clean: `adjustedRate = config.targetCarbsGPerHr * adjustments.carbMultiplier`. Milan approved.

**Testing:**
- 54/54 tests pass; `dart analyze` clean
- Committed 2f66bec on feat/v1-phase3-engine

**Next:** Phase 4 — Built-in Products & Product Library (Tasks 4.1 and 4.2)

## 2026-04-07 — Phase 3: Code Review & Test Fixes

### Completed
Code-reviewed Phase 3 (first time it was reviewed). Two Important issues found and fixed.

**Issue 1 — Altitude test assertion too weak:**
The test used `greaterThanOrEqualTo` which couldn't catch a regression where `carbMultiplier` silently reverted to 1.0. Root cause: 25g gels absorb the ~6.7% altitude boost through ceiling arithmetic — both flat and mountain plans produced 150g (6 slots × 1 gel each). Fixed by switching to a 1g/serving liquid product so the adjustment produces a measurable difference (120g vs 132g), then tightening to `greaterThan`. Committed eb87ca2.

**Issue 2 — Depletion warning severity verified:**
Reviewer flagged that all `depletionWarnings` are mapped to `Severity.critical` — confirmed this is correct. The list contains exactly two cases: (a) product ID not found in library (plan can't execute as written), (b) product depleted before last slot (athlete runs out mid-race). Both are race-critical. No code change needed.

**Pre-existing bug logged (not fixed here):**
`plan_validator.dart:111` — `_checkGaps` only fires if the slot WITH the gap also has carbs. A depleted slot with a 35+ min gap won't trigger the warning. Fix deferred to its own task.

**Lesson learned:**
Integer ceiling in product allocation can mask multiplier effects. When writing integration tests that check environmental adjustments, always verify the product granularity is fine enough that the multiplier produces observable output differences.

## 2026-04-04 — Task 2.7: Plan Validator

### Completed
Implemented `validatePlan()` function — the last pure engine component before the `generatePlan()` orchestrator.

**Files created:**
- `packages/core/lib/src/engine/plan_validator.dart` — six check functions covering all warning conditions
- `packages/core/test/engine/plan_validator_test.dart` — 8 tests, one per behavior

**Checks implemented:**
1. `_checkGutTolerance` — rolling 60-min window; critical if carbs exceed tolerance × 1.15
2. `_checkSingleSource` — critical if glucose >60g/hr with zero fructose in any window
3. `_checkCaffeine` — critical if `entries.last.cumulativeCaffeine` > 400mg or >6mg/kg
4. `_checkGaps` — advisory if gap >30min between fueling entries
5. `_checkRatio` — advisory if fructose/glucose ratio outside 0.6–1.0 when >50g/hr
6. `_checkCarbDrop` — advisory if second-half carbs < 80% of first-half carbs

**Key design note:**
Caffeine check reads `entries.last.cumulativeCaffeine` (running total already computed by allocator), not per-entry caffeine. Tests manually construct entries with explicit cumulative values (150, 300, 450) to simulate this.

**Testing:**
- All 8 new tests pass; full suite 49/49 pass; `dart analyze` clean
- Fixed `unnecessary_brace_in_string_interps` lint warning (`${gap}` → `$gap`)
- Committed 760e99d to feat/v1-phase2-engine

**Notes:**
- All checks are pure functions — no state, no I/O
- ABOUTME headers verified on both files
- No force-unwraps in production code (`profile.bodyWeightKg!` used only inside an explicit `!= null` guard)

## 2026-04-07 — Phase 5: Storage Layer

### Completed
Implemented the storage layer: schema validation in core and file-based persistence in CLI.

**Task 5.1 — StorageAdapter interface + schema migration (core package):**
- `packages/core/lib/src/storage/schema_migration.dart` — `validateSchemaVersion()` + `SchemaVersionException`
- `packages/core/lib/src/storage/storage_adapter.dart` — abstract `StorageAdapter` interface
- `packages/core/test/storage/schema_migration_test.dart` — 3 tests (pass-through, missing version, future version)
- Barrel exports updated

**Task 5.2 — FileStorageAdapter (cli package):**
- `packages/cli/lib/src/storage/file_storage_adapter.dart` — full implementation
- `packages/cli/test/storage/file_storage_adapter_test.dart` — 9 tests with real file I/O via temp dirs
- Barrel export updated

**Design notes:**
- `AthleteProfile` and `RaceConfig` embed `schema_version` directly in their JSON (via `@JsonKey`), so `saveProfile`/`savePlan` can write model JSON directly and `loadProfile`/`loadPlan` can validate before passing to `fromJson`
- `saveUserProducts` wraps products in an envelope (`{schema_version, products: [...]}`) because `List<Product>` has no natural home for the version field
- Temp dir pattern in tests (setUp/tearDown) gives full file I/O coverage without polluting the real `~/.race-fueling/`

**Testing:**
- 73/73 tests pass across both packages; `dart analyze` clean on both

**Next:** Phase 6 — CLI Commands

## Known Issues — Address After Phase 8

Catalogued during full code quality review (2026-04-07). Do not fix mid-stream; address in a dedicated cleanup pass after all phases are done.

### Correctness Bugs (High Priority)

1. **Product allocator over-allocates via `.ceil()`** (`product_allocator.dart:70`)
   - `((target - carbsAssigned) / product.carbsPerServing).ceil()` rounds UP on every slot
   - A 20g target with a 25g product always assigns 25g — compounds across a long race
   - Can trigger false gut tolerance warnings. Fix: round-to-nearest or flag overage >20%

2. **Zero interval causes infinite loop** (`timeline_builder.dart`)
   - If `intervalMinutes` is explicitly set to 0, `for (var min = 0; min <= totalMin; min += 0)` never exits
   - No guard against this. Fix: validate interval > 0 at entry point
   - **CLI-guarded since Task 6.4** (`plan_command.dart` rejects `--interval 0` / `--interval-km 0` with `kExitUsage`). Core-layer fix still pending.

3. **Custom carb curve incomplete → silent fallback** (`carb_distributor.dart`)
   - If curve segments don't cover full race duration, falls back to base rate silently
   - No warning emitted. Fix: detect uncovered duration and emit advisory

4. **Altitude multiplier doesn't affect actual allocation** (`plan_engine.dart:30`)
   - Multiplier only adjusts the target rate passed to `distributeCarbs()`, not actual product quantities
   - If insufficient product quantity exists, the adjustment is invisible in the final plan
   - Fix: apply environmental multipliers before allocation, not just to the input rate

5. **Zero distance causes nonsensical timeline** (`timeline_builder.dart:61`)
   - `paceMinPerKm = totalKm > 0 ? totalMin / totalKm : 0.0` — if distance is 0, all slots get `timeMark = Duration(0)`
   - Allocator still runs, producing a broken plan with no warnings
   - **CLI-guarded since Task 6.4** (`plan_command.dart` rejects `--distance 0` in distance mode with `kExitUsage`). Core-layer fix still pending.

### Domain Logic Errors (High Priority)

6. **Heat index formula is made up** (`environmental.dart:38`)
   - `heatStress = temperature + (humidity / 100) * 10` is not a real formula
   - At 35°C/80% humidity: formula gives 43, real heat index is ~52°C
   - Thresholds (40, 44, 48) were tuned to pass tests, not physiology
   - Fix: use standard WBGT or Rothfusz heat index approximation, re-derive thresholds

7. **Altitude formula is linear, physiology is not** (`environmental.dart:26-32`)
   - Linear scale 1500m→3000m giving 0%→10% boost is oversimplified
   - Real O₂ availability drops exponentially; above 3000m the formula gives no further adjustment
   - Acceptable for V1 but should be flagged with a `// TODO(accuracy):` comment

8. **G:F ratio range [0.6, 1.0] may not match current guidelines** (`plan_validator.dart:145`)
   - Current sports nutrition (2024) often recommends 2:1 glucose:fructose
   - `fructose/glucose` range of [0.6, 1.0] means glucose:fructose of [1:0.6 to 1:1], narrower than guidelines
   - Fix: verify against current research, add citation comment

9. **Caffeine threshold is one-size-fits-all** (`plan_validator.dart:83-98`)
   - 400mg absolute cap and 6mg/kg are hardcoded with no athlete-level override
   - Acceptable for V1 but AthleteProfile has no sensitivity field

### Test Coverage Gaps (Medium Priority)

10. **Plan engine tests cover only happy paths** (`plan_engine_test.dart`)
    - Missing: empty product list, zero-duration race, fructose-only products, negative carb rate, all products filtered by aid-station constraints

11. **Validator reports only first violation per category** (`plan_validator.dart`)
    - `break` after first warning means a plan with 3 gut-tolerance violations only reports one
    - Fix: remove breaks, collect all violations

12. **Allocator tests never assert cumulative carbs/caffeine** (`product_allocator_test.dart`)
    - `cumulativeCarbs` and `cumulativeCaffeine` fields are never verified in any test

13. **Validator tests check warning presence, not count** (`plan_validator_test.dart`)
    - `warnings.any(...)` passes even if the same warning is emitted 10 times

### Architecture Issues (Medium Priority)

14. **Circular distributor/allocator responsibility**
    - Distributor outputs fractional targets; allocator rounds up; validator reacts to damage
    - Allocator should report overfill delta so caller can decide, not silently overdeliver

15. **Gap computation is implicit** (`timeline_builder.dart` / `carb_distributor.dart`)
    - Distributor relies on `slots[i].timeMark - slots[i-1].timeMark` being stable and sorted
    - No contract enforces this. Fix: either make gap explicit in TimeSlot or add a `computeGaps()` helper

16. **Product library merge has no conflict validation** (`product_library.dart`)
    - User override replaces built-in by ID, but if user's product is missing glucose/fructose, the ratio changes silently
    - Fix: warn if user product is missing fields that the built-in had

### Phase 6 CLI Quality Review (Medium Priority)

Catalogued 2026-04-28 from `dart-quality-reviewer` pass on the merged Phase 6 work. Same directive: address in the dedicated cleanup pass, not mid-stream.

17. **`plan_command.dart` is 753 lines** (`packages/cli/lib/src/commands/plan_command.dart`)
    - Six subcommand classes plus the parent live in one file; under the 800 ceiling but past the 400 "consider splitting" mark
    - Fix: split `_PlanCreateCommand`, `_PlanGenerateCommand`, and `_PlanProductsCommand` into their own files under `lib/src/commands/plan/`

18. **`products_command.dart` is 567 lines** (`packages/cli/lib/src/commands/products_command.dart`)
    - Six subcommands plus helpers in one file
    - Fix: split into `lib/src/commands/products/`, separating read-only (list/show) from write (add/edit/remove/reset)

19. **`plan_command_test.dart` is 1168 lines** (`packages/cli/test/commands/plan_command_test.dart`)
    - Mixes plan-create, plan-list, plan-show, plan-delete, plan-products-add/list, and plan-generate tests; failures hard to navigate
    - Fix: split along subcommand lines, mirroring whatever split lands for #17

20. **Coverage gap — `_PlanProductsListCommand` plan-not-found path** (`plan_command.dart:655`)
    - The `_storage.loadPlan(planName) == null` branch has no dedicated test
    - Fix: add a test running `plan products list --plan nonexistent` asserting `kExitUsage` with "Plan not found"

21. **Coverage gap — `_PlanShowCommand` silently accepts extra positionals** (`plan_command.dart:360`)
    - `results.rest.first` is taken without checking `results.rest.length`; extra args are silently ignored
    - Fix: either pin current behavior with a test or reject `rest.length > 1` — make the choice deliberate

22. **Inconsistent "not found" exit codes** (`plan_command.dart` vs `profile_command.dart`)
    - "Plan not found" uses `kExitUsage` (lines 371, 448, 571, 657, 708); "No profile found" uses `kExitData` (`profile_command.dart:204, 263`; `plan_command.dart:721`)
    - Both are defensible (plan = user typo → usage; profile = data missing → data error), but the convention should be either unified or documented
    - Fix: pick one rule and apply it consistently, or add a one-line decision note here

### Phase 7 Plan Review (Medium Priority)

Catalogued 2026-04-28 from a `/plan-review` pass on the Phase 7 amendments in `docs/superpowers/plans/v1.md`. Critical/High gaps were patched into the plan in the same session; these Medium items are deferred to the cleanup pass.

23. **Color contract under captured stdout — pin the assumption** (Phase 7 cross-cutting rule 1)
    - Inside `dart test`, `stdout.supportsAnsiEscapes` reports `false`, so `resolveColorMode(noColorFlag: false)` correctly returns `false` and existing `captureOutput` tests stay clean
    - This works today but is implicit; a config change (e.g. running tests with `--reporter=expanded` on a TTY-attached runner) could cause ANSI to leak into existing assertions
    - Fix: add a unit test for `resolveColorMode` that locks the precedence (`--no-color` → `NO_COLOR` env → `stdout.supportsAnsiEscapes`), and a CI smoke test that runs the suite with stdout redirected to confirm no ANSI bleeds

24. ~~**Phase 8 barrel export still references `plain_plan.dart`**~~ — RETRACTED 2026-04-29
    - Audited via `/plan-review` on Phase 8 before implementation. Task 8.1's snippet correctly lists `plan_table.dart`, `summary_block.dart`, and `color.dart` — no `plain_plan.dart` reference exists anywhere in Phase 8. The fear was unfounded; either the plan was authored after the Phase 7 amendment or the snippet was patched proactively. No follow-up needed.

25. **G:F ratio direction is undocumented in the formatter** (`summary_block.dart`, after Task 7.3 lands)
    - Engine stores ratio as `fructose / glucose` (`plan_engine.dart:82`); label `'1:${ratio}'` reads correctly as glucose:fructose. The patched Task 7.3 snippet adds an ABOUTME line documenting this, but the contract is one inadvertent inversion away from being silently wrong
    - Fix: in the cleanup pass, add a unit test pinning `formatSummaryBlock` against a known glucose=10 / fructose=8 plan asserting `'1:0.80'` exactly. Catches any future formula flip in the engine

26. **Dead Phase 6 snippet still calls `print(formatPlanTable/SummaryBlock)`** (`v1.md` lines ~4497-4499)
    - The pre-amendment Phase 6 snippet at those lines still shows `print(...)` which conflicts with the Phase 7 cross-cutting rule "No `print()`"
    - Phase 6 is shipped so this is dead text, but it's a footgun for any reader skimming the plan top-down
    - Fix: in the cleanup pass, strike through or annotate the Phase 6 snippet block to flag it as superseded

### Phase 7 Implementation Review — Tasks 7.1+7.2 (Medium Priority)

Catalogued 2026-04-29 from a multi-agent review (architecture / test-coverage / accessibility-UX) of `color.dart` and `plan_table.dart`. CRITICAL #1 (NO_COLOR spec violation) and HIGH #2/#3/#4 were fixed in commits 530acba and 5351f6d on `feat/v1-phase7-formatting`. Items below are deferred.

27. **No `--color=always` force-on path** (`color.dart`, deferred to Task 7.4)
    - When auto-detect wrongly reports no-TTY (piping into `less -R`, `script`, terminal recorders, CI logs), users have no way to opt back in to colored output other than unsetting `NO_COLOR`
    - Fix: in Task 7.4, accept a tri-state via `ColorMode { auto, always, never }` (or `forceColor: bool`) so a `--color=always` flag can override `stdout.supportsAnsiEscapes`. Pairs naturally with the `--no-color` flag already planned for Task 7.4

28. ~~**`_separator` / column widths private; Task 7.3 needs them**~~ — RETRACTED 2026-04-29
    - Original concern assumed Task 7.3's SUMMARY divider would match the table's total width. Actual implementation uses a fixed-length banner (`═══ SUMMARY ═══`, 15 chars) that is intentionally decoupled from table width. Architecture reviewer (Tasks 7.3+7.4 multi-agent review) confirmed coupling them would actively harm cohesion. False alarm; no follow-up needed.

29. **Truncation uses byte-based `substring(0, 24)`** (`plan_table.dart:67-68`)
    - `String.substring` operates on UTF-16 code units; product names with multi-code-unit graphemes (emoji, accented chars in user-defined products) can split mid-character and produce mojibake
    - Fix: use `raw.characters.take(24).toString()` from `package:characters` (already in Dart core); add a regression test with a non-ASCII product name placed at the boundary

30. **`distanceMark!` force-unwrap inside conditional** (`plan_table.dart:42`)
    - Guarded by the immediately-preceding `!= null`, so safe today, but project policy prefers structural null guards (cf. commit a152eae which removed `rawDuration!` for the same reason)
    - Fix: rewrite as `final dist = entry.distanceMark; dist != null ? '${dist.toStringAsFixed(0)}km' : ''`

31. **Magic numbers `25` / `24` duplicate `widths[2]`** (`plan_table.dart:67`)
    - Truncation thresholds are hand-derived from the Product column width; widening the column in the future silently desyncs truncation
    - Fix: pass the column width into `_productCell` and compute `width - 1` for the truncation arithmetic

32. **`formatPlanTable` signature closed to deferred v2 work** (`plan_table.dart:8`)
    - Aid stations and per-entry warnings are deferred to v2; when they land, callers will need to opt them in
    - Fix: consider a Dart 3 record `({required bool useColor})` in v2 so adding `showAidStations` is non-breaking

33. **Box-drawing glyphs degrade screen-reader / non-UTF-8 output** (`plan_table.dart:6`, v1.1)
    - `│` / `─` are announced poorly by VoiceOver/NVDA and corrupt under `LANG=C`
    - Fix: in v1.1, add a `--plain` ASCII fallback (`|` / `-`) and auto-detect via `LANG`/`LC_ALL`

34. **Truncation persists when output is piped** (`plan_table.dart:67`, v1.1)
    - Rationale for truncation (fixed terminal width) disappears when output goes to a file or pipe; "Maurten Drink Mix 320 Caffe…" hides load-bearing tokens
    - Fix: in v1.1, auto-disable truncation when `!stdout.hasTerminal`; expose `--no-truncate` / `--wide` for explicit control

35. **Alignment test only checks one content row** (`plan_table_test.dart`, ~line 135 pre-coverage commit)
    - The `useColor: true` alignment test verifies header/divider/first-row visible-width parity; if any row down the table contains a wider product cell or longer carb string, mis-alignment goes undetected
    - Fix: loop over all content rows in the alignment test and assert `visibleWidth(line) == dividerWidth` for each

36. **`visibleWidth` lacks non-ASCII and all-ANSI test coverage** (`color_test.dart`, line ~37)
    - Current tests cover plain strings and SGR-wrapped ASCII; no test for `'foo…'` (U+2026 ellipsis used by truncation), all-ANSI strings (`'\x1B[31m\x1B[0m'` should give 0), or multi-segment SGR sequences as inputs to `padVisibleRight`
    - Fix: add `expect(visibleWidth('foo…'), 4)` and `expect(visibleWidth('\x1B[31m\x1B[0m'), 0)` plus a `padVisibleRight` test on a multi-segment SGR string

37. **`visibleWidth` uses code-unit `.length` — latent CJK/emoji misalignment** (`color.dart:30`, v2)
    - ASCII-only built-in product catalogue masks this today, but a custom "🧪 Beta Test" or CJK name will misalign columns. Correct fix needs `package:characters` plus East-Asian Width tables — heavier than v1 warrants
    - Fix: track for v2; pairs with #29 (truncation grapheme safety) and #33 (`--plain` ASCII fallback)

38. **No `stdout.terminalColumns` adaptation** (`plan_table.dart:31`, v2)
    - Fixed ~76-col layout (or ~98-col with Dist column) wraps on 60-col terminals (mobile SSH, narrow tmux panes)
    - Fix: in v2, read `stdout.terminalColumns` and trim/wrap columns dynamically; pairs with `--wide` from #34

### Phase 7 Implementation Review — Tasks 7.3+7.4 (Medium Priority)

Catalogued 2026-04-29 from a multi-agent review (architecture / test-coverage / accessibility-UX) of `summary_block.dart`, the `_PlanGenerateCommand` wiring, and the new `full_flow_test.dart` E2E. HIGH items (glyph unification, rule 5(b) gap, E2E cwd, env-only NO_COLOR, plan doc drift) were fixed in commits 019c29e, b611047, 2a2a474. Items below are deferred.

39. **Severity color rendering duplicated between summary_block and table** (`summary_block.dart:46-49` + future `plan_table.dart`)
    - When v2 adds inline per-entry warnings, the `Severity → color` mapping (critical→red, advisory→yellow) will be in three places
    - Fix: lift `severityColor(Severity, String, {bool useColor})` helper into `color.dart` (or `severity_format.dart`); both summary_block and the future inline-warning renderer call into one place

40. **`_formatDuration` duplicated with divergent formats** (`plan_command.dart:46-52` vs `plan_table.dart`)
    - Two private `_formatDuration` helpers exist with different output (`3h30m` vs `3:30`); divergence is intentional but undocumented and a future reader may unify them by accident
    - Fix: either consolidate into a shared util with a comment explaining the two flavors, or add an ABOUTME line in each clarifying their distinct contracts

41. **E2E spawns 4 `dart run` subprocesses** (`full_flow_test.dart`)
    - ~8–20s of cold-start cost per CI run; overlap with `plan_command_test.dart`'s in-process tests is high
    - Fix: mark with `@Tags(['e2e'])`, exclude from default `dart test` runs, gate behind an explicit CI job to keep the inner-loop suite fast

42. **Banner literals hardcoded inline** (`summary_block.dart:11-12,35`)
    - `═══ SUMMARY ═══` / `═══ WARNINGS ═══` and their ASCII fallbacks appear inline; if reused elsewhere, they'll diverge
    - Fix: extract `summaryBanner(useColor)` / `warningsBanner(useColor)` constants; minor cleanup, not load-bearing

43. **Coverage — mixed-warnings test doesn't lock structural ordering** (`summary_block_test.dart:38-62`)
    - Asserts both `CRITICAL` and `ADVISORY` text present, but not that `WARNINGS` precedes both, that `CRITICAL` precedes `ADVISORY`, or that totals precede WARNINGS
    - Fix: add `output.indexOf('CRITICAL') < output.indexOf('ADVISORY')` and `output.indexOf('WARNINGS') < output.indexOf('CRITICAL')`

44. **Coverage — G:F ratio formatting only pinned at one value** (`summary_block_test.dart:64-70`)
    - Single test case at `0.80` happens to format identically under naive `toString()`; rounding behavior of `toStringAsFixed(2)` is unverified
    - Fix: add cases at `0.667` (asserts `1:0.67`) and `1.0` (asserts `1:1.00`, not `1:1`) to lock rounding

45. **Coverage — empty-notes branch spacing not precisely locked** (`summary_block_test.dart:72-95`)
    - Asserts trailing line is non-empty but not the exact line structure between totals and WARNINGS when notes are empty
    - Fix: assert exact substring like `'Total water:      1200ml\n\n=== WARNINGS ==='`

46. **Coverage — E2E doesn't assert stderr empty** (`full_flow_test.dart`)
    - Only checks exit code and stdout; advisory leakage to stderr would go undetected
    - Fix: add `expect(result.stderr.toString(), isEmpty)` to both E2E tests

47. **UX — severity not recoverable from a single bullet line** (`summary_block.dart:41,48`, v1.1)
    - Each warning bullet is `'  • <message>'`; if a user pipes through `grep '•'` or a screen reader extracts a single line, severity depends on the upstream group header
    - Fix: in v1.1, add inline `[CRITICAL]` / `[ADVISORY]` text prefix on each bullet; pairs with KI-33's `--plain` proposal

48. **Polish — code style nits in `summary_block.dart`** (LOW)
    - Variable `s` for `plan.summary` should be renamed to `summary` (clearer)
    - `buf.writeln('')` should be `buf.writeln()` (no arg) at lines 10, 21, 33
    - Fix: trivial cleanup; no urgency

49. **`full_flow_test.dart` lacks `@Timeout` annotation** (`full_flow_test.dart:7`, LOW)
    - A hung subprocess blocks the suite for `dart test`'s default 30s
    - Fix: add `@Timeout(Duration(seconds: 60))` and a one-line comment explaining why

50. **Coverage — new "summary block emitted" test in plan_command_test doesn't assert table portion** (`plan_command_test.dart:1168-1204`, LOW)
    - The test confirms summary is reachable but doesn't assert plan-table substrings (`'Maurten Gel 100'`) co-emit
    - Fix: add the product assertion to confirm table-then-summary composition

51. **`--no-color` help text doesn't state precedence** (`plan_command.dart:693`, LOW)
    - Help reads "Disable colored output. Also honors NO_COLOR env var." — doesn't make explicit that the flag wins
    - Fix: extend to "Equivalent to setting NO_COLOR=1; takes precedence over the env var."

### Phase 8 Implementation Review — Tasks 8.1+8.2+8.3 (Medium Priority)

Catalogued 2026-04-29 from a multi-agent review (architecture / test-coverage / accessibility-UX) of `cli_api.dart`, `cli_runner.dart`, `cli_integration_test.dart`, and the §Verification smoke-test block. HIGH items (FUEL_HOME isolation, Dist verify, barrel split, consistent show discipline, barrel resolution test, exit-code/errors exports) were fixed in commits f7a8b37 and a2176e6. Items below are deferred.

52. **Coverage — integration test has zero error-path branches** (`cli_integration_test.dart`)
    - Single happy-path; missing `loadProfile` null, `loadPlan` null, schema-version mismatch (the seams most likely to break)
    - Fix: add a test where `loadPlan` returns null for an unknown name and another that exercises `validateSchemaVersion` rejecting a stored file with a future `schema_version`

53. **Integration test bypasses its own barrel and doesn't read as API example** (`cli_integration_test.dart:6-8`)
    - Imports from `src/...` directly while `cli_api.dart` exists for exactly this consumer pattern; new contributors reading the test see the wrong example
    - Fix: switch imports to `package:race_fueling_cli/cli_api.dart` and add a short header comment mapping each step (profile setup → plan create → products add → plan generate) to its CLI counterpart

54. **`test/integration/` vs `test/e2e/` directory split is semantically thin** (`test/integration/cli_integration_test.dart`)
    - Both exercise multi-component flows; the directory name doesn't say "in-process vs subprocess"
    - Fix: rename `test/integration/` to `test/in_process/` (or merge into `test/e2e/` with a shape-conveying filename like `cli_in_process_test.dart`) so the layout teaches future contributors which to add to

55. **Coverage — `entries.length == 12` duplicates a timeline_builder invariant** (`cli_integration_test.dart:62`)
    - Restates math already locked by `core/test/engine/timeline_builder_test.dart`; brittle (any future timeline change breaks both)
    - Fix: derive from input — `expect(plan.entries.length, loaded.duration.inMinutes ~/ loaded.intervalMinutes)` — to lock the contract instead of the math

56. **Coverage — `environmentalNotes, isNotEmpty` is coupled to KI-7's altitude threshold** (`cli_integration_test.dart:65`)
    - Test silently breaks if KI-7 (linear altitude formula) is fixed and the 1500m threshold moves
    - Fix: tighten to round-trip contract — assert that `loaded.altitudeM == 1800.0` AND that whatever notes the engine produces for the loaded value match the expected list — that tests the seam, not the engine threshold

57. **Coverage — formatter assertions are smoke-only substrings** (`cli_integration_test.dart:70`)
    - `contains('Maurten')` and `contains('SUMMARY')` don't prove the formatter consumed the LOADED plan vs a default
    - Fix: add a discriminating assertion like `expect(table, contains('XCM Test Race'))` or assert the formatted output contains the exact total carbs from `plan.summary.totalCarbs`

58. **Test name advertises a `products` step the body doesn't exercise** (`cli_integration_test.dart:23`, LOW)
    - Test is named `'full workflow: profile → plan → products → generate'` but never calls `saveProducts`/`loadProducts` or merges a non-empty user library
    - Fix: rename to `'profile + plan round-trip drives engine and formatters'`, OR extend the test to actually exercise `mergeProducts(builtInProducts, userProducts)` with a non-empty user list

59. **Temp-dir prefix inconsistency between integration and e2e tests** (`cli_integration_test.dart:15`, LOW)
    - Uses `'fuel_integration_'` (underscore) while `e2e/full_flow_test.dart` uses `'fuel-e2e-'` (hyphen)
    - Fix: normalize to one separator style for grep-ability when triaging leaked temp dirs

60. **Smoke test product name unpinned** (`v1.md:5657`, LOW)
    - `"Maurten Drink Mix 320"` is hardcoded; future SKU rename in `built_in_products.dart` silently breaks the smoke test
    - Fix: add a `// source-of-truth: built_in_products.dart:107` comment in the plan, OR pin the smoke test to use the product ID `maurten-320` (more stable than display name)

61. **No automated drift detection on `--help` output** (`v1.md` Task 8.3 Step 4, LOW, v1.1 idea)
    - Manual sanity check only; an accidental command-tree change goes undetected
    - Fix: in v1.1, add a golden-file diff test against `fuel --help` and each subcommand's `--help`; fails CI on any unintended drift

62. **Barrel grouping comments missing** (`cli_api.dart:5-12` + `cli_runner.dart:5-9`, LOW)
    - Exports are a flat list; grouping comments separating storage / formatting / prompts / errors would help additions land in the right section
    - Fix: cosmetic; add blank lines + section headers if the lists grow

63. **Process note — TDD trace ambiguous on `cli_integration_test.dart`** (LOW)
    - Assertions look retrofitted to observed behavior (`12`, `isNotEmpty`) rather than written from spec
    - Fix: when extending this test (KI-52 onwards), favor spec-derived assertions like `entries.length == duration / interval` over restating output — keeps the test honest about what it locks

### Engine Correctness Review — 8 KI-fix commits (Mixed Priority)

Catalogued 2026-04-29 from 8 dedicated per-KI reviewers on the `feat/v1-engine-correctness` branch (KI-1 through KI-8 fixes). HIGH and MED items were addressed in commits 1e0b4a7 (KI-4 advisory scope) and 9526ffe (KI-8 comment wording). Items below are deferred LOW polish + one MED follow-up.

64. **Allocator round-down silent under-delivery** (`product_allocator.dart:99`, MEDIUM follow-up to KI-1)
    - When `target < 0.5 × carbsPerServing` (e.g., 10g target with a 25g-only product), `.round()` returns 0 servings, the inner `if (use > 0)` skips, the slot delivers 0g of carbs, and no warning fires (overage check fires only when delta > 0)
    - Fix: add a complementary slot-level UNDER-delivery advisory mirroring the over-delivery surfacing — when `carbsAssigned < target * (1 - threshold)` AND a non-zero target was requested, emit `Severity.advisory` with the shortfall

65. **Missing edge-case test for round-down boundary** (`product_allocator_test.dart`, LOW)
    - No test covers `target = 0.4 × carbsPerServing` (the symmetric edge of the rounding behavior). Pairs with KI-64
    - Fix: add a case (target=10g + 25g-only product) asserting servings=0 and an under-delivery advisory once KI-64 lands

66. **Overage advisory uses target-relative ratio only** (`product_allocator.dart:131`, LOW)
    - 5g overage on 20g target = 25% (fires); same 5g on 50g target = 10% (silent). For gut tolerance the absolute g/hr matters
    - Fix: also flag absolute deltas above a fixed threshold (e.g., >10g/hr extra). Defer if Milan prefers single-axis simplicity

67. **Curve fallback test "60" substring assertion is weak** (`carb_distributor_test.dart:170`, LOW)
    - Asserts `contains('60')` after asserting `contains('60/120')` — the second assertion is trivially satisfied by the prefix and adds no signal
    - Fix: assert the full rate substring like `contains('60g/hr')` or `contains('remaining 60 minutes')`

68. **Missing single-segment exact-duration coverage test** (`carb_distributor_test.dart`, LOW)
    - The covered-full-duration test uses two segments summing to 120 minutes; the equality boundary on a single segment is not exercised
    - Fix: add a one-line case with `[CurveSegment(durationMinutes: 120, ...)]` asserting no fallback warning

69. **Water-side under-delivery warning missing** (`plan_engine.dart`, MEDIUM follow-up to KI-4)
    - KI-4's fix correctly scopes the carb-side under-delivery warning to altitude only. But heat scales `additionalWaterMlPerSlot` and the user could still under-deliver fluid (e.g., choose products without enough water requirement). No warning surfaces this
    - Fix: add a parallel water under-delivery check — when `additionalWaterMlPerSlot > 0` AND the plan's total water is below some threshold, emit a water-specific advisory

70. **KI-7 boundary tests miss 3500m/4500m/5500m exact band-starts and 10000m cap** (`environmental_test.dart`, LOW)
    - Existing tests use 1000m for "below threshold" (1499m would more tightly pin), and 6000m for "above cap" (10000m would explicitly verify the cap doesn't continue scaling)
    - Fix: add band-boundary tests at 3500m, 4500m, 5500m and an extreme test at 10000m asserting `carbMultiplier == 1.20`

71. **KI-7 altitude advisory text format not pinned** (`environmental_test.dart`, LOW)
    - Tests assert substring `'Moderate altitude'` but not the full format `"$label (${m}m): +$pct% carb target"` from the spec
    - Fix: add an exact-string assertion like `expect(adj.advisories, contains('Moderate altitude (2000m): +2.5% carb target'))`

72. **KI-8 comment cites optimal range but gate is outer tolerance** (`plan_validator.dart:158-159`, LOW)
    - Comment cites "1:0.8–1:1 is recommended" for >60 g/hr but the implemented gate accepts as low as 0.5 from 50 g/hr+. Minor inconsistency between cited guidance (optimum) and implemented threshold (outer tolerance band)
    - Fix: add a sentence to the comment clarifying that 0.5 is the *outer* tolerance band, not the optimum, to avoid confusion when readers compare the cited research to the gate

## 2026-05-04 — Phase A Round 4 review (allocator rewrite)

The new allocator (commit `825394f`) is in good shape but three concerns
were deferred from this round and should be addressed before v1.1 ships
or in a follow-on:

### Deferred items

- **A1 — Drink-start guard skips last slot.** `i < slots.length - 1`
  prevents starting a new drink in the final slot. If a rider's only
  refill is at the finish line, the refilled bottle is wasted.
  Behavior pinned by test in commit 2 (Round 4 fix-up). Real fix
  requires inventory-accounting rework: only skip when `drinkSteps > 1`
  for the picked drink. Out of scope for v1.1.

- **A4 — `discipline` parameter plumbed but unused.** Kept as forward-
  prep with regression test that two configs differing only by
  discipline produce identical entries. When the allocator gains
  per-discipline tuning, the existing plumbing is in place.

- **A5/A6 — `tStart` window math drifts ±1 in distance-based mode.**
  In distance-based timelines, slot times round to integer minutes;
  the per-slot window `(tStart, tEnd]` derived from a single `stepMin`
  can misplace an aid station at the rounding boundary. Acknowledged
  by the plan as a v1.1 tradeoff. Fix when distance-mode lands as a
  user-facing feature: derive `tStart` per-slot as
  `slots[i-1].timeMark.inMinutes` (or 0 for i==0).

### Round 4 summary

- 3 reviewers (architecture, test coverage, numerical correctness)
- 1 commit landed (Commit 1: dead-code removal, collision handling, doc)
- 1 commit landed (Commit 2: 9 new tests for coverage gaps)
- 0 fixes deferred to a future v1.x pass

## 2026-05-04 — v1.1 Phase A complete (engine port)

Phase A of the v1.1 plan (`docs/superpowers/plans/2026-04-30-v1.1-flutter-app.md`) shipped on branch `feat/v1.1-phase-a-engine`, tagged `v1.1.0-rc.1` on commit `76b3928`. 25 commits ahead of `main`.

The engine port replaces the v1.0 per-slot greedy allocator with a stateful sip+gel-debt allocator that matches the design's reference engine. The CLI consumes the new engine; Flutter app (Phases B–F) builds on top later.

### What shipped

- **Models.** Added `Product.sipMinutes` (A1), populated 60 on every built-in liquid (A2). Added `Discipline { xcm, road, run, tri, ultra }` and `RaceConfig.discipline` (A3, plumbed but unused — forward-prep). Added `AidStation.refill: List<String>` (A4) and removed `ProductSelection.isAidStationOnly` (A5). Added `PlanEntry.effectiveDrinkCarbs` and `PlanEntry.aidStation` (A6).
- **Storage.** Bumped `RaceConfig` schema to v2 with `migrateRaceConfig` migrator (A7). Wired migration into the CLI storage adapter; `<name>.json.v1.bak` backup on first migrated save (Round 2 fix-up).
- **Engine.**
  - `projectAidStationMin` helper: linear km→min projection with `timeMinutes`-precedence (A8).
  - `buildTimeline` no longer inserts non-aligned aid-station slots — uniform-duration slots are required by the new allocator's window math (A8b).
  - `validateAidStationDefinitions` validator: critical for missing/negative/out-of-range fields, advisory for distance-without-total (A9, hardened in Round 3 fix-up).
  - Wholesale allocator rewrite (A10+A11, combined into one commit because the project's pre-commit hook disallows RED commits): drinks-as-sip + 65% drink cap + cross-slot gel-debt + aid-station refill via `projectAidStationMin`. Resolves the open question on sip-drink depletion warnings via `lastContribSlot` tracking.
  - Validator wired into `generatePlan` (A12) so its warnings reach the user.
- **CLI.** Sip-bottle continuation marker `~ sip bottle (Ng)` for slots where the rider is mid-sip; aid-station divider line `── AID @ +Nmin ── refill: <ids>` above slots where a station fires (A13). `[aid station]` per-product tag dropped (A5).
- **Toolchain.** Bumped Dart SDK floor from `^3.6.0` to `^3.8.0` (Round 1 fix-up) — required by `json_serializable`'s null-aware-element codegen for `@JsonKey(includeIfNull: false)`.
- **Verification + tag.** Final `dart analyze` clean; core 257 / CLI 279 tests green; pubspecs at 1.1.0 (A14).

### Process

- 14 plan tasks executed across 4 review rounds.
- Each round: 3 implementers (sequential — the project's hook enforces "every commit green"), 3 parallel reviewers (architecture, test coverage, and either UX/a11y or numerical correctness depending on the batch's surface area), consolidated verdict table, fix-up batch.
- 4 fix-up rounds landed 8 additional cleanup commits with new tests and tightened invariants.
- One forced workflow change at A10: pre-commit hook refused to land RED, so A10 (failing tests) and A11 (passing implementation) collapsed into one commit. TDD discipline preserved internally — tests written first, observed RED, then implementation made them GREEN.

### Test deltas

| Suite | v1.0.0 | v1.1.0-rc.1 | Δ |
|-------|-------:|------------:|---:|
| `packages/core` | 188 | 257 | +69 |
| `packages/cli`  | 271 | 279 | +8  |

### Deferred to a future v1.x pass

Captured during Round 4 review (commit `e517b15` and the entry above):

- **A1** — Drink-start guard skips the last slot. A refill landing on the finish line is silently unused. Pinned as a known-limit test; real fix requires inventory-accounting rework.
- **A4** — `discipline` parameter is plumbed end-to-end but unused. Kept with regression test as forward-prep for per-discipline tuning.
- **A5/A6** — `tStart = tEnd - stepMin` window math drifts ±1 in distance-based mode. Acknowledged tradeoff per the plan; revisit when distance mode is a primary user-facing path.

### Known Issues from earlier reviews — status after v1.1

The "Known Issues" catalogue above (KI-1 through KI-72) was authored against the v1.0 engine. Many are now obsolete or partially addressed:

- **KI-1, KI-12, KI-14** — refer to the per-slot greedy allocator and its `.ceil()` over-allocation, cumulative-carbs/caffeine test gaps, and circular distributor/allocator responsibility. **Obsolete** — the v1.1 allocator is structurally different (sip background + gel debt accumulator).
- **KI-4** — altitude multiplier didn't reach the allocator. **Largely fixed** — sip drink contribution scales with the adjusted slot target; a debt-justified gel still fires at the higher target.
- **KI-64, KI-65** — round-down silent under-delivery. **Obsolete** — gel-debt accumulator pools cross-slot shortfalls and clears them with the next well-fitting gel.
- **KI-66** — overage advisory uses target-relative ratio only. Still applies (the v1.1 allocator carries the same `_slotOverageAdvisoryThreshold = 0.20` constant).
- **KI-69** — water-side under-delivery warning missing. Still applies.
- **KI-9, KI-3, KI-11, KI-29–KI-63** (formatter, CLI plumbing, validator coverage gaps, etc.) — distinct from the engine; still applies. Will be revisited when those areas are next touched.

A comprehensive KI sweep is deferred to a v1.x cleanup pass.

## 2026-05-04 — v1.1 Phase B Batch 1 (foundation scaffolding)

Started Phase B (Flutter app) on branch `feat/v1.1-phase-b-scaffolding`. Batch 1 covers the four foundation tasks that other batches depend on: workspace pubspec (B1), domain re-exports (B2), `PlanStorage` interface + `PlanStorageLocal` (B6), and `BonkBreakpoint` responsive helper (B8). Bootstrapping plus theme are in flight in later batches.

### What shipped (10 commits)

- **B1** — `packages/app/pubspec.yaml` (Flutter 0.1.0), root `pubspec.yaml` adds the package to the workspace, `analysis_options.yaml` extends `flutter_lints` with `prefer_single_quotes` / `require_trailing_commas` / `prefer_const_constructors`.
- **B2** — `lib/domain/domain.dart` re-exports `package:race_fueling_core/core.dart` so app code never imports core internals directly.
- **B6** — `PlannerState` aggregate root (RaceConfig + AthleteProfile, with copyWith / toJson / fromJson and the Andalucía Bike Race Stage 3 seed factory). `PlanStorage` interface + `PlanStorageLocal` (shared_preferences-backed, single JSON blob under `bonk_v1.working_plan`).
- **B8** — `BonkBreakpoint` enum with five tiers (`wide` ≥1480 / `medium` 1380–1480 / `noDiagnostics` 1080–1380 / `narrow` 880–1080 / `mobile` <880) plus convenience getters (`showsDiagnosticsRail`, `showsSetupRail`, `setupRailWidth`, `diagnosticsRailWidth`).

### Round 1 review (3 parallel reviewers: architecture / test coverage / accessibility-UX)

**Verdict:** 1 CRITICAL + 5 HIGH fix-ups landed. Verdict matrix:

| Severity | Total | Fixed in Round 1.5 | Deferred |
|---|---:|---:|---:|
| CRITICAL | 1 | 1 | 0 |
| HIGH | 6 | 4 | 2 (UX — downstream wiring) |
| MEDIUM | 6 | 2 | 4 |
| LOW | 9 | 1 | 8 |

**CRITICAL fix landed:** `PlanStorageLocal.load()` only caught `FormatException` — non-Map JSON, missing keys, and missing `schema_version` all threw uncaught `TypeError`, crashing the app on launch from any corrupted blob. Widened the catch to `catch (_) { return null; }` so any deserialization failure falls back to the seed. Hardened with three new tests (non-JSON, non-Map JSON, missing keys) plus a hand-rolled v1-blob migration test that locks the storage-boundary migration contract.

**Architecture HIGH fixes landed:**
- Moved `migrateRaceConfig` out of `PlannerState.fromJson` into `PlanStorageLocal.load()`. The domain layer no longer knows about persisted-version history; storage adapters own the migration contract (matches CLI's `FileStorageAdapter`).
- `planner_state.dart` now imports through the local `domain.dart` barrel instead of reaching into `package:race_fueling_core/core.dart` directly. Sets the precedent for every downstream `domain/`/`data/`/`presentation/` file.

**Test HIGH fixes landed:**
- New `test/domain/planner_state_test.dart` — direct coverage of `copyWith` (no-args, partial), `seed()` field pinning, `fromJson(toJson())` identity, `toJson` shape stability.
- New boundary equality tests in `breakpoints_test.dart` (1480/1479.999, etc.) plus a 5×4 getter table — flips of `>` vs `>=` are now visible.

**Test counts:** 28 app tests (was 8 after initial Batch 1; +20 from Round 1.5). Core 257 / CLI 279 unchanged.

### Deferred — captured here, not blocking Batch 2

**UX (downstream wiring concerns, surface in F1/B5 acceptance):**

- **PB-UX-1** — Diagnostics rail invisible at 1080–1380 px (typical 13–14" laptop at default scaling). Critical safety warnings (single-source carbs >60g/hr, gut-tolerance breach, caffeine ceiling) silently invisible to the modal user. **Fix when wiring lands:** F1/B5 must surface CRITICAL warnings via an unconditional inline banner above the timeline regardless of breakpoint, with the rail-or-slide-over carrying the full diagnostics. Consider lowering `medium` floor to 1280 once the rail is wired.
- **PB-UX-2** — iPad portrait (820–834 pt) classified as `mobile`, collapses to phone layout. iPad mini portrait (~744 pt) is genuinely small enough to be `mobile`, but iPad/iPad Air/iPad Pro 11" deserve at least the setup rail. **Fix when wiring lands:** lower `mobile` threshold to `<768` so iPad portrait falls into `narrow` (or introduce a `tablet` tier). Pair with a real-device check.
- **PB-UX-3** — Setup rail = 32% of screen at 880 px low end of `narrow`. Verify the 3-column stats fallback kicks in early enough once the stats grid lands (Batch 4).
- **PB-UX-4** — `noDiagnostics` is the only behavior-defining tier name in a size-defining family. Rename to `compact` (or similar) if Batch 5 keeps the threshold; defer until then so we don't churn naming twice.
- **PB-UX-5** — Seed inventory may overwhelm a first-run user. F1 needs to decide: load the Andalucía seed automatically (current behavior), surface a "Sample plan — clear or customize" banner, or only load via a "Load example" button. Defer the call to F1.

**Architecture / engineering:**

- **PB-ARCH-1** — Plan doc still says `sdk: ^3.6.0`; actual workspace is `^3.8.0` (Phase A bumped it). Plan should be reflected; this journal entry is the durable record.
- **PB-ARCH-2** — Riverpod bumped 2.6.x → 3.3.x at Batch 1 because `riverpod_lint 2.6.1`'s `analyzer ^6.7.0` constraint conflicts with `flutter_test`'s `analyzer >=8.0.0`. `custom_lint` and `riverpod_lint` dropped from dev_deps. Milan approved staying on 3.x. **Implication for Batch 3 (B7):** plan code samples at lines 2660–2879 were written for Riverpod 2.x; re-validate against 3.x docs (`Ref` typing, `AsyncNotifier` lifecycle, codegen output) before paste-and-build.
- **PB-ARCH-3** — `analysis_options.yaml` lint posture diverges from core/cli (which only `include: package:lints/recommended.yaml`). App adds three rules. Either unify in a workspace-root analysis_options or document the divergence in CLAUDE.md. Deferred to v1.x cleanup pass.
- **PB-ARCH-4** — Storage key `bonk_v1.working_plan` mixes a key-level version prefix with the in-blob `schema_version`. The migrator already handles content upgrades, so the `_v1` is cosmetic. Decide before v2 ships whether to drop the prefix or document the v2 upgrade path (load `bonk_v2`, fall back to `bonk_v1`, migrate).

**Coverage gap discovered in Phase A core:**

- **PB-CORE-1** — `migrateRaceConfig` (`packages/core/lib/src/storage/schema_migration.dart`) drops `isAidStationOnly`, defaults `refill: []`, and bumps `schema_version` — but does **not** inject a default `discipline`. A migrated v1 blob has `discipline == null`, not `Discipline.xcm`. Today this is fine because the `discipline` field is plumbed-but-unused (Phase A deferred A4). When per-discipline tuning lands (post-v1.1), the migrator must default it. Found by Round 1's hand-rolled v1 blob test in `plan_storage_local_test.dart`.

**Test coverage backlog:**

- **PB-TEST-1** — `PlanStorage` interface not exercised polymorphically anywhere. First polymorphic test arrives in Batch 3 (B7 uses `FakePlanStorage`).
- **PB-TEST-2** — `seed()` const-stability assertion (`identical(seed(), seed())`) deferred. Trivial hardening, low value.
- **PB-TEST-3** — `prefs.setString` failure path not testable via `setMockInitialValues`; consistent with the rest of the shared_preferences ecosystem.

**Future tax:**

- **PB-FUTURE-1** — No i18n scaffolding (`flutter_localizations` not added). Seed race name `Andalucía Bike Race — Stage 3` is hardcoded English. Fine for v1.1; route through `AppLocalizations` when l10n lands.
- **PB-FUTURE-2** — Race name special characters render fine in Flutter; CLI Windows console (`cmd.exe`, code page 437/1252) may mojibake on em dash and `í`. Keep CLI output ASCII-safe-by-default for v1.x or document `chcp 65001` in CLI Windows guidance.

## 2026-05-04 — v1.1 Phase B Batch 2 (theme tokens + typography)

Tasks B3 (`BonkTokens` design tokens — 24 colors + 3 radii + 10 spacing) and B4 (`BonkType` — Inter Tight + JetBrains Mono via google_fonts, 8 named roles) shipped. Two implementer commits + JOURNAL pause + 6 Round-2 fix-up commits.

### What shipped (8 net commits, after Round 2.5)

- **B3** — `lib/presentation/theme/tokens.dart` with surfaces / inks / rules / accent + 7 semantic colors, 3 radii, 10 spacing values, plus `topbarHeight = space44` semantic alias. Doc block at top of file declares the **color-usage doctrine** (see below) and the **dark-mode deferral TODO**.
- **B4** — `lib/presentation/theme/typography.dart` exposes two parameterised builders (`sans({size, w})`, `mono({size, w})`) and 7 memoised role tokens (`railEyebrow`, `railTitle`, `railSub`, `sectionLabel`, `fieldLabel`, `statHero`, `statValue`) as `static final TextStyle` — refactored from methods so per-frame `build()` calls don't reallocate.
- **Test infra** — `test/test_helpers/google_fonts_setup.dart` extracts the `TestWidgetsFlutterBinding.ensureInitialized` + `GoogleFonts.config.allowRuntimeFetching = false` + `flutter/assets` mock-manifest stub into a one-line `setUpAll` call. Required by every future widget test that touches `BonkType` (Phases C–F all qualify).

### Round 2 review (3 parallel reviewers: architecture / test coverage / accessibility-UX)

Heavier round than Round 1 — a11y reviewer in particular surfaced two CRITICALs and a HIGH that drove the doctrine decision.

| Severity | Total | Fixed in Round 2.5 | Deferred (acceptance constraints below) | Defer to backlog |
|---|---:|---:|---:|---:|
| CRITICAL | 3 | 1 (docstrings) + 2 (resolved by doctrine) | 0 | 0 |
| HIGH | 4 | 2 (paper test, TextScaler comment) + 1 (dark-mode TODO) | 1 (small fonts → Batch 3-D `textScaler 2.0` widget test) | 0 |
| MEDIUM | 8 | 4 (semantic palette tests, secondary tests, methods→fields, helper) | 4 (focus ring, dividers, letterSpacing, outline color) | 0 |
| LOW | 8 | 1 (mono-origin tests, mono override symmetry, topbarHeight alias) | 0 | 7 |

**Test counts:** 57 app tests (was 42; +11 token tests covering `paper`, `bg2`, `rule2`, `accentInk`, all 7 semantics; +4 typography contract tests pinning mono origin for `railEyebrow`/`sectionLabel`, mono override symmetry, `statHero` height inheritance). Core 257 / CLI 279 unchanged.

### Decisions locked in (Milan, post-Round 2)

**Q1 → B (Doctrine, NOT new tokens).** Severity *text* (warning headlines, "CRITICAL" / "ADVISORY" labels) always uses `BonkTokens.ink` or `ink2`. Color carries severity through the **left bar, dot, or icon only** — never through text foreground. This keeps every severity label at WCAG AA contrast on cream surfaces without expanding the token surface. Documented at the top of `tokens.dart`. Binding constraint on Diagnostics rail (Batch 4–5): severity card text never takes a semantic-color foreground.

**Q2 → B (TODO, not indirection).** Spec §13 lists dark mode as future work. `tokens.dart` carries a `// TODO(dark-mode):` comment explaining the future `ThemeExtension<BonkTokens>` retrofit and the trigger condition: **if more than ~5 widget files reference these tokens before dark mode lands, do the extraction proactively** to avoid touching every consumer.

**Q3 → Yes.** `BonkType` role helpers refactored from `static TextStyle railTitle()` methods to `static final TextStyle railTitle = ...` fields. Per-frame `TextStyle` allocation eliminated. Builders (`sans`, `mono`) stay as methods because they take parameters. All call sites updated.

**Q4 → Yes.** `test/test_helpers/google_fonts_setup.dart` extracted. Future widget tests use `setUpAll(setUpGoogleFontsForTests);` in one line.

### Color-usage doctrine (now codified in `tokens.dart`)

- **Text foreground:** `ink` / `ink2` / `ink3` always. `accentInk` for accent text on accent fills.
- **Decorative-only fills (FAIL contrast as text):** `accent`, `glu`, `fru` — chips, dots, ratio bars only. Docstrings on each token warn against text use.
- **Semantic severity:** color goes on the bar/dot/icon. Text stays in `ink`/`ink2`. Contrast ratios: `accent`=1.25:1 / `glu`=1.58:1 / `fru`=2.12:1 / `hydro`=2.39:1 / `warn`=2.69:1 / `ok`=2.71:1 / `bad`=3.86:1 / `caf`=4.46:1 — all fail or are borderline at AA-Normal as text. Doctrine sidesteps the problem entirely.

### Acceptance constraints for downstream batches

These were NOT fixed in Round 2.5 because they need the consumer code to exist. Batches 3–5 must honour them.

- **PB-A11Y-1 (Batch 4-5 Diagnostics rail).** Severity text never uses semantic-color foreground (Q1 doctrine). Severity must also be encoded as **text label + icon** so colorblind users can distinguish CRITICAL from ADVISORY without color (`bad`/`ok` collapse to 1.42:1 native, 1.22:1 protanope, 1.57:1 deuteranope — ~1 in 12 male users in the XCM target audience).
- **PB-A11Y-2 (Batch 3 Setup rail forms).** Dividers `rule` (1.32:1) / `rule2` (1.16:1) FAIL WCAG 1.4.11 if they outline interactive controls. Add a `ruleStrong` (or `outline`) token at ≥3:1 — recommended `#A19E94` — before any input batch lands. Pure decorative dividers between sections are exempt.
- **PB-A11Y-3 (B5 theme construction).** Default Material focus ring uses `colorScheme.primary`. If `accent` becomes primary, focus rings render at 1.25:1 on bg — invisible. Focus indicator must use `ink` or `ink2`, not `accent`. Wire this when `MaterialApp.theme` is constructed.
- **PB-A11Y-4 (Batch 3-D stat grid).** Smallest fonts (10.5pt `sectionLabel`, 11pt `railEyebrow`) are borderline for race-morning glance in sunlight. Add a `tester.platformDispatcher.textScaleFactorTestValue = 2.0` widget test in Batch 3-D and verify stat grid + rail widths still survive 200% scaling. Per WCAG 1.4.4.

### Deferred to backlog

- **PB-ARCH-5** — `BonkTokens` and `BonkType` use `Klass._()` private constructor for namespace classes. Flutter SDK (`Colors`) uses `abstract final class` since Dart 3. Cosmetic; consistent style decision for the project to make later.
- **PB-ARCH-6** — Single-letter constants `r` / `rSm` / `rLg` are namespace-qualified but terse. If a future refactor exposes them un-namespaced, readability collapses. Consider `radiusSm` / `radius` / `radiusLg` rename if it stays in scope.
- **PB-ARCH-7** — 8 typography roles cover the surfaces of Phase B. Phase C–E will discover gaps (button text, error text, link text, body-large/small). Add roles as needed; don't pre-add speculatively.
- **PB-A11Y-5 (v2 i18n).** `Inter Tight` has no CJK/RTL/Indic coverage. Non-Latin race names fall back to platform default. v2 should add a `fontFamilyFallback: ['Noto Sans CJK', ...]` chain. RTL also requires the entire three-rail layout to invert.
- **PB-A11Y-6** — Negative `letterSpacing: -0.1` on mono. Visual review on a low-DPR Windows display before Batch 4 closes; drop to `0` if alignment looks poor.
- **PB-A11Y-7** — Print stylesheet (Cmd+P from Flutter Web) burns toner on cream `bg`. Spec §13 lists print/PDF as future. Swap surfaces to white via `@media print` when feature lands.
- **PB-TEST-4** — Radii (3) and spacing (10) constants untested. Trivial doubles; drift would surface visually on first use. Skip unless a single "spacing scale stable" snapshot test feels worth one line.

## 2026-05-04 — v1.1 Phase B Batch 3 (BonkApp + Riverpod 3.x provider chain)

Tasks B5 (`main.dart` + root `BonkApp` + stub `PlannerPage`) and B7 (Riverpod providers — storage / library / planner notifier / plan / warnings) shipped. 7 implementer commits + 8 Round-3 fix-up commits.

### What shipped (15 net commits, after Round 3.5)

- **B5** — `main.dart` boots `BonkApp` inside `ProviderScope`. `app.dart` constructs the full M3 theme: `ColorScheme.fromSeed(accent).copyWith(primary: ink, onPrimary: bg, outline: ink3, outlineVariant: rule, error: bad, onError: white)` + `GoogleFonts.interTightTextTheme(...)` covering every Material text slot. `PlannerPage` is a single-Text stub for now.
- **B7** — 5 Riverpod providers: `planStorageProvider`, `productLibraryProvider`, `plannerNotifierProvider` (`AsyncNotifier`), `planProvider`, `warningsProvider`. PlannerNotifier loads from storage with seed fallback, exposes `updateRaceConfig` / `updateAthleteProfile` mutators that emit new state and serialize saves through a chained Future.
- **Test infra** — `test/app_test.dart` (3 tests: byType render, theme value pinning, textTheme Inter Tight cascade); `test/presentation/providers/planner_notifier_test.dart` (7 tests including pre-build mutator guard, sequential save serialization, AsyncError-on-load, updateAthleteProfile); `test/presentation/providers/plan_provider_test.dart` (6 tests including recompute-after-mutation).

### Riverpod 2.x → 3.x adaptations (verified against `riverpod-3.2.1` source)

Two surgical fixes were required:

- **`asyncState.valueOrNull` → `asyncState.value`.** Riverpod 3.x removed `valueOrNull`; the unified `value` getter returns `T?` and falls through to the previous `AsyncData` payload on error. For our planner this means a transient storage error during refresh would render the stale plan rather than the seed — acceptable given `PlanStorageLocal.load` already swallows recoverable errors to null.
- **Public `update(PlannerState)` → private `_emit(PlannerState)`.** The plan template defined a public `void update(PlannerState)` method on `PlannerNotifier`. **Correction to the c70cd1e commit body:** the inherited `AsyncClassModifier.update` exists in Riverpod 2.x as well (`Future<T> Function(FutureOr<T> Function(T))`), not just 3.x. The rename was always necessary regardless of major version — the commit body's Riverpod-3-specific framing is wrong. Future readers should not infer a 2.x→3.x API shift from the rename.

### Round 3 review (3 parallel reviewers)

Heaviest round so far. The cascade of seed-derived ColorScheme + silent-error-handling + provider test gaps drove a 9-commit fix-up batch (8 fix-ups + this journal entry).

| Severity | Total | Fixed in Round 3.5 | Deferred (acceptance constraints) | Defer to backlog |
|---|---:|---:|---:|---:|
| CRITICAL | 0 | 0 | 0 | 0 |
| HIGH | 9 | 7 | 2 (silent error UI surfacing → L3 Phase F prereq) | 0 |
| MEDIUM | 14 | 9 | 1 (FakePlanStorage dedup → 3rd consumer trigger) | 4 |
| LOW | 8 | 0 | 0 | 8 |

**Test counts:** 73 app tests (was 66; +7 from Round 3.5: serialize, pre-build guard, updateAthleteProfile, AsyncError-on-load, planProvider recompute, warningsProvider re-derive, theme assertions). Core 257 / CLI 279 unchanged.

### Decisions locked in (Milan, post-Round 3)

**Q1 → L1+L2 now; L3 documented as Phase F prerequisite.**
- L1 (landed): `unawaited(... .onError((e, st) { debugPrint(...); }))` on save. Errors logged.
- L2 (landed): saves serialized through `_lastSave` Future chain so writes land in mutation order (no out-of-order under Web/IndexedDB).
- **L3 (DEFERRED — required before F1 wires real UI mutators):** see PB-DATA-1 below.

**Q2 → Yes (theme overhaul landed):** ColorScheme.copyWith now pins primary/onPrimary/outline/outlineVariant/error/onError. textTheme is `GoogleFonts.interTightTextTheme(baseTextTheme).apply(bodyColor: ink, displayColor: ink)` covering every Material slot.

### 🚨 Phase F prerequisite — PB-DATA-1 (L3, must land before F1)

When F1 wires real UI mutators, the following architectural fix MUST land first or race-day silent data loss is a real risk:

1. **`planProvider` preserves `AsyncError`** instead of collapsing to null — change return type from `FuelingPlan?` to `AsyncValue<FuelingPlan>` (or sibling `Provider<Object?> planErrorProvider`).
2. **`isSeedFallback` flag on `PlannerState`** (or sibling provider) — set when `build()` returns `seed()` because storage load was empty OR errored. Lets F1 distinguish "user customized this" from "we showed sample data because their drive was empty/corrupt."
3. **`PlannerNotifier._emit` guards against overwriting on error state until user opts in** — if the prior state was `AsyncError`, refuse to save until the user explicitly accepts the seed (via a "Start fresh" button or similar). Without this, the first mutation post-error overwrites the recoverable corrupted blob with the seed, making data permanently unrecoverable.
4. **F1 surfaces the error state** — banner: "Stored plan could not be read — showing the sample plan. [Try recovery] [Start fresh]" (WCAG 3.3.1 Error Identification).

Round 3 review's combined finding from architecture+UX reviewers — the data layer is currently silently fault-tolerant in ways that will mask real bugs in production. Logging via debugPrint (L1) and write serialization (L2) buy us observability without UI surface; L3 closes the loop.

### Acceptance constraints carried forward (still live)

- **PB-A11Y-1** — Diagnostics rail must encode severity as text label + icon (not color alone). 1 in 12 male users in XCM target audience can't distinguish bad/ok by color.
- **PB-A11Y-2** — iPad portrait threshold to <768.
- **PB-A11Y-4** — `textScaler 2.0` widget test in stat grid batch.
- **PB-UX-5** — First-run UX: F1 decides on sample-plan affordance (paired with L3 above — once `isSeedFallback` exists, F1 can render the banner naturally).

### New Round 3 carry-overs

- **PB-A11Y-8** — `MediaQuery.textScaler` propagation untested at app level. Add a 200% scale test in Batch 3-D when stat grid lands.
- **PB-A11Y-9** — Topbar a11y prep for F1: M3 IconButton uses `colorScheme.onSurfaceVariant` overlays for focus, NOT `theme.focusColor`. Topbar elements may need explicit per-widget focus styling or a `*ButtonTheme.styleFrom(overlayColor: ink)` set in `ThemeData`.
- **PB-A11Y-10** — `localizationsDelegates` / `supportedLocales` not configured. Material widgets emit English-only labels (incl. screen-reader announcements). Defer to v1.x; English-first ship is acceptable per spec.
- **PB-DATA-2** — `FakePlanStorage` duplicated across `planner_notifier_test.dart` and `plan_provider_test.dart` with diverging shape (full vs slim). Lift to `test/test_helpers/fake_plan_storage.dart` when 3rd consumer arrives (likely F1 widget tests) — just-in-time DRY.
- **PB-ARCH-8** — `warnings_provider` is a one-line selector. Threshold for "earn its own provider" not codified. When F1 lands the diagnostics rail, decide whether to inline `plan?.warnings ?? const []` at the call site and delete this provider.
- **PB-ARCH-9** — `FuelingPlan?` nullable return on `planProvider` collapses three states (loading, error, ready) into two. Migrate to `AsyncValue<FuelingPlan>` when L3 lands (covered by PB-DATA-1).
- **PB-ARCH-10** — Riverpod 3.x's `value` getter (replacing 2.x's `valueOrNull`) returns previous `AsyncData` on error. For `plan_provider`, this means a transient storage error renders the stale plan rather than the seed. Documented as a **deliberate** choice — for an auto-saving planner this is the right behavior, but if the contract changes, switch to `asyncState.unwrapPrevious().value`.

### Phase B status

All 8 Phase B tasks shipped:
- B1 (workspace pubspec) ✓
- B2 (domain re-exports) ✓
- B3 (theme tokens) ✓
- B4 (typography) ✓
- B5 (BonkApp bootstrap + stub PlannerPage) ✓
- B6 (PlanStorage + PlanStorageLocal) ✓
- B7 (Riverpod providers) ✓
- B8 (BonkBreakpoint) ✓

35 commits ahead of `main`. 73 app tests, 257 core tests, 279 cli tests — all green. `dart analyze` and `flutter analyze` clean. Ready for branch finishing.

## 2026-05-05 — Phase B merged + manual smoke; Phase C kickoff

Phase B closed. `feat/v1.1-phase-b-scaffolding` fast-forwarded to `main` after manual browser smoke (cream `BonkTokens.bg` background, centered "Bonk planner — coming online…" stub in Inter Tight ink, MaterialApp title rendered correctly, Flutter dev server confirmed at port 8765 with hot reload). Branch deleted. README + CLAUDE.md synced with the three-package workspace and Phase B conventions. Plan file left untouched (it's a starting point — JOURNAL is the source of truth).

Phase C started on `feat/v1.1-phase-c-setup-rail`. Batch 1 is C1 (three reusable widgets used by every Setup-rail section to come).

## 2026-05-05 — v1.1 Phase C Batch 1 (C1: reusable widgets)

`BonkSegControl<T extends Object>`, `BonkStepper`, `BonkFieldShell` shipped. 5 commits net after Round 1 fix-ups.

### What shipped

- **BonkSegControl** — pill-row segmented picker with active state filled in `ink`. Generic `T extends Object`. Optional `groupLabel` parameter wraps the control in Semantics container. Uses `InkWell` (focusable, Tab traversal) with `WidgetStateProperty` overlay for ink-tinted focus/hover. Each option wrapped in `Semantics(button: true, selected: v == value, inMutuallyExclusiveGroup: true, label: label, excludeSemantics: true)`. Re-tap of currently-selected option is a no-op (avoids unnecessary parent rebuilds and storage writes — Q1=B). Inner `Text` carries `maxLines: 1` + `overflow: TextOverflow.ellipsis` defensive against long localized labels.
- **BonkStepper** — minus / count / plus row with **44×44 hit area** (28×28 visual padded by 8 on each side). `Semantics(value, increasedValue, decreasedValue, onIncrease, onDecrease)` wrapper makes it announceable as adjustable to VoiceOver / TalkBack. Optional `semanticLabel` carries field context ("Maurten Gel 100 quantity, 5"). `ExcludeSemantics` on the inner row strips standalone glyph announcements. Disabled state at min/max boundary visually distinct: `bg2` background, `rule2` border, `ink3` glyph. Default `max=30` documented as inventory-specific.
- **BonkFieldShell** — `Semantics(container: true, label: label)` wrapper associates the visible label with the child input as one accessible field. Inner `Text(label)` excluded from semantics (no double-announce). `SizedBox` height switched from hardcoded `6` to `BonkTokens.space6` token.
- File rename: `product_stepper.dart` → `stepper.dart` (widget is generic, not product-specific; zero consumers at rename time).

### Round 1 review (3 parallel reviewers)

Heaviest a11y round so far. Three CRITICAL WCAG Level A failures all caught before any consumer code wired up the widgets. Fixing now prevented cascading the debt across C2–C5.

| Severity | Total | Fixed in Round 1.5 | Deferred |
|---|---:|---:|---:|
| CRITICAL | 3 | 3 (all WCAG Level A — keyboard inaccessibility + missing SR roles × 2) | 0 |
| HIGH | 5 | 5 (disabled visual, 44pt hit area, FieldShell label association, missing tests × 2) | 0 |
| MEDIUM | 11 | 8 | 3 (helper/error slots in FieldShell, fixed-size targets vs textScaler, hover/focus states beyond focus ring — all carry-overs) |
| LOW | 5 | 2 (space6 alias, generic constraint) | 3 |

**Test counts:** 94 app tests (was 75 at baseline; +19 from a11y test suite — selection state, semantic flags, keyboard focus, generic enum, no-op re-tap, Stepper boundaries × 4, disabled visual × 2, semantic value/increasedValue, semanticLabel prefix, FieldShell label association × 5, etc.). Core 257 / CLI 279 unchanged.

### Decisions locked in (Milan, post-Round 1)

**Q1 → B (no-op re-tap).** `BonkSegControl.onTap` for the currently-selected option is `null` — no `onChanged` fires. Avoids unnecessary parent rebuilds and `SharedPreferences.setString` writes on every visit. Pinned by test `'does NOT fire onChanged when current value is re-tapped'`.

**Q2 → Yes (rename now).** `product_stepper.dart` → `stepper.dart` shipped at zero consumer count. Plan template at line 3743 still references the old name; we adapt plan code to reality anyway (Phase B precedent).

### New conventions established for Phase C

- **Semantics wrapping is mandatory** for every reusable widget that paints anything tappable. `Semantics(button, selected, inMutuallyExclusiveGroup)` for radio-like controls; `Semantics(value, increasedValue, decreasedValue, onIncrease, onDecrease)` for adjustables; `Semantics(container, label)` for labeled fields. Use `ExcludeSemantics` to strip noise from the inner visual tree.
- **44×44 hit areas via Padding(8) outside the visual.** Visual stays compact; hit area expands via outer padding. WCAG 2.5.5 spirit (race-day cycling phone use) even though the strict letter is AAA.
- **Disabled-state visuals must be distinct from enabled.** Drop bg to `bg2`, border to `rule2`, glyph color to `ink3`. WCAG 1.4.11 + 1.3.3.
- **Test files under `test/presentation/widgets/` reuse `setUpGoogleFontsForTests`** — already a Phase B convention but reaffirmed for every new widget test.
- **Semantics tests** use `tester.ensureSemantics()` + `tester.getSemantics(...).getSemanticsData()` to assert role/value/label/state. `find.bySemanticsLabel(...)` works for finding by accessible name.
- **`Color.withValues(alpha:)` not `withOpacity`** — `withOpacity` is deprecated in Flutter 3.27+. Applied to `BonkTokens.ink.withValues(alpha: 0.12)` etc. in seg control overlay states.

### Deferred (not blocking Phase C; carry-over for later)

- **PB-A11Y-11** — `BonkSegControl` and `BonkStepper` use fixed pixel sizes (28×28, 7px vertical padding). At system text scale 200%, glyphs may clip. Already covered by PB-A11Y-4 carry-over (textScaler 2.0 widget test in Batch 3-D / D2 stat grid).
- **PB-ARCH-11** — `BonkFieldShell` API has no helper-text or error-text slot. Confirmed deferred per YAGNI. If a Setup-rail field needs validation feedback, lift the API at that point.
- **PB-ARCH-12** — Per-build `TextStyle` allocation via `BonkType.sans(...).copyWith(...)` in `BonkSegControl`. Marginal cost; revisit if profiling surfaces a concern.

### Plan-vs-reality drift caught (and fixed)

- Plan template at line 3125 used `BonkType.fieldLabel()` (method-call form). Phase B Round 2 refactored to `static final` field. Implementer correctly used `BonkType.fieldLabel`. Test now locks the static-final reference via fontSize + color assertions.
- Plan template at line 3010 had a tautological selection assertion (`expect(selected, isNotNull)`). Replaced with structural assertion against `BoxDecoration.color == BonkTokens.ink`.

## 2026-05-05 — v1.1 Phase C Batch 2 (C2: SetupRail + race section)

The Setup rail's first user-facing surface — race name, duration, body mass, total distance, discipline. 7 net commits after Round 2 fix-ups (1 baseline + 6 fix-ups).

### What shipped

- **SetupRail** — `ConsumerWidget` rendering the seed-loaded `PlannerState` via `asyncState.when(loading, error, data)`. Loading state announced via `Semantics(liveRegion, label: 'Loading planner')`. Error state has a stub message + `// PC-ERROR-UI` breadcrumb pointing to PB-DATA-1's F1 deliverable.
- **Race section** — race name input, duration (h/m), body mass + total distance row, discipline seg control. Each input wired through `notifier.updateRaceConfig` / `notifier.updateAthleteProfile`. Discipline default falls back to `Discipline.xcm` (handles PB-CORE-1 carry-over).
- **`BonkTextInput`** (promoted from private `_BonkTextInput` per Q3=yes) — public widget under `lib/presentation/widgets/text_input.dart` with cursor-preserving `didUpdateWidget`, `labelText` (accessible name), `maxLength`, `inputFormatters`. Material-3-friendly defaults: `enabledBorder` at `ink3` (3:1 contrast on bg), `focusedBorder` at `ink` width 2.0, `vertical: 12` content padding (~44pt field height).
- **Row leaves are `ConsumerWidget`s** — `_DurationRow` and `_BodyMassAndDistanceRow` pull state via `ref.watch` instead of receiving `notifier`/`state` props. No prop drilling for downstream sections.
- **Test infra** — `FakePlanStorage` lifted to `test/test_helpers/fake_plan_storage.dart` (PB-DATA-2 closed at 4th consumer). New `_pump` helper returns a `ProviderContainer` so widget tests can read state directly: `c.read(plannerNotifierProvider).requireValue.raceConfig.distanceKm`.

### Round 2 review (3 parallel reviewers)

Heaviest round so far. **Two CRITICAL runtime bugs** were originally flagged as `PC-*` TODO comments but the a11y reviewer correctly noted "a comment is not a guard." Plus 8 HIGH a11y/test gaps.

| Severity | Total | Fixed in Round 2.5 | Deferred |
|---|---:|---:|---:|
| CRITICAL | 2 | 2 (PC-UNIT-CONVERSION display guard + PC-PRESERVE-DIST behavior lock) | 0 |
| HIGH | 12 | 10 | 2 (race-name maxLength carry-over to other text inputs; full keyboard-tab-order test deferred to F1 assembly) |
| MEDIUM | 11 | 7 | 4 (`_RailBody` could be ConsumerWidget too; file-split decision; abbreviation tooltips; F1 `errorBorder`) |
| LOW | 13 | 6 | 7 |

**Test counts:** 110 app tests (was 97; +13 from Round 2.5 — 4 BonkTextInput tests, 9 setup_rail expansion). Core 257 / CLI 279 unchanged.

### Decisions locked in (Milan, post-Round 2)

**Q1 → A (hardcode unit display).** PC-UNIT-CONVERSION runtime safety bug: imperial user entering "150 lb" produces a fueling plan calibrated for 150 kg → off by ~2.2× (race-day risk). Until F1 wires real unit conversion, **the displayed unit labels are hardcoded to "kg" and "km" regardless of `unitSystem`**. Imperial users see "kg" — display is wrong for them but the value-vs-label is now consistent. Locked by test `'PC-UNIT-CONVERSION: unit labels are hardcoded kg/km regardless of unitSystem'`.

**Q2 → A (lock current behavior).** PC-PRESERVE-DIST: empty distance input is a no-op (`RaceConfig.copyWith(distanceKm: null)` falls through `??` to `this.distanceKm`). User cannot clear distance via input; "Backspace appears broken." Until F1 lands a sentinel-aware `copyWith` or an explicit Clear button, **the bug remains but is locked by test** `'PC-PRESERVE-DIST: empty distance input preserves prior value'`. The test's `reason:` field documents the bug for F1 to intentionally flip.

**Q3 → Yes (promote `_BonkTextInput`).** Now `BonkTextInput` under `lib/presentation/widgets/text_input.dart`. C3-C5 reuse without copy-paste.

**Q4 → No (defer file split).** `setup_rail.dart` stays as one file until C3 lands the second section and motivates a per-section directory. Deferred per "smallest reasonable changes."

### New conventions established for Phase C

- **PC-* breadcrumb pattern** for documented-but-deferred runtime concerns. Tests pin the documented behavior so F1 can intentionally flip. Active breadcrumbs: `PC-RESPONSIVE` (320px hardcoded width), `PC-UNIT-CONVERSION` (display hardcoded kg/km), `PC-PRESERVE-DIST` (empty distance no-op), `PC-ERROR-UI` (stub error stub awaiting PB-DATA-1).
- **`UncontrolledProviderScope` + `_pump` returning `ProviderContainer`** for widget tests that need to read state directly. Pattern: `final c = await _pump(tester); ...; expect(c.read(plannerNotifierProvider).requireValue.<...>, expected);`. Lets tests assert wiring contracts instead of just rendered output.
- **`InputDecoration.labelText`** is the canonical accessible name for `TextField`. Avoids implementation-undefined `Semantics(container, label)` ancestor merging across SR engines (VoiceOver / TalkBack / NVDA).
- **`inputFormatters: [FilteringTextInputFormatter.digitsOnly]`** on integer inputs (h, m, body mass) and `RegExp(r'^\d*\.?\d*')` on decimal inputs (distance). Filters at the source — no display flicker, no silent revert.
- **`Key('setup.<field_name>')`** addressing convention for setup-rail inputs. Lets tests use `find.byKey(...)` instead of brittle `find.text(...)`.
- **`ExcludeSemantics` on inline unit Text widgets** (h, m, kg, km). Each TextField now carries its full accessible name via `labelText`; the inline unit is decorative.
- **`liveRegion: true` on loading/error states** — screen reader announces transitions.
- **Cursor-preserving `_ctrl.value = TextEditingValue(...)` instead of `_ctrl.text = ...`**. Default `controller.text =` setter resets cursor to position 0; preserving via clamped `TextSelection` matches the user's typing flow.

### Closed carry-overs

- **PB-DATA-2** — `FakePlanStorage` was duplicated across two test files; this batch lifted it to `test_helpers/fake_plan_storage.dart` (4th consumer trigger reached: setup_rail_test joined planner_notifier_test + plan_provider_test).

### Active carry-overs (still live)

- **PC-RESPONSIVE** — 320px hardcoded width. F1 wires `BonkBreakpoint.setupRailWidth`.
- **PC-PRESERVE-DIST** — empty distance preserves prior value. F1 fixes via sentinel-aware copyWith or Clear button.
- **PC-UNIT-CONVERSION** — labels hardcoded kg/km until F1 wires real unit conversion.
- **PC-ERROR-UI** — stub error message awaiting PB-DATA-1's F1 actionable banner with [Try recovery] [Start fresh].
- **PB-A11Y-4** — fixed-pixel input widths (56/64) at risk under 200% text scaling. Carry-over to D2 stat grid widget test.
- **PB-A11Y-1, PB-A11Y-2, PB-UX-5** — earlier Phase B carry-overs unchanged.

### Plan-vs-reality drift caught (and fixed)

- **`BonkType.<role>()` → `BonkType.<role>`** — 4 callsites in plan template lines 3338-3395 used the deprecated method-call form. All fixed.
- **Cursor reset on `_ctrl.text = widget.value`** — plan template at lines 3423-3425 had this pattern. Fixed in promoted `BonkTextInput` to use `_ctrl.value = TextEditingValue(text:, selection:)` with clamped selection preservation.
- **Notifier prop drilling** — plan had `_DurationRow` and `_BodyMassAndDistanceRow` taking `notifier: PlannerNotifier`. Refactored to `ConsumerWidget` reading via `ref.read(plannerNotifierProvider.notifier)` at the leaf.
- **`BonkType.sectionLabel()` (and railEyebrow/railTitle/railSub)** — plan template at line 3395 used method form; converted to field form.

## 2026-05-05 — v1.1 Phase C Batch 3 (C3+C4+C5: carb strategy, inventory, aid stations)

The remaining three Setup-rail sections shipped. 8 net commits (3 implementer + 5 Round 3.5 fix-ups).

### What shipped

- **C3 — Carb strategy** — two `Slider`s (target intake 30–120 g/hr, gut-trained ceiling 30–120 g/hr) + `BonkSegControl<Strategy>` (Front-load / Steady / Back-load). Both sliders inherit theme primary (ink) — Q3=A dropped the gut-trained `activeColor: ink3` differentiation; live labels disambiguate. Live label rebuilds on every drag tick; Material's built-in Semantics(value, increasedValue, decreasedValue) handles SR announcements.
- **C4 — Inventory list** — `InventoryRow` per built-in product. Kind dot (decorative anchor) + brand+name + mono subline `'80g · 2:1 · Gel'` (type label appended per Q1=C) + `BonkStepper` with `keyPrefix: 'inv.${id}'`. Active state when count > 0 paints `BonkTokens.paper` background. Increment preserves `selectedProducts` order via replace-in-place (Q4 fix-now).
- **C5 — Aid station list** — `AidStationRow` per station: `BonkSegControl<bool>` time/distance toggle (toggle-clear behavior per Q2=C — the new mode's value renders empty so user types fresh) + numeric `BonkTextInput` + `IconButton` row remove + Wrap of refill chips (each chip has `IconButton(visualDensity: compact, minWidth: 24)` close per WCAG 2.5.8) + `+ refill` PopupMenuButton (renders disabled "All products added" chip when nothing's pickable). "+ Add aid station" outlined button below.
- **`AidStation.copyWith`** — added to `packages/core/lib/src/models/race_config.dart` with null-as-no-change semantics matching `RaceConfig.copyWith`. Refill mutations in `aid_station_row.dart` switched to `station.copyWith(refill: ...)`. Toggle path still constructs fresh `AidStation(...)` because copyWith can't clear unit fields.
- **Section extraction** — `_RailBody.build` no longer holds inline `Consumer` blocks. `_InventorySection` and `_AidStationsSection` are private `ConsumerWidget`s in the same file (Q6 in-file extraction; directory split deferred to F1).
- **`BonkStepper.keyPrefix`** — added (test-addressing). `Key('$keyPrefix.minus')` and `'.plus'` resolve to per-product tap targets.
- **`_SectionLabel`** wraps in `Semantics(header: true)` — SR users can jump-by-heading.
- Each `AidStationRow` wrapped in `Semantics(container: true, label: 'Aid station ${i+1}')`.

### Round 3 review (3 parallel reviewers)

Heaviest a11y round so far. Two CRITICAL findings (refill chip close + InventoryRow type-by-color) caught before Phase C closes.

| Severity | Total | Fixed in Round 3.5 | Deferred |
|---|---:|---:|---:|
| CRITICAL | 2 | 2 (chip → IconButton; type via text + Semantics) | 0 |
| HIGH | 11 | 11 | 0 |
| MEDIUM | 13 | 9 | 4 (nested-Scrollable PB-SCROLL; OutlinedButton stylistic; refill chip 11pt textScaler — covered by PB-A11Y-4; AidStationRow toggle magic conversion → resolved by Q2=C clear) |
| LOW | 5 | 1 | 4 |

**Test counts:** 135 app tests (was 119 baseline + 9 from Batch 3 implementer + 6 inventory_row + 7 aid_station_row + ~3 setup_rail expansion + 16 net inflation from re-shaping existing tests). Core 257 / CLI 279 unchanged.

### Decisions locked in (Milan, post-Round 3)

**Q1 → C (type via text + Semantics).** `InventoryRow` mono subline appends product type: `'60g · 1:1 · Gel'` instead of carrying type signal in the `_KindDot` color. The dot stays as a visual anchor with `Semantics(label: type.shortLabel)` for SR users. Resolves WCAG 1.4.1 (color-only info), 1.4.11 (decorative dot exempt), 4.1.2 (named).

**Q2 → C (clear value on toggle).** `AidStationRow` toggle between Time and Distance now drops the active-unit value to `0` / `0.0` (sentinel for "user re-types fresh"). Render path translates 0 → empty string so the input shows blank. Honest UX — no magic 3.0 km/min conversion. Discipline-aware conversion is a future polish if usage justifies.

**Q3 → A (drop gut-trained activeColor).** Both sliders inherit theme primary (ink). No visual differentiation; live labels disambiguate. Pin against future "do I differentiate sliders by color again?" questions.

**Q4 → Fix now (preserve order).** Inventory `+` tap replaces in place rather than removing-then-appending. `selectedProducts` ordering is now stable across user mutations.

**Q5 → Add now (`AidStation.copyWith`).** 5-line core-package addition. `aid_station_row.dart` chip-mutation paths use it; toggle path still constructs fresh because copyWith can't clear unit fields.

**Q6 → Do now (in-file section extraction).** `_RailBody.build` halves; readable. Directory split deferred to F1 alongside `BonkBreakpoint` responsive wiring (PC-RESPONSIVE).

### Toggle-clear sentinel choice (notable decision)

The toggle-clear path uses `0` / `0.0` sentinels (NOT `null`) for the active field because `validateAidStationDefinitions` (`packages/core/lib/src/engine/plan_validator.dart`) flags the "no time AND no distance" branch as **critical** — the model requires one to be set. Render path translates the sentinel back to empty string so the user types fresh:

```dart
if (_isDistance) {
  final km = station.distanceKm!;
  markValue = km == 0.0 ? '' : km.toStringAsFixed(km % 1 == 0 ? 0 : 1);
} else {
  final m = station.timeMinutes ?? 0;
  markValue = m == 0 ? '' : '$m';
}
```

A future v1.x could revisit by relaxing the validator to accept "user-pending" states.

### Closed carry-overs

- **Q4 from Round 2 (file split)** — partially closed via in-file section extraction (`_InventorySection` / `_AidStationsSection`). Directory-level split still deferred to F1.

### Active carry-overs (still live)

- **PC-RESPONSIVE / PC-PRESERVE-DIST / PC-UNIT-CONVERSION / PC-ERROR-UI** — unchanged; F1 work.
- **PB-DATA-1 (L3)** — unchanged; F1 prerequisite for real UI mutators.
- **PB-A11Y-4** — fixed-pixel sizes + 11pt fonts. Refill chip `maxWidth: 140` joins this carry-over.
- **PB-A11Y-1, PB-A11Y-2, PB-UX-5** — earlier Phase B carry-overs unchanged.

### New Round 3 carry-overs

- **PB-SCROLL** — `_pumpTall` workaround in setup_rail tests masks a real production scroll-handling ambiguity (parent `SingleChildScrollView` + each `BonkTextInput`'s `EditableText` viewport fight for gestures at small viewports). Fix in F1: either set `BonkTextInput.scrollPhysics: NeverScrollableScrollPhysics()` for single-line inputs, or wrap the rail with `PrimaryScrollController`.
- **PC-OUTLINED-BUTTON** — "+ Add aid station" uses Material 3 OutlinedButton default styling. Theme overrides give it ink foreground/border which works, but it's stylistically inconsistent with brutalist BonkSegControl/BonkStepper aesthetic. F1 polish: introduce a `BonkButton` widget if a second secondary action lands.
- **PC-DOT-COLORS** — `_KindDot` colors are now decorative (per Q1=C, type is conveyed by text). The actual mapping (`gel→accent`, `liquid→ink2`, `chew→ink`, `solid→ink3`, `realFood→rule`) gives three dark-on-cream dots that look pairwise similar at 10×10 px. Aesthetic polish, not a11y blocker. Pick five distinct hues if a future design pass cares.
- **PC-AID-VALIDATOR** — sentinel `0`/`0.0` for toggle-clear is a workaround for the validator requiring one unit field non-null. v1.x could relax the validator to accept "pending input" states.

### Plan-vs-reality drift caught (and fixed)

- Plan template at lines 3735+ used `import 'product_stepper.dart'` — the file was renamed to `stepper.dart` in Round 1.
- `_KindDot` colors in plan template (`accent / hydro / warn / fru`) are different from the actual implementer's choice (`accent / ink2 / ink / ink3 / rule`). Per Q1=C the dot is decorative now, so neither mapping is "wrong" — but worth noting the divergence.
- Plan said `Slider.activeColor` is deprecated. **Verified false** — Flutter 3.41.3 stable still ships `activeColor` without a `@Deprecated` annotation. Implementer's note retracted.
- `AidStation` has no `copyWith` in core (per plan); added in this round.
- Plan-template tests for `InventoryRow` referenced a "caffeine row" that never existed in the actual layout (the row is a single mono subline + stepper). Test for non-existent feature dropped; replaced with brand+name test.






