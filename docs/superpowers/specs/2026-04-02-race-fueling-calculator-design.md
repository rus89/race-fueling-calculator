# Race Fueling Calculator — Design Spec

## Context

Endurance athletes (mountain bikers, road cyclists, runners, triathletes) need to consume carbohydrates during races to maintain performance. Figuring out exactly what to eat, when, and how much is complex — you have to account for race duration, intensity, gut tolerance, carb source ratios, product logistics, environmental conditions, and aid station access. Most athletes either wing it (risking bonking or GI distress) or maintain messy one-off spreadsheets.

This tool produces a concrete, time-based fueling plan from structured inputs: what to consume at each interval, with cumulative tracking and smart warnings.

**Target user:** Initially the author — an XCM mountain bike racer progressing from 60g to 90g carbs/hour. Designed to serve the broader endurance sports community.

**V1 scope:** CLI tool with core plan generation and terminal output. Exports and Flutter app are designed for but deferred.

---

## Tech Stack & Project Structure

**Language:** Dart  
**Structure:** Monorepo with separate packages

```
race-fueling-calculator/
  packages/
    core/           # Pure Dart — domain models, plan engine, validation, storage interface
    cli/            # CLI interface — depends on core
  melos.yaml        # (or workspace pubspec) monorepo config
```

- `core` has zero dependencies on CLI or Flutter libraries
- `cli` depends on `core` and CLI-specific packages (`args`, terminal formatting)
- Future `app` package (Flutter) will depend only on `core`

---

## Core Domain Model

### Product

A nutrition product (gel, drink mix, bar, chew, real food).

| Field | Type | Required | Notes |
|---|---|---|---|
| id | String | yes | Unique identifier |
| name | String | yes | Display name |
| brand | String | no | Manufacturer |
| type | ProductType | yes | gel, liquid, solid, chew, real_food |
| carbsPerServing | double | yes | Total carbs in grams |
| glucoseGrams | double | no | Glucose/maltodextrin portion. Defaults to total carbs (conservative) |
| fructoseGrams | double | no | Fructose portion. Defaults to 0 |
| caffeineMg | double | no | Caffeine per serving. Defaults to 0 |
| waterRequiredMl | double | no | Water needed to consume (e.g., to wash down a gel) |
| servingDescription | String | no | e.g., "1 gel (40g)", "500ml bottle" |
| isBuiltIn | bool | yes | Whether this is a bundled default |

### AthleteProfile

| Field | Type | Required | Notes |
|---|---|---|---|
| gutToleranceGPerHr | double | yes | Trained carb absorption ceiling (g/hr) |
| unitSystem | UnitSystem | yes | metric or imperial |
| bodyWeightKg | double | no | For future hydration/caffeine-per-kg calculations |

### RaceConfig

| Field | Type | Required | Notes |
|---|---|---|---|
| name | String | yes | Race name |
| duration | Duration | yes | Expected race time |
| distanceKm | double | no | Race distance (required for distance-based plans) |
| timelineMode | TimelineMode | yes | time_based or distance_based |
| intervalMinutes | int | cond. | Interval for time-based mode (default: 20) |
| intervalKm | double | cond. | Interval for distance-based mode |
| targetCarbsGPerHr | double | yes | Hourly carb target |
| strategy | Strategy | yes | steady, front_load, back_load, or custom |
| customCurve | List<CurveSegment> | cond. | Required if strategy is custom. List of (duration, g/hr) segments |
| selectedProducts | List<ProductSelection> | yes | Products + quantities carried |
| aidStations | List<AidStation> | no | Locations where aid-station-only products are available |
| temperature | double | no | Celsius (converted from F if imperial) |
| humidity | double | no | Relative humidity % |
| altitudeM | double | no | Meters (converted from ft if imperial) |

**ProductSelection:** product ID + quantity carried + whether it's aid-station-only.

**AidStation:** location (time mark or distance mark) + available products.

**CurveSegment:** duration + target g/hr for that segment.

### FuelingPlan (output)

| Field | Type | Notes |
|---|---|---|
| raceConfig | RaceConfig | The config that generated this plan |
| entries | List<PlanEntry> | The timeline |
| summary | PlanSummary | Aggregate stats |
| warnings | List<Warning> | All warnings collected |

### PlanEntry

| Field | Type | Notes |
|---|---|---|
| timeMark | Duration | Time from start |
| distanceMark | double? | Distance from start (if distance-based) |
| products | List<ProductServing> | What to consume (product + servings count) |
| carbsGlucose | double | Glucose/maltodextrin grams this entry |
| carbsFructose | double | Fructose grams this entry |
| carbsTotal | double | Total carbs this entry |
| cumulativeCarbs | double | Running total |
| cumulativeCaffeine | double | Running caffeine total (mg) |
| waterMl | double | Water needed for this entry |
| warnings | List<Warning> | Inline warnings for this entry |

### PlanSummary

Total carbs, average g/hr, total caffeine, overall glucose:fructose ratio, total water, environmental adjustments applied.

### Warning

| Field | Type | Notes |
|---|---|---|
| severity | Severity | critical or advisory |
| message | String | Human-readable warning |
| entryIndex | int? | Which entry it applies to (null = plan-level) |

---

## Plan Engine

The engine is a pure function: `generatePlan(RaceConfig, AthleteProfile, List<Product>) -> FuelingPlan`.

### Step 1: Build Timeline

Generate time slots from duration + interval. If distance-based, generate from distance + interval, mapping to estimated times using average pace (distance / duration). Aid station locations become fixed slots in the timeline.

### Step 2: Calculate Target Carbs Per Slot

- **Steady:** target g/hr evenly across all slots
- **Front-load:** decay curve — ~110% of target in the first third, ~100% in the middle, ~90% in the final third
- **Back-load:** inverse of front-load
- **Custom:** user-defined g/hr per segment, mapped onto timeline slots

### Step 3: Assign Products to Slots

Greedy allocation per slot:
1. For each slot, determine available products (all carried products, plus aid-station products if this slot is at an aid station)
2. Select products to hit the target carbs, preferring combinations that maintain glucose:fructose ratio near 1:0.8
3. Deduct from available quantities (don't over-allocate)
4. If a slot can't be fully filled, allocate what's available and flag a warning

### Step 4: Validate and Warn

After plan generation, a validation pass produces warnings:

**Critical:**
- Any hour exceeds trained gut tolerance by >15%
- Single-source carbs >60g/hr without dual-source products
- Cumulative caffeine >400mg (or >6mg/kg if body weight known)
- Running out of any product before race end

**Advisory:**
- Glucose:fructose ratio outside 1:0.6 to 1:1.0 range per hour
- Gap >30 minutes with no fuel intake
- High-heat hydration reminders (extra water suggestions)
- Significant carb drop in back half without back-load strategy

### Step 5: Environmental Adjustments

- **Heat stress** (temperature + humidity): increase water recommendations, add advisory notes about gel concentration, suggest favoring drink mix over gels at extreme levels
- **Altitude** (>1500m): apply modest upward modifier to carb target (~5-10%), noted in summary as "Target adjusted from Xg/hr to Yg/hr for altitude"
- Adjustment factors are configurable constants in the core package

---

## Product Library

### Two-tier system

1. **Built-in defaults:** ~20-30 popular products bundled as a JSON asset in `packages/core`. Read-only, versioned with the app.
2. **User products:** stored in `~/.race-fueling/products.json`. Users can add custom products or override built-in defaults. User entries take precedence when names match.

### CLI commands

- `fuel products list` — all products grouped by type
- `fuel products add` — interactive or via flags
- `fuel products edit <name>` — modify a user product
- `fuel products remove <name>` — remove user product (built-ins can be hidden, not deleted)
- `fuel products show <name>` — detailed nutrition view
- `fuel products reset` — restore built-in defaults

### Minimal data requirement

Only name, total carbs, and product type are required. Unknown glucose/fructose split defaults to all-glucose (conservative for ratio warnings).

---

## Athlete Profile

Stored at `~/.race-fueling/profile.json`. Created on first run via interactive wizard or via flags.

### CLI commands

- `fuel profile setup` — interactive first-time setup
- `fuel profile show` — display current profile
- `fuel profile set --tolerance 75 --units metric` — update fields

---

## Race Plan Workflow

### CLI commands

- `fuel plan create` — interactive or via flags, saves to `~/.race-fueling/plans/<name>.json`
- `fuel plan products add <product> --quantity 6` — add product to current plan
- `fuel plan products add <product> --quantity 2 --aid-station` — aid-station-only product
- `fuel plan products list` — show products in current plan
- `fuel plan generate` — run the engine, display the fueling timeline
- `fuel plan list` — list saved plans
- `fuel plan show <name>` — re-display a saved plan

### Interactive flow for new users

```
fuel profile setup    # one-time: gut tolerance, units, weight
fuel plan create      # race name, duration, distance, targets, strategy, conditions
fuel plan products add ...   # select products, set quantities
fuel plan generate    # view the plan
```

When flags are omitted, the CLI prompts for each value with sensible defaults (interval: 20 min, strategy: steady, no environmental adjustments).

---

## CLI Output Format

### Plan table

Formatted terminal table with columns: Time (or Distance), Product, Carbs (G+F), Cumulative, Caffeine, Water, Warnings.

Color coded: red for critical warnings, yellow for advisory.

### Summary block

Below the table: total carbs, average g/hr, total caffeine, glucose:fructose ratio, total water, environmental adjustments applied.

### Warnings section

All warnings collected at the bottom, grouped by severity.

---

## Data Storage

```
~/.race-fueling/
  profile.json
  products.json
  plans/
    cape-epic-stage-3.json
    local-xco-race.json
```

### Schema versioning

Every JSON file includes a `schemaVersion` field (starting at 1). Core package includes migration functions that upgrade older schemas on load. Migrations are one-way, applied automatically.

### StorageAdapter interface

Abstract class in core with methods: `loadProfile()`, `saveProfile()`, `loadProducts()`, `saveProducts()`, `loadPlan()`, `savePlan()`, `listPlans()`.

CLI implements `FileStorageAdapter` (local JSON files). Flutter will implement a different adapter without touching domain logic.

Pre-loaded products are bundled as an asset in core. The adapter merges built-in + user products at load time, user entries taking precedence.

---

## Deferred to v2+

- Export formats: plain text/markdown, CSV/JSON, PDF stem card
- Flutter web and mobile app
- Shareable plans (import/export between users)
- Training log integration (track what you actually consumed vs. planned)
- Sodium/electrolyte tracking
- Sweat rate modeling

---

## Verification Plan

1. Unit test the plan engine with known inputs → expected outputs
2. Unit test validation rules (trigger each warning type)
3. Unit test environmental adjustment calculations
4. Integration test the full CLI flow: profile setup → plan create → product add → generate
5. Manual smoke test: create a real race plan for an upcoming XCM race and verify the output makes sense
