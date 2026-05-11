// ABOUTME: Widget tests for the SetupRail — race section input wiring.
// ABOUTME: Asserts user input flows through PlannerNotifier including
// ABOUTME: metric/imperial unit conversion and sentinel-aware distance clear.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/domain.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:race_fueling_app/presentation/panels/setup_rail.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';

import '../../test_helpers/fake_plan_storage.dart';
import '../../test_helpers/google_fonts_setup.dart';

/// Drains the 500 ms debounce window so the test's pending save Timer fires
/// before tear-down. Tests that mutate state without this drain trip
/// flutter_test's "Timer still pending" verifier.
Future<void> _drainSaveDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
}

/// Pumps the SetupRail wired to a [FakePlanStorage] and returns the underlying
/// [ProviderContainer] so tests can read planner state directly. Caller may
/// supply a configured [storage] (e.g. with `loadGate` / `loadError`) to
/// exercise async branches.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakePlanStorage? storage,
  bool waitForLoad = true,
}) async {
  final fake = storage ?? FakePlanStorage();
  final container = ProviderContainer(
    overrides: [planStorageProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  if (waitForLoad) {
    // Resolve the AsyncNotifier seed so requireValue is safe in widget tree.
    await container.read(plannerNotifierProvider.future);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SetupRail())),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders the race name field with seed value', (tester) async {
    await _pump(tester);
    expect(find.text('Andalucía Bike Race — Stage 3'), findsOneWidget);
  });

  testWidgets('typing in race name updates state', (tester) async {
    await _pump(tester);
    final field = find.byKey(const Key('setup.race_name'));
    await tester.tap(field);
    await tester.enterText(field, 'New Race Name');
    await tester.pump();
    expect(find.text('New Race Name'), findsOneWidget);
    // Drain the F2 save debounce timer before the test body returns.
    await _drainSaveDebounce(tester);
  });

  testWidgets('discipline segments include all 5 disciplines', (tester) async {
    await _pump(tester);
    expect(find.text('MTB XCM'), findsOneWidget);
    expect(find.text('Road'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('Tri'), findsOneWidget);
    expect(find.text('Ultra'), findsOneWidget);
  });

  testWidgets('shows loading indicator while storage is gated', (tester) async {
    final fake = FakePlanStorage()..loadGate = Completer<void>();
    await _pump(tester, storage: fake, waitForLoad: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading planner'), findsOneWidget);
    fake.loadGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('renders banner-signposted fallback when storage load throws', (
    tester,
  ) async {
    final fake = FakePlanStorage()..loadError = StateError('disk full');
    await _pump(tester, storage: fake, waitForLoad: false);
    // Allow the AsyncError to propagate.
    await tester.pump();
    // F1b: actionable recovery lives in BonkRecoveryBanner above the rail;
    // the rail signposts the banner so it isn't empty when only one panel
    // hits AsyncError.
    expect(find.textContaining('see recovery options'), findsOneWidget);
  });

  testWidgets('metric unitSystem renders kg/km labels', (tester) async {
    await _pump(tester);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
  });

  testWidgets('imperial unitSystem renders lb/mi labels', (tester) async {
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        athleteProfile: seed.athleteProfile.copyWith(
          unitSystem: UnitSystem.imperial,
        ),
      );
    await _pump(tester, storage: fake);
    expect(find.text('lb'), findsOneWidget);
    expect(find.text('mi'), findsOneWidget);
    expect(find.text('kg'), findsNothing);
    expect(find.text('km'), findsNothing);
  });

  testWidgets('imperial body mass input stores converted kg value', (
    tester,
  ) async {
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        athleteProfile: seed.athleteProfile.copyWith(
          unitSystem: UnitSystem.imperial,
        ),
      );
    final c = await _pump(tester, storage: fake);
    await tester.enterText(find.byKey(const Key('setup.body_mass')), '158.7');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.athleteProfile.bodyWeightKg,
      closeTo(72.0, 0.05),
    );
  });

  testWidgets('imperial distance input stores converted km value', (
    tester,
  ) async {
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        athleteProfile: seed.athleteProfile.copyWith(
          unitSystem: UnitSystem.imperial,
        ),
      );
    final c = await _pump(tester, storage: fake);
    await tester.enterText(find.byKey(const Key('setup.distance_km')), '62');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.distanceKm,
      closeTo(99.78, 0.05),
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets(
    'imperial body mass displays one-decimal precision (no rounding drift)',
    (tester) async {
      // F1d HIGH#1(a): 72 kg renders as 158.7 lb (kgToLb(72) ≈ 158.733...),
      // NOT "159". Imperial display must keep the typed decimal precision so
      // the controller doesn't overwrite mid-edit text.
      final seed = PlannerState.seed();
      final fake = FakePlanStorage()
        ..loaded = seed.copyWith(
          athleteProfile: seed.athleteProfile.copyWith(
            unitSystem: UnitSystem.imperial,
            bodyWeightKg: 72.0,
          ),
        );
      await _pump(tester, storage: fake);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('setup.body_mass')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '158.7');
    },
  );

  testWidgets(
    'imperial distance displays one-decimal precision (no rounding drift)',
    (tester) async {
      // F1d HIGH#1(a) mirror for distance: stored distanceKm: 100 → 62.1 mi.
      final seed = PlannerState.seed();
      final fake = FakePlanStorage()
        ..loaded = seed.copyWith(
          athleteProfile: seed.athleteProfile.copyWith(
            unitSystem: UnitSystem.imperial,
          ),
          raceConfig: seed.raceConfig.copyWith(distanceKm: 100.0),
        );
      await _pump(tester, storage: fake);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('setup.distance_km')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '62.1');
    },
  );

  testWidgets('imperial decimal distance "62.5" mi stores ≈ 100.59 km', (
    tester,
  ) async {
    // F1d LOW#13: mirrors the imperial-body-mass decimal test for symmetry.
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        athleteProfile: seed.athleteProfile.copyWith(
          unitSystem: UnitSystem.imperial,
        ),
      );
    final c = await _pump(tester, storage: fake);
    await tester.enterText(find.byKey(const Key('setup.distance_km')), '62.5');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.distanceKm,
      closeTo(100.59, 0.05),
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('imperial Semantics label for body mass includes "(lb)"', (
    tester,
  ) async {
    // F1d HIGH#2: AT users must hear the active unit, not just sighted ones.
    // The label appears twice (BonkFieldShell container + TextField decoration);
    // RegExp tolerates the merged Semantics announcement.
    final handle = tester.ensureSemantics();
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        athleteProfile: seed.athleteProfile.copyWith(
          unitSystem: UnitSystem.imperial,
        ),
      );
    await _pump(tester, storage: fake);
    expect(find.bySemanticsLabel(RegExp(r'Body mass \(lb\)')), findsWidgets);
    handle.dispose();
  });

  testWidgets('imperial Semantics label for distance includes "(mi)"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        athleteProfile: seed.athleteProfile.copyWith(
          unitSystem: UnitSystem.imperial,
        ),
      );
    await _pump(tester, storage: fake);
    expect(
      find.bySemanticsLabel(RegExp(r'Total distance \(mi\)')),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('metric Semantics label for body mass includes "(kg)"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel(RegExp(r'Body mass \(kg\)')), findsWidgets);
    handle.dispose();
  });

  testWidgets('metric Semantics label for distance includes "(km)"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(
      find.bySemanticsLabel(RegExp(r'Total distance \(km\)')),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('metric body mass accepts decimal input (72.5 kg)', (
    tester,
  ) async {
    // Regression guard: F1d swapped the body-mass formatter from digitsOnly
    // to the decimal-tolerant pattern so imperial lbs round-trip. Metric
    // users must keep being able to type '72.5'.
    final c = await _pump(tester);
    await tester.enterText(find.byKey(const Key('setup.body_mass')), '72.5');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.athleteProfile.bodyWeightKg,
      72.5,
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('valid distance km updates state', (tester) async {
    final c = await _pump(tester);
    await tester.enterText(find.byKey(const Key('setup.distance_km')), '120');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.distanceKm,
      120.0,
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('emptying the distance input clears the stored distance', (
    tester,
  ) async {
    // Sentinel-aware copyWith: passing distanceKm: null clears the field, so
    // an empty input frees the user from a previously-set value.
    final c = await _pump(tester);
    final originalDist = c
        .read(plannerNotifierProvider)
        .requireValue
        .raceConfig
        .distanceKm;
    expect(originalDist, isNotNull);
    await tester.enterText(find.byKey(const Key('setup.distance_km')), '');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.distanceKm,
      isNull,
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('valid body mass updates state in kg', (tester) async {
    final c = await _pump(tester);
    await tester.enterText(find.byKey(const Key('setup.body_mass')), '75');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.athleteProfile.bodyWeightKg,
      75.0,
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('zero body mass is rejected', (tester) async {
    final c = await _pump(tester);
    final original = c
        .read(plannerNotifierProvider)
        .requireValue
        .athleteProfile
        .bodyWeightKg;
    await tester.enterText(find.byKey(const Key('setup.body_mass')), '0');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.athleteProfile.bodyWeightKg,
      original,
      reason: 'guard `if (w > 0)` should suppress 0 from propagating',
    );
  });

  testWidgets('tapping Run discipline updates state', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.discipline,
      Discipline.run,
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('controller stays in sync when widget.value mutates externally', (
    tester,
  ) async {
    final c = await _pump(tester);
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(name: 'External Change'));
    await tester.pump();
    expect(find.text('External Change'), findsOneWidget);
    await _drainSaveDebounce(tester);
  });

  testWidgets('target slider initial label shows current value', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.textContaining('Target intake — 80 g/hr'), findsOneWidget);
  });

  testWidgets('distribution segmented control renders three options', (
    tester,
  ) async {
    await _pumpTall(tester);
    expect(find.text('Front-load'), findsOneWidget);
    expect(find.text('Steady'), findsOneWidget);
    expect(find.text('Back-load'), findsOneWidget);
  });

  testWidgets('target slider drag rightward increases the stored value', (
    tester,
  ) async {
    final c = await _pumpTall(tester);
    final targetSlider = find.byType(Slider).first;
    await tester.drag(targetSlider, const Offset(40, 0));
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.targetCarbsGPerHr,
      greaterThan(80.0),
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('gut-tolerance slider drag updates athleteProfile', (
    tester,
  ) async {
    final c = await _pumpTall(tester);
    final gutSlider = find.byType(Slider).at(1);
    await tester.drag(gutSlider, const Offset(40, 0));
    await tester.pump();
    expect(
      c
          .read(plannerNotifierProvider)
          .requireValue
          .athleteProfile
          .gutToleranceGPerHr,
      greaterThan(75.0),
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('tapping Front-load distribution updates strategy', (
    tester,
  ) async {
    final c = await _pumpTall(tester);
    await tester.tap(find.text('Front-load'));
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.strategy,
      Strategy.frontLoad,
    );
    await _drainSaveDebounce(tester);
  });

  testWidgets('inventory section lists products from library', (tester) async {
    await _pumpTall(tester);
    expect(find.textContaining('Maurten'), findsWidgets);
  });

  testWidgets('tapping + on a product increments inventory count', (
    tester,
  ) async {
    final c = await _pumpTall(tester);
    final plus = find.byKey(const Key('inv.maurten-160.plus'));
    expect(plus, findsOneWidget);
    await tester.tap(plus);
    await tester.pump();
    final updatedCount = c
        .read(plannerNotifierProvider)
        .requireValue
        .raceConfig
        .selectedProducts
        .firstWhere((s) => s.productId == 'maurten-160')
        .quantity;
    expect(updatedCount, 5);
    await _drainSaveDebounce(tester);
  });

  testWidgets('+ Add aid station appends a station at duration / 2', (
    tester,
  ) async {
    final c = await _pumpTall(tester);
    final originalCount = c
        .read(plannerNotifierProvider)
        .requireValue
        .raceConfig
        .aidStations
        .length;
    final addButton = find.text('+ Add aid station');
    await tester.ensureVisible(addButton);
    await tester.pump();
    await tester.tap(addButton);
    await tester.pump();
    final stations = c
        .read(plannerNotifierProvider)
        .requireValue
        .raceConfig
        .aidStations;
    expect(stations.length, originalCount + 1);
    // Seed duration is 4h30m = 270 min, so half is 135.
    expect(stations.last.timeMinutes, 135);
    await _drainSaveDebounce(tester);
  });

  testWidgets('empty aid stations list renders the carrying-everything copy', (
    tester,
  ) async {
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        raceConfig: seed.raceConfig.copyWith(aidStations: const []),
      );
    await _pumpTall(tester, storage: fake);
    expect(find.textContaining('carrying everything'), findsOneWidget);
  });

  testWidgets('lays out inside a 280px-wide parent without overflow', (
    tester,
  ) async {
    // F1 pins the contract that SetupRail is width-driven by its parent.
    // BonkBreakpoint.setupRailWidth returns 280 at medium/noDiagnostics/narrow.
    await tester.binding.setSurfaceSize(const Size(280, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = FakePlanStorage();
    final container = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(plannerNotifierProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 280, child: SetupRail())),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('default placement paints right-side rule', (tester) async {
    // The desktop three-pane layout uses the rule as the seam between
    // SetupRail and PlanCanvas. Pin the contract — turning the rule off by
    // default would re-introduce the F1c mobile-tab regression.
    await _pump(tester);
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SetupRail),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration?;
    expect(decoration?.border, isNotNull);
  });

  testWidgets(
    'showSideRule: false suppresses the right-side rule (mobile tabs)',
    (tester) async {
      // Mobile TabBarView places the rail as a tab child; the desktop seam
      // turns into a stray vertical line at the tab content's edge. The
      // mobile body opts out of the rule.
      final fake = FakePlanStorage();
      final container = ProviderContainer(
        overrides: [planStorageProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      await container.read(plannerNotifierProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SetupRail(showSideRule: false)),
          ),
        ),
      );
      await tester.pump();
      // Stable outer-container Key (LOW#11): the rule-painting Container
      // exposes Key('setup-rail.outer') so tests can find it without
      // relying on descendant order.
      final box = tester.widget<Container>(
        find.byKey(const Key('setup-rail.outer')),
      );
      final decoration = box.decoration as BoxDecoration?;
      expect(decoration?.border, isNull);
    },
  );
}

/// Pumps the rail under a 360x2400 surface so all sections (carb strategy,
/// inventory, aid stations) lay out without scrolling and tap targets resolve.
Future<ProviderContainer> _pumpTall(
  WidgetTester tester, {
  FakePlanStorage? storage,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  return _pump(tester, storage: storage);
}
