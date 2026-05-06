// ABOUTME: Widget tests for CaffeineMeter — segment fill, hot state with
// ABOUTME: redundant OVER text, composed Semantics, textScaler resilience.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/widgets/caffeine_meter.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders mg/kg readout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 200, bodyKg: 70)),
      ),
    );
    expect(find.textContaining('2.9'), findsOneWidget);
    expect(find.textContaining('mg/kg'), findsOneWidget);
  });

  testWidgets('hot state at >=ceiling — segment + OVER text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 500, bodyKg: 70)),
      ),
    );
    expect(find.byKey(const Key('caf-seg-hot-4')), findsOneWidget);
    expect(find.textContaining('OVER'), findsOneWidget);
  });

  testWidgets('no OVER text when below ceiling', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 200, bodyKg: 70)),
      ),
    );
    expect(find.textContaining('OVER'), findsNothing);
  });

  testWidgets('composes Semantics label with mg/kg + ceiling + state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 500, bodyKg: 70)),
      ),
    );
    final data = tester
        .getSemantics(find.byType(CaffeineMeter))
        .getSemanticsData();
    expect(data.label, contains('mg/kg'));
    expect(data.label, contains('ceiling 6'));
    expect(data.label, contains('over'));
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
              child: CaffeineMeter(totalMg: 500, bodyKg: 70),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // E1 lesson: cover the zero-input edge.
  testWidgets('renders zero-fill at 0 mg', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 0, bodyKg: 70)),
      ),
    );
    expect(find.textContaining('0.0'), findsOneWidget);
    expect(find.textContaining('OVER'), findsNothing);
    expect(find.byKey(const Key('caf-seg-hot-4')), findsNothing);
  });

  // E1 lesson: bodyKg <= 0 should fall back to 70 (per spec) — pin the contract.
  testWidgets('falls back to 70 kg body weight when bodyKg <= 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 200, bodyKg: 0)),
      ),
    );
    // 200 / 70 = 2.857..., rounds-to-1dp = 2.9 — matches the bodyKg=70 default
    expect(find.textContaining('2.9'), findsOneWidget);
  });
}
