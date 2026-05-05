// ABOUTME: Widget tests for BonkStepper — increment/decrement, disabled
// ABOUTME: boundaries, disabled visual, hit-area expansion, and Semantics.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';
import 'package:race_fueling_app/presentation/widgets/stepper.dart';

import '../../test_helpers/google_fonts_setup.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('tap minus when value > min decrements', (tester) async {
    int? captured;
    await tester.pumpWidget(
      _wrap(BonkStepper(value: 5, onChanged: (v) => captured = v)),
    );
    await tester.tap(find.text('−'));
    expect(captured, 4);
  });

  testWidgets('tap plus when value < max increments', (tester) async {
    int? captured;
    await tester.pumpWidget(
      _wrap(BonkStepper(value: 5, onChanged: (v) => captured = v)),
    );
    await tester.tap(find.text('+'));
    expect(captured, 6);
  });

  testWidgets('tap minus at value == min is a no-op (disabled visual)', (
    tester,
  ) async {
    int? captured;
    await tester.pumpWidget(
      _wrap(BonkStepper(value: 0, onChanged: (v) => captured = v)),
    );
    await tester.tap(find.text('−'));
    expect(captured, isNull);

    final minusContainer = tester.widget<Container>(
      find.ancestor(of: find.text('−'), matching: find.byType(Container)).first,
    );
    expect(
      (minusContainer.decoration as BoxDecoration).color,
      BonkTokens.bg2,
      reason: 'disabled minus must drop to softer cream background',
    );
  });

  testWidgets('tap plus at value == max is a no-op (disabled visual)', (
    tester,
  ) async {
    int? captured;
    await tester.pumpWidget(
      _wrap(BonkStepper(value: 30, onChanged: (v) => captured = v)),
    );
    await tester.tap(find.text('+'));
    expect(captured, isNull);

    final plusContainer = tester.widget<Container>(
      find.ancestor(of: find.text('+'), matching: find.byType(Container)).first,
    );
    expect(
      (plusContainer.decoration as BoxDecoration).color,
      BonkTokens.bg2,
      reason: 'disabled plus must drop to softer cream background',
    );
  });

  testWidgets('respects custom min and max', (tester) async {
    int? captured;
    await tester.pumpWidget(
      _wrap(
        BonkStepper(value: 5, min: 5, max: 10, onChanged: (v) => captured = v),
      ),
    );
    await tester.tap(find.text('−'));
    expect(captured, isNull, reason: 'minus disabled at custom min');
    await tester.tap(find.text('+'));
    expect(captured, 6, reason: 'plus enabled below custom max');
  });

  testWidgets('displays current value with monospaced styling', (tester) async {
    await tester.pumpWidget(_wrap(BonkStepper(value: 7, onChanged: (_) {})));
    expect(find.text('7'), findsOneWidget);
    final valueText = tester.widget<Text>(find.text('7'));
    expect(valueText.style?.fontFamily, contains('JetBrainsMono'));
  });

  testWidgets('exposes adjustable Semantics with value/increased/decreased', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(BonkStepper(value: 5, onChanged: (_) {})));

    final node = tester.getSemantics(find.byType(BonkStepper));
    final data = node.getSemanticsData();
    expect(data.value, '5');
    expect(data.increasedValue, '6');
    expect(data.decreasedValue, '4');
    handle.dispose();
  });

  testWidgets('semanticLabel prefixes the announced value', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        BonkStepper(
          value: 3,
          semanticLabel: 'Maurten Gel 100 quantity',
          onChanged: (_) {},
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(BonkStepper));
    final data = node.getSemanticsData();
    expect(data.label, 'Maurten Gel 100 quantity, 3');
    handle.dispose();
  });
}
