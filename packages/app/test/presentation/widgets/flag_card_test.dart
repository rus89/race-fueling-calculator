// ABOUTME: Widget tests for FlagCard — title/body parsing, ink severity label,
// ABOUTME: composed Semantics, and textScaler resilience.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';
import 'package:race_fueling_app/presentation/widgets/flag_card.dart';
import 'package:race_fueling_core/core.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders CRITICAL label in ink (color doctrine)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlagCard(
            warning: Warning(
              severity: Severity.critical,
              message:
                  'Aid station 2 — refill list references unknown product id',
            ),
          ),
        ),
      ),
    );
    final label = tester.widget<Text>(find.text('CRITICAL'));
    expect(label.style?.color, BonkTokens.ink);
    expect(find.text('Aid station 2'), findsOneWidget);
    expect(find.textContaining('refill list'), findsOneWidget);
  });

  testWidgets('renders ADVISORY label in ink', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlagCard(
            warning: Warning(
              severity: Severity.advisory,
              message: 'Caffeine total trends toward ceiling',
            ),
          ),
        ),
      ),
    );
    final label = tester.widget<Text>(find.text('ADVISORY'));
    expect(label.style?.color, BonkTokens.ink);
  });

  testWidgets('whole message renders as title when no em-dash separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlagCard(
            warning: Warning(
              severity: Severity.advisory,
              message: 'Caffeine total trends toward ceiling',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Caffeine total trends toward ceiling'), findsOneWidget);
  });

  testWidgets('composes Semantics label with severity + message', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlagCard(
            warning: Warning(
              severity: Severity.critical,
              message:
                  'Aid station 2 — refill list references unknown product id',
            ),
          ),
        ),
      ),
    );
    final data = tester.getSemantics(find.byType(FlagCard)).getSemanticsData();
    expect(data.label, contains('Critical'));
    expect(data.label, contains('Aid station 2'));
    expect(data.label, contains('refill list'));
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
              child: FlagCard(
                warning: Warning(
                  severity: Severity.critical,
                  message:
                      'Aid station 2 — refill list references unknown product id',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // E1/E2 defensive — empty message string
  testWidgets('renders empty message without crash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlagCard(
            warning: Warning(severity: Severity.advisory, message: ''),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('ADVISORY'), findsOneWidget);
  });

  // Defensive — multiple em-dashes split only on the first occurrence
  testWidgets('splits on the FIRST em-dash, preserves rest in body', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlagCard(
            warning: Warning(
              severity: Severity.critical,
              message: 'Title — body part one — body part two',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('body part one — body part two'), findsOneWidget);
  });

  // Defensive — side rule color matches severity (color carries severity)
  testWidgets(
    'side rule color matches severity (bad for critical, warn for advisory)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FlagCard(
                  key: Key('flag.critical'),
                  warning: Warning(severity: Severity.critical, message: 'x'),
                ),
                FlagCard(
                  key: Key('flag.advisory'),
                  warning: Warning(severity: Severity.advisory, message: 'y'),
                ),
              ],
            ),
          ),
        ),
      );
      final criticalContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('flag.critical')),
              matching: find.byType(Container),
            )
            .first,
      );
      final advisoryContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('flag.advisory')),
              matching: find.byType(Container),
            )
            .first,
      );
      final criticalBorder =
          (criticalContainer.decoration as BoxDecoration).border as Border;
      final advisoryBorder =
          (advisoryContainer.decoration as BoxDecoration).border as Border;
      expect(criticalBorder.left.color, BonkTokens.bad);
      expect(advisoryBorder.left.color, BonkTokens.warn);
      expect(criticalBorder.left.width, 3);
      expect(advisoryBorder.left.width, 3);
    },
  );

  testWidgets(
    'body text uses ink2 color (severity carried via side rule, not text)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlagCard(
              warning: Warning(
                severity: Severity.critical,
                message:
                    'Aid station 2 — refill list references unknown product id',
              ),
            ),
          ),
        ),
      );
      final body = tester.widget<Text>(
        find.text('refill list references unknown product id'),
      );
      expect(body.style?.color, BonkTokens.ink2);
    },
  );

  testWidgets('Semantics label uses Advisory word for advisory severity', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlagCard(
            warning: Warning(
              severity: Severity.advisory,
              message: 'Caffeine total trends toward ceiling',
            ),
          ),
        ),
      ),
    );
    final data = tester.getSemantics(find.byType(FlagCard)).getSemanticsData();
    expect(data.label, contains('Advisory'));
    expect(data.label, contains('Caffeine total'));
    handle.dispose();
  });
}
