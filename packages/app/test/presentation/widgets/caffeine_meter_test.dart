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
    expect(find.textContaining('2.9', findRichText: true), findsOneWidget);
    expect(find.textContaining('mg/kg', findRichText: true), findsOneWidget);
  });

  testWidgets('hot state at >=ceiling — segment + OVER text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 500, bodyKg: 70)),
      ),
    );
    expect(find.byKey(const Key('caf-seg-hot-4')), findsOneWidget);
    expect(find.textContaining(' · OVER', findRichText: true), findsOneWidget);
  });

  testWidgets('no OVER text when below ceiling', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 200, bodyKg: 70)),
      ),
    );
    expect(find.textContaining(' · OVER', findRichText: true), findsNothing);
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
    expect(find.textContaining('0.0', findRichText: true), findsOneWidget);
    expect(find.textContaining(' · OVER', findRichText: true), findsNothing);
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
    expect(find.textContaining('2.9', findRichText: true), findsOneWidget);
  });

  testWidgets('renders zero segments at sub-10% caffeine (plan note 8)', (
    tester,
  ) async {
    // 20mg / 70kg = 0.286 mg/kg → 20/420*5 = 0.238 → round = 0 segments
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 20, bodyKg: 70)),
      ),
    );
    expect(find.byKey(const Key('caf-seg-hot-4')), findsNothing);
    expect(find.textContaining(' · OVER', findRichText: true), findsNothing);
    expect(find.textContaining('0.3', findRichText: true), findsOneWidget);
  });

  testWidgets('does NOT fire hot at 5.4 mg/kg (90% of ceiling, post-F1)', (
    tester,
  ) async {
    // 378mg / 70kg = 5.4 mg/kg = 0.9 × ceiling
    // BEFORE F1: round(4.5) = 5 → hot. AFTER F1: hot = false (mgPerKg < 6.0).
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 378, bodyKg: 70)),
      ),
    );
    expect(find.byKey(const Key('caf-seg-hot-4')), findsNothing);
    expect(find.textContaining(' · OVER', findRichText: true), findsNothing);
    expect(find.textContaining('5.4', findRichText: true), findsOneWidget);
  });

  testWidgets('fires hot at exact ceiling (6.0 mg/kg)', (tester) async {
    // 420mg / 70kg = 6.0 mg/kg = ceiling exactly
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaffeineMeter(totalMg: 420, bodyKg: 70)),
      ),
    );
    expect(find.byKey(const Key('caf-seg-hot-4')), findsOneWidget);
    expect(find.textContaining(' · OVER', findRichText: true), findsOneWidget);
    expect(find.textContaining('6.0', findRichText: true), findsOneWidget);
  });
}
