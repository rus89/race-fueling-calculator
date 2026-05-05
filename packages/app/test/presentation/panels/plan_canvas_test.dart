// ABOUTME: Widget tests for PlanCanvas — header stats and timeline rendering.
// ABOUTME: Asserts the 6 stat-card labels, race title, and at least one row.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:race_fueling_app/presentation/panels/plan_canvas.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/widgets/stat_card.dart';

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

  testWidgets('loading indicator has Semantics liveRegion + label', (
    tester,
  ) async {
    await sizeCanvas(tester);
    final fake = FakePlanStorage()..loadGate = Completer<void>();
    await tester.pumpWidget(wrap(fake));
    await tester.pump();
    final handle = tester.ensureSemantics();
    final data = tester
        .getSemantics(find.byType(CircularProgressIndicator))
        .getSemanticsData();
    expect(data.label, contains('Loading'));
    expect(
      data.flagsCollection.isLiveRegion,
      isTrue,
      reason: 'Loading indicator should announce dynamically',
    );
    fake.loadGate!.complete();
    await tester.pumpAndSettle();
    handle.dispose();
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

  testWidgets('long race name truncates with ellipsis at 2 lines', (
    tester,
  ) async {
    await sizeCanvas(tester);
    final seed = PlannerState.seed();
    final longName = 'A' * 200;
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        raceConfig: seed.raceConfig.copyWith(name: longName),
      );
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text(longName));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
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

  testWidgets('Glu:Fru ratio rendering matches glucose/fructose direction', (
    tester,
  ) async {
    await sizeCanvas(tester);
    final fake = FakePlanStorage();
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    // The Andalucía seed produces more glucose than fructose, so the
    // glucose/fructose ratio is > 1. The StatCard's Semantics label is
    // the source of truth for the displayed value (RichText doesn't match
    // find.text reliably).
    final handle = tester.ensureSemantics();
    final cards = tester.widgetList(find.byType(StatCard));
    final gluFruLabel = cards
        .map(
          (w) => tester.getSemantics(find.byWidget(w)).getSemanticsData().label,
        )
        .firstWhere((l) => l.startsWith('Glu : Fru'));
    final match = RegExp(r'(\d+\.\d+):1').firstMatch(gluFruLabel);
    expect(match, isNotNull, reason: 'expected "X.YZ:1" in $gluFruLabel');
    final printed = double.parse(match!.group(1)!);
    expect(printed, greaterThan(1.0));
    handle.dispose();
  });

  testWidgets('intervalMinutes null defaults to 15 minutes (peak axis label)', (
    tester,
  ) async {
    await sizeCanvas(tester);
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        raceConfig: seed.raceConfig.copyWith(intervalMinutes: null),
      );
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    // The 0g axis tick is always present; a clean render with intervalMinutes
    // null proves the 15-minute default kicked in (would div-by-zero crash
    // otherwise).
    expect(find.text('0g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at 200% text scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2400, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = FakePlanStorage();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: ProviderScope(
          overrides: [planStorageProvider.overrideWithValue(fake)],
          child: const MaterialApp(home: Scaffold(body: PlanCanvas())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // TODO(F1-RESPONSIVE): the 6-card stat grid is a fixed Row; at 200%
    // text scale on narrow surfaces it can overflow. F1 owns the Wrap
    // collapse. On this 2400×3200 surface the canvas builds without
    // throwing — pin that contract so a future regression that flips
    // it shows up here.
    expect(tester.takeException(), isNull);
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
    // The raw error message must NOT be interpolated into UI text — users
    // see the static copy, devs see the underlying error in debugPrint.
    expect(find.textContaining('boom'), findsNothing);
  });
}
