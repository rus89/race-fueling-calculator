// ABOUTME: Widget tests for RatioBar — split width, ideal marker, OK band,
// ABOUTME: composed Semantics label, and textScaler resilience.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/widgets/ratio_bar.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders ratio number with two decimals', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RatioBar(glucose: 50, fructose: 40)),
      ),
    );
    expect(find.text('1.25'), findsOneWidget);
    expect(find.textContaining('ideal 1.25'), findsOneWidget);
    expect(find.textContaining('OK 0.9–1.5'), findsOneWidget);
  });

  testWidgets('renders dash when fructose is zero', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RatioBar(glucose: 50, fructose: 0)),
      ),
    );
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('composes Semantics label with ratio + grams', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RatioBar(glucose: 50, fructose: 40)),
      ),
    );
    final data = tester.getSemantics(find.byType(RatioBar)).getSemanticsData();
    expect(data.label, contains('1.25'));
    expect(data.label, contains('Glucose 50'));
    expect(data.label, contains('Fructose 40'));
    handle.dispose();
  });

  testWidgets('survives 200% textScaler', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: RatioBar(glucose: 50, fructose: 40),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
