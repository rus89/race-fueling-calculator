// ABOUTME: Widget tests for the SetupRail — race section input wiring.
// ABOUTME: Asserts user input flows through PlannerNotifier and locks bug
// ABOUTME: contracts (PC-PRESERVE-DIST, PC-UNIT-CONVERSION) F1 will revisit.
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

  testWidgets('renders failure message when storage load throws', (
    tester,
  ) async {
    final fake = FakePlanStorage()..loadError = StateError('disk full');
    await _pump(tester, storage: fake, waitForLoad: false);
    // Allow the AsyncError to propagate.
    await tester.pump();
    expect(find.textContaining('Failed to load'), findsOneWidget);
  });

  testWidgets('PC-UNIT-CONVERSION: unit labels are hardcoded kg/km regardless '
      'of unitSystem', (tester) async {
    await _pump(tester);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
  });

  testWidgets('valid distance km updates state', (tester) async {
    final c = await _pump(tester);
    await tester.enterText(find.byKey(const Key('setup.distance_km')), '120');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.distanceKm,
      120.0,
    );
  });

  testWidgets('PC-PRESERVE-DIST: empty distance input preserves prior value', (
    tester,
  ) async {
    final c = await _pump(tester);
    final originalDist = c
        .read(plannerNotifierProvider)
        .requireValue
        .raceConfig
        .distanceKm;
    expect(originalDist, isNotNull);
    await tester.enterText(find.byKey(const Key('setup.distance_km')), '');
    await tester.pump();
    final after = c
        .read(plannerNotifierProvider)
        .requireValue
        .raceConfig
        .distanceKm;
    expect(
      after,
      originalDist,
      reason:
          'PC-PRESERVE-DIST: copyWith(distanceKm: null) is a no-op; '
          'F1 will fix via sentinel-aware copyWith or explicit Clear button.',
    );
  });

  testWidgets('valid body mass updates state in kg', (tester) async {
    final c = await _pump(tester);
    await tester.enterText(find.byKey(const Key('setup.body_mass')), '75');
    await tester.pump();
    expect(
      c.read(plannerNotifierProvider).requireValue.athleteProfile.bodyWeightKg,
      75.0,
    );
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
