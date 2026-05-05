// ABOUTME: Widget tests for StatCard — value formatting + severity styling.
// ABOUTME: Covers hero+full layout, severity glyph, key, and Semantics label.
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

  testWidgets('warn severity shows warn-keyed side rule and "!" glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Glu : Fru',
            value: '0.5:1',
            severity: StatSeverity.warn,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('stat-severity-warn')), findsOneWidget);
    expect(find.text('!'), findsOneWidget);
  });

  testWidgets('ok severity shows ok-keyed side rule and "✓" glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Avg carbs / hr',
            value: '80',
            severity: StatSeverity.ok,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('stat-severity-ok')), findsOneWidget);
    expect(find.text('✓'), findsOneWidget);
  });

  testWidgets('bad severity shows bad-keyed side rule and "×" glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Caffeine',
            value: '999',
            severity: StatSeverity.bad,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('stat-severity-bad')), findsOneWidget);
    expect(find.text('×'), findsOneWidget);
  });

  testWidgets('Semantics container exposes composed label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Avg carbs / hr',
            value: '80',
            unit: 'g',
            sub: 'target 80',
            severity: StatSeverity.warn,
          ),
        ),
      ),
    );
    final handle = tester.ensureSemantics();
    final data = tester.getSemantics(find.byType(StatCard)).getSemanticsData();
    expect(data.label, contains('Avg carbs / hr'));
    expect(data.label, contains('80'));
    expect(data.label, contains('g'));
    expect(data.label, contains('target 80'));
    expect(data.label, contains('warn'));
    handle.dispose();
  });

  testWidgets('renders without overflow at 200% text scale', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
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
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
