// ABOUTME: Widget tests for the SetupRail — race section input wiring.
// ABOUTME: Asserts user input flows through PlannerNotifier.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_fueling_app/presentation/panels/setup_rail.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';

import '../../test_helpers/fake_plan_storage.dart';
import '../../test_helpers/google_fonts_setup.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
      child: const MaterialApp(home: Scaffold(body: SetupRail())),
    ),
  );
  // Resolve the AsyncNotifier load.
  await tester.pump();
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
}
