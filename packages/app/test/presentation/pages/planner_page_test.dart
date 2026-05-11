// ABOUTME: Smoke test — PlannerPage renders all three panels at wide width.
// ABOUTME: Also pins that the endDrawer stays wired when the inline diagnostics rail drops.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/pages/planner_page.dart';
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
    },
  );
}
