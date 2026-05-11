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

  testWidgets(
    'does NOT overwrite controller while focused (preserves typed decimals)',
    (tester) async {
      // F1d HIGH#1: when an upstream state echoes a rounded form of the user's
      // typed value (e.g. user types "158.7" lb → stored 71.989 kg → re-render
      // "159"), the in-focus controller must not be overwritten mid-edit.
      String value = '158.7';
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
      // User taps the field to start editing.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final controller = (tester.widget<TextField>(
        find.byType(TextField),
      )).controller!;
      expect(controller.text, '158.7');

      // Simulate upstream state change rounding the value while focused.
      setter!(() => value = '159');
      await tester.pump();

      // Controller text must remain '158.7' — the user is still typing.
      expect(controller.text, '158.7');
    },
  );

  testWidgets('resumes overwrite when field loses focus', (tester) async {
    // F1d HIGH#1 mirror: once focus leaves, the next external value change
    // should propagate to the controller as before.
    String value = '158.7';
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
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final controller = (tester.widget<TextField>(
      find.byType(TextField),
    )).controller!;
    // Confirm the focus guard locks the field while focused.
    setter!(() => value = '159');
    await tester.pump();
    expect(controller.text, '158.7');

    // Drop focus by tapping elsewhere.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    // External update now propagates.
    setter!(() => value = '200');
    await tester.pump();
    expect(controller.text, '200');
  });
}
