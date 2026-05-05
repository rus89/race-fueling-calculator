// ABOUTME: Tests for BonkTextInput — cursor preservation, label, formatters.
// ABOUTME: Locks the contract C3-C5 forms rely on as the input is reused.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/widgets/text_input.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('preserves cursor position when external value changes', (
    tester,
  ) async {
    String value = 'hello';
    StateSetter? setter;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, s) {
              setter = s;
              return BonkTextInput(value: value, onChanged: (v) {});
            },
          ),
        ),
      ),
    );
    // Place cursor between 'hel' and 'lo'.
    final controller = (tester.widget<TextField>(
      find.byType(TextField),
    )).controller!;
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();

    // Simulate external state change extending the value.
    setter!(() => value = 'hello world');
    await tester.pump();

    // Cursor should still be at offset 3 (extension keeps prior selection).
    expect(controller.selection.baseOffset, 3);
  });

  testWidgets('inputFormatters reject non-digit characters when digitsOnly', (
    tester,
  ) async {
    String captured = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkTextInput(
            value: '',
            onChanged: (v) => captured = v,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'a1b2c3');
    await tester.pump();
    expect(captured, '123');
  });

  testWidgets('maxLength caps the input length', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkTextInput(value: '', onChanged: (_) {}, maxLength: 5),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'abcdefghij');
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 5);
  });

  testWidgets('labelText surfaces as accessible name on the TextField', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkTextInput(
            value: 'something',
            onChanged: (_) {},
            labelText: 'Race name',
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Race name'), findsWidgets);
    handle.dispose();
  });
}
