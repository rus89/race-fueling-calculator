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
