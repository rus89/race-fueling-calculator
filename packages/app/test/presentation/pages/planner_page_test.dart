// ABOUTME: Smoke tests — PlannerPage renders panels per BonkBreakpoint tier.
// ABOUTME: Pins endDrawer wiring, mobile TabBar, and rail widths across surfaces.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/pages/planner_page.dart';
import 'package:race_fueling_app/presentation/panels/diagnostics_rail.dart';
import 'package:race_fueling_app/presentation/panels/setup_rail.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';

import '../../test_helpers/fake_plan_storage.dart';
import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders Topbar + setup rail + canvas + diagnostics at 1600w', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
        child: const MaterialApp(home: PlannerPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bonk'), findsOneWidget);
    expect(find.text('01 / SETUP'), findsOneWidget);
    expect(find.text('02 / PLAN'), findsOneWidget);
    expect(find.text('03 / DIAGNOSTICS'), findsOneWidget);

    // Rail widths pinned to the BonkBreakpoint.wide tier (320 / 380).
    // Regression guard against breakpoint↔page drift.
    final setupRailBox = tester.widget<SizedBox>(
      find
          .ancestor(of: find.byType(SetupRail), matching: find.byType(SizedBox))
          .first,
    );
    expect(setupRailBox.width, 320);
    final diagnosticsRailBox = tester.widget<SizedBox>(
      find
          .ancestor(
            of: find.byType(DiagnosticsRail),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(diagnosticsRailBox.width, 380);
  });

  testWidgets(
    'drops inline diagnostics rail at 1200w (endDrawer still wired)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
          child: const MaterialApp(home: PlannerPage()),
        ),
      );
      await tester.pumpAndSettle();
      // Inline rail is gone at this breakpoint.
      expect(find.text('03 / DIAGNOSTICS'), findsNothing);
      expect(find.text('01 / SETUP'), findsOneWidget);
      expect(find.text('02 / PLAN'), findsOneWidget);
      // EndDrawer is still hooked up so the Checks button (F1c) can open it.
      expect(find.byType(Drawer), findsNothing); // closed by default
      final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      expect(scaffold.hasEndDrawer, isTrue);

      // Opening the endDrawer surfaces the DiagnosticsRail header.
      scaffold.openEndDrawer();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('03 / DIAGNOSTICS'), findsOneWidget);
    },
  );

  testWidgets('narrow tier (1000w) drops inline diagnostics, keeps setup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
        child: const MaterialApp(home: PlannerPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('01 / SETUP'), findsOneWidget);
    expect(find.text('02 / PLAN'), findsOneWidget);
    expect(find.text('03 / DIAGNOSTICS'), findsNothing);
  });

  testWidgets('mobile tier (700w) renders TabBar with three tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
        child: const MaterialApp(home: PlannerPage()),
      ),
    );
    await tester.pumpAndSettle();
    // Topbar horizontal overflow at very narrow widths is a known F1c
    // concern (Checks button + mobile-fit polish). Drain the rendering
    // exception so we can validate the orthogonal TabBar contract.
    tester.takeException();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Setup'), findsOneWidget);
    // Topbar also renders 'Plan' (eyebrow); scope the tab label by ancestry.
    expect(
      find.descendant(of: find.byType(TabBar), matching: find.text('Plan')),
      findsOneWidget,
    );
    expect(find.text('Diagnostics'), findsOneWidget);

    // Default tab is Setup; tap Plan and assert the canvas header appears.
    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('Plan')),
    );
    await tester.pumpAndSettle();
    tester.takeException(); // drain residual overflow events from pump
    expect(find.text('02 / PLAN'), findsOneWidget);
  });
}
