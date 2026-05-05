// ABOUTME: Widget tests for BonkSegControl — selection, semantics, keyboard.
// ABOUTME: Locks selected fill, label color/weight, no-op re-tap, a11y roles.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';
import 'package:race_fueling_app/presentation/widgets/seg_control.dart';

import '../../test_helpers/google_fonts_setup.dart';

enum _Pick { a, b }

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders all options and marks selected with ink fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkSegControl<String>(
            value: 'b',
            options: const [('a', 'A'), ('b', 'B'), ('c', 'C')],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);

    final selectedBox = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('B'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (selectedBox.decoration as BoxDecoration).color,
      BonkTokens.ink,
      reason: 'selected option must paint ink fill',
    );

    final unselectedBox = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('A'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (unselectedBox.decoration as BoxDecoration).color,
      Colors.transparent,
      reason: 'unselected option must be transparent',
    );
  });

  testWidgets('selected label uses bg color and w500 weight', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkSegControl<String>(
            value: 'a',
            options: const [('a', 'A'), ('b', 'B')],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final selectedText = tester.widget<Text>(find.text('A'));
    expect(selectedText.style?.color, BonkTokens.bg);
    expect(selectedText.style?.fontWeight, FontWeight.w500);
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

  testWidgets('does NOT fire onChanged when current value is re-tapped', (
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
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(captured, isNull, reason: 're-tap of selected option must no-op');
  });

  testWidgets('exposes button + selected semantics for each option', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkSegControl<String>(
            value: 'b',
            options: const [('a', 'A'), ('b', 'B')],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final selectedFlags = tester
        .getSemantics(find.bySemanticsLabel('B'))
        .getSemanticsData()
        .flagsCollection;
    expect(selectedFlags.isButton, isTrue);
    expect(selectedFlags.isSelected, Tristate.isTrue);
    expect(selectedFlags.isInMutuallyExclusiveGroup, isTrue);

    final unselectedFlags = tester
        .getSemantics(find.bySemanticsLabel('A'))
        .getSemanticsData()
        .flagsCollection;
    expect(unselectedFlags.isButton, isTrue);
    expect(unselectedFlags.isSelected, Tristate.isFalse);

    handle.dispose();
  });

  testWidgets('groupLabel wraps the control in a labelled container', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkSegControl<String>(
            value: 'a',
            options: const [('a', 'A'), ('b', 'B')],
            groupLabel: 'Discipline',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Discipline'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('first option is keyboard-focusable via Tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkSegControl<String>(
            value: 'a',
            options: const [('a', 'A'), ('b', 'B')],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focusNode = FocusManager.instance.primaryFocus;
    expect(focusNode?.hasFocus, isTrue);
    expect(focusNode?.context, isNotNull);
  });

  testWidgets('accepts a generic enum type parameter', (tester) async {
    _Pick? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonkSegControl<_Pick>(
            value: _Pick.a,
            options: const [(_Pick.a, 'A'), (_Pick.b, 'B')],
            onChanged: (v) => captured = v,
          ),
        ),
      ),
    );
    await tester.tap(find.text('B'));
    expect(captured, _Pick.b);
  });
}
