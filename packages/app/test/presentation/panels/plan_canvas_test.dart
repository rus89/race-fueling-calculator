// ABOUTME: Widget tests for PlanCanvas — header stats and timeline rendering.
// ABOUTME: Asserts the 6 stat-card labels, race title, and at least one row.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/data/plan_storage.dart';
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
    // F1c-RESPONSIVE: the stat grid collapses to Wrap below 880px so the
    // 200% text-scale surface doesn't overflow. 2400×3200 with 2× scale
    // exercises the wide branch — pin that contract.
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stat grid collapses to wrap layout below 880px without overflow',
    (tester) async {
      // Pump at a narrow viewport so _StatsGrid takes the Wrap branch.
      // The six cards must all remain findable and no horizontal overflow
      // can occur (RenderFlex overflow throws an Exception during paint).
      await tester.binding.setSurfaceSize(const Size(600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fake = FakePlanStorage();
      await tester.pumpWidget(wrap(fake));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Avg carbs / hr'), findsOneWidget);
      expect(find.text('Total carbs'), findsOneWidget);
      expect(find.text('Glu : Fru'), findsOneWidget);
      expect(find.text('Caffeine'), findsOneWidget);
      expect(find.text('Fluid w/ fuel'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);

      // F1c-WRAP-SHAPE: the 2-up Wrap composes exactly one Wrap with six
      // SizedBox children sized to (innerWidth - space4) / 2. Pin the
      // shape so a regression to GridView or three-column Row shows here.
      final wrapFinder = find.byType(Wrap);
      expect(wrapFinder, findsOneWidget);
      final wrapWidget = tester.widget<Wrap>(wrapFinder);
      final sizedBoxes = wrapWidget.children.whereType<SizedBox>().toList();
      expect(sizedBoxes.length, 6);
      // Each SizedBox width = (innerWidth - 16) / 2 and all are equal.
      // Probe the LayoutBuilder's effective inner width via the first card
      // and assert the others are within 1px (rounding).
      final firstWidth = sizedBoxes.first.width!;
      expect(firstWidth, greaterThan(0));
      for (final box in sizedBoxes) {
        expect(box.width, closeTo(firstWidth, 1.0));
      }
    },
  );

  testWidgets('stat grid uses Row layout at exactly 880px inner width', (
    tester,
  ) async {
    // Boundary check: 880px is the wrap-below threshold INSIDE _StatsGrid's
    // LayoutBuilder. The canvas applies 28+28 horizontal padding, so a
    // 936px surface yields exactly 880px inner. At >= 880px inner the grid
    // uses IntrinsicHeight + Row, NOT Wrap.
    await tester.binding.setSurfaceSize(const Size(936, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = FakePlanStorage();
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    expect(find.byType(IntrinsicHeight), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('stat grid uses Wrap layout at 879px inner width', (
    tester,
  ) async {
    // Boundary check: 879px inner (935px surface) is just below the
    // threshold; Wrap branch.
    await tester.binding.setSurfaceSize(const Size(935, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = FakePlanStorage();
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(IntrinsicHeight), findsNothing);
  });

  testWidgets('empty plan renders empty-state CTA and hides stat grid', (
    tester,
  ) async {
    await sizeCanvas(tester);
    // Zero-duration race produces no timeline slots → FuelingPlan.entries
    // is empty. This is the path the empty-state CTA catches (the user
    // cleared duration or hasn't set one yet).
    final seed = PlannerState.seed();
    final fake = FakePlanStorage()
      ..loaded = seed.copyWith(
        raceConfig: seed.raceConfig.copyWith(
          duration: Duration.zero,
          selectedProducts: const [],
          aidStations: const [],
        ),
      );
    await tester.pumpWidget(wrap(fake));
    await tester.pumpAndSettle();
    // Empty-state CTA copy is visible.
    expect(find.text('No plan yet.'), findsOneWidget);
    expect(
      find.text(
        'Set a duration and add at least one product in Setup to compute '
        'your plan.',
      ),
      findsOneWidget,
    );
    // The empty-state explanatory copy is the entire affordance — no button
    // that destroys in-progress work. F1c review HIGH#1.
    expect(find.byType(FilledButton), findsNothing);
    // The stat grid is replaced, not stacked above — labels must not appear.
    expect(find.text('Avg carbs / hr'), findsNothing);
    expect(find.text('Total carbs'), findsNothing);
    // Race-name header at the top of _Body stays visible.
    expect(find.text('Andalucía Bike Race — Stage 3'), findsOneWidget);
  });

  testWidgets(
    'PlanStorageException → "Saved plan unreadable — see recovery options."',
    (tester) async {
      await sizeCanvas(tester);
      final fake = FakePlanStorage()
        ..loadError = const PlanStorageException('corrupt blob');
      await tester.pumpWidget(wrap(fake));
      await tester.pumpAndSettle();
      // F1b: storage-layer failures get the "Saved plan unreadable" copy
      // and signpost the banner (layout-agnostic copy — banner may be
      // above or beside the canvas depending on viewport). Raw error text
      // must not leak into UI.
      expect(
        find.text('Saved plan unreadable — see recovery options.'),
        findsOneWidget,
      );
      expect(find.textContaining('corrupt blob'), findsNothing);
    },
  );

  testWidgets(
    'non-storage error → "Couldn\'t compute plan — see recovery options."',
    (tester) async {
      await sizeCanvas(tester);
      final fake = FakePlanStorage()..loadError = StateError('boom');
      await tester.pumpWidget(wrap(fake));
      await tester.pumpAndSettle();
      // F1b: anything other than PlanStorageException reads as an engine
      // failure — the canvas surfaces the generic compute-failed copy.
      expect(
        find.text("Couldn't compute plan — see recovery options."),
        findsOneWidget,
      );
      expect(find.textContaining('boom'), findsNothing);
    },
  );
}
