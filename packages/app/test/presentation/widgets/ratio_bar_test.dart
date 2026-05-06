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

  testWidgets('ideal marker positioned at 55.56% of bar width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: RatioBar(glucose: 50, fructose: 40),
          ),
        ),
      ),
    );
    final markerRect = tester.getRect(
      find.byKey(const Key('ratio.idealMarker')),
    );
    // _shareForRatio(1.25) = 1.25 / 2.25 ≈ 0.5556
    // Marker positioned at: w * 0.5556 - 1 (centered 2px-wide line)
    expect(markerRect.left, closeTo(360 * 0.5556 - 1, 1.0));
  });

  testWidgets('OK band spans 0.4737 to 0.6 of bar width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: RatioBar(glucose: 50, fructose: 40),
          ),
        ),
      ),
    );
    final bandRect = tester.getRect(find.byKey(const Key('ratio.okBand')));
    // _shareForRatio(0.9) = 0.9/1.9 ≈ 0.4737
    // _shareForRatio(1.5) = 1.5/2.5 = 0.6
    expect(bandRect.left, closeTo(360 * 0.4737, 1.0));
    expect(bandRect.width, closeTo(360 * (0.6 - 0.4737), 1.0));
  });

  testWidgets('renders neutral bar when both glucose and fructose are zero', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RatioBar(glucose: 0, fructose: 0)),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    // Neutral path: no marker / no OK band rendered
    expect(find.byKey(const Key('ratio.idealMarker')), findsNothing);
    expect(find.byKey(const Key('ratio.okBand')), findsNothing);
    final data = tester.getSemantics(find.byType(RatioBar)).getSemanticsData();
    expect(data.label, contains('not available'));
    expect(data.label, contains('no glucose'));
    expect(data.label, contains('no fructose'));
    handle.dispose();
  });
}
