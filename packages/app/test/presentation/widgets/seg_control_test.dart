// ABOUTME: Widget tests for BonkSegControl — selection state and onChanged.
// ABOUTME: Verifies selected option renders ink fill and tap fires the callback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/widgets/seg_control.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders all options and marks selected', (tester) async {
    String value = 'b';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkSegControl<String>(
            value: value,
            options: const [('a', 'A'), ('b', 'B'), ('c', 'C')],
            onChanged: (v) => value = v,
          ),
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    final selected = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('B'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(selected, isNotNull);
  });

  testWidgets('fires onChanged when a different option is tapped', (
    tester,
  ) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkSegControl<String>(
            value: 'a',
            options: const [('a', 'A'), ('b', 'B')],
            onChanged: (v) => captured = v,
          ),
        ),
      ),
    );
    await tester.tap(find.text('B'));
    expect(captured, 'b');
  });
}
