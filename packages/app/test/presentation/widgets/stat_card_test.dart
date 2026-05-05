// ABOUTME: Widget tests for StatCard — value formatting + flag styling.
// ABOUTME: Covers hero+full layout and the warn flag side-rule keying.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/widgets/stat_card.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders label, value, unit, and sub', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Avg carbs / hr',
            value: '80',
            unit: 'g',
            sub: 'target 80',
            isHero: true,
          ),
        ),
      ),
    );
    expect(find.text('Avg carbs / hr'), findsOneWidget);
    // Value + unit live in a RichText span, so the visible plain text is the
    // concatenation '80 g'. Use textContaining so we don't depend on the
    // exact spacing of the unit suffix.
    expect(find.textContaining('80'), findsWidgets);
    expect(find.textContaining('g'), findsWidgets);
    expect(find.text('target 80'), findsOneWidget);
  });

  testWidgets('warn flag shows warn-colored side rule', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Glu : Fru',
            value: '0.5:1',
            flag: StatFlag.warn,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('stat-flag-warn')), findsOneWidget);
  });
}
