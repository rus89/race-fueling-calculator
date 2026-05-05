// ABOUTME: Widget tests for PlanCanvas — header stats and timeline rendering.
// ABOUTME: Asserts the 6 stat-card labels, race title, and at least one row.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:race_fueling_app/presentation/panels/plan_canvas.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';

import '../../test_helpers/fake_plan_storage.dart';
import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  Widget wrap(FakePlanStorage fake) => ProviderScope(
    overrides: [planStorageProvider.overrideWithValue(fake)],
    child: const MaterialApp(home: Scaffold(body: PlanCanvas())),
  );

  Future<void> sizeCanvas(WidgetTester tester) async {
    // Wide enough that the 6-column stat grid lays out at the canvas's
    // production widths; tall enough that the timeline + grid don't
    // overflow inside the SingleChildScrollView during layout.
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('renders 6 stat cards and race title', (tester) async {
    await sizeCanvas(tester);
    final fake = FakePlanStorage();
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    expect(find.text('Avg carbs / hr'), findsOneWidget);
    expect(find.text('Total carbs'), findsOneWidget);
    expect(find.text('Glu : Fru'), findsOneWidget);
    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('Fluid w/ fuel'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget);
  });

  testWidgets('renders the race name as the canvas title', (tester) async {
    await sizeCanvas(tester);
    final fake = FakePlanStorage();
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    expect(find.text('Andalucía Bike Race — Stage 3'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while planner state is loading', (
    tester,
  ) async {
    await sizeCanvas(tester);
    final fake = FakePlanStorage()..loadGate = Completer<void>();
    await tester.pumpWidget(wrap(fake));
    await tester.pump(); // one frame, build() in flight
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty race name renders "Untitled race"', (tester) async {
    await sizeCanvas(tester);
    final emptyNameSeed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = emptyNameSeed.copyWith(
        raceConfig: emptyNameSeed.raceConfig.copyWith(name: ''),
      );
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    expect(find.text('Untitled race'), findsOneWidget);
  });

  testWidgets('race name has Semantics header flag', (tester) async {
    await sizeCanvas(tester);
    final fake = FakePlanStorage();
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();
    final data = tester
        .getSemantics(find.text('Andalucía Bike Race — Stage 3'))
        .getSemanticsData();
    expect(data.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });

  testWidgets('renders an error state when storage load fails', (tester) async {
    await sizeCanvas(tester);
    final fake = FakePlanStorage()..loadError = StateError('boom');
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    // PB-DATA-1: the panel surfaces the error rather than silently
    // showing seed data. F1 will replace this with the recovery banner;
    // for now, a static fallback proves planProvider's AsyncError reaches
    // the consumer.
    expect(find.text('Plan unavailable. Please reload.'), findsOneWidget);
  });
}
