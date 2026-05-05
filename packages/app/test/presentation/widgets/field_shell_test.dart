// ABOUTME: Widget tests for BonkFieldShell — label render, child render,
// ABOUTME: column ordering, label style identity, and Semantics association.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';
import 'package:race_fueling_app/presentation/widgets/field_shell.dart';

import '../../test_helpers/google_fonts_setup.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders label text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BonkFieldShell(label: 'Body weight', child: SizedBox.shrink()),
      ),
    );
    expect(find.text('Body weight'), findsOneWidget);
  });

  testWidgets('renders child widget', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BonkFieldShell(
          label: 'Race name',
          child: SizedBox(key: ValueKey('child'), width: 10, height: 10),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
  });

  testWidgets('label uses BonkType.fieldLabel style (locks static-final ref)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const BonkFieldShell(label: 'Distance', child: SizedBox.shrink())),
    );
    final labelText = tester.widget<Text>(find.text('Distance'));
    // BonkType.fieldLabel is sans 11.5pt in ink2. Locking these catches a
    // regression to method-call form or to a different role helper.
    expect(labelText.style?.fontSize, 11.5);
    expect(labelText.style?.color, BonkTokens.ink2);
  });

  testWidgets('places label above child', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BonkFieldShell(
          label: 'Top',
          child: SizedBox(key: ValueKey('below'), width: 10, height: 10),
        ),
      ),
    );
    final labelTop = tester.getTopLeft(find.text('Top'));
    final childTop = tester.getTopLeft(find.byKey(const ValueKey('below')));
    expect(labelTop.dy, lessThan(childTop.dy));
  });

  testWidgets(
    'Semantics container carries the label so screen readers associate it with the input',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const BonkFieldShell(
            label: 'Gut tolerance',
            child: SizedBox(width: 10, height: 10),
          ),
        ),
      );
      // The Semantics wrapper exposes 'Gut tolerance' as the field's
      // accessible name; the inner Text's announcement is excluded so
      // screen readers don't read it twice.
      expect(find.bySemanticsLabel('Gut tolerance'), findsOneWidget);
      handle.dispose();
    },
  );
}
