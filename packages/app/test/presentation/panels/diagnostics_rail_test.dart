// ABOUTME: Widget tests for DiagnosticsRail — sections + empty/non-empty flags
// ABOUTME: + AsyncError fallback + loading branch.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_fueling_app/data/plan_storage.dart';
import 'package:race_fueling_app/presentation/panels/diagnostics_rail.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/warnings_provider.dart';
import 'package:race_fueling_app/presentation/widgets/flag_card.dart';
import 'package:race_fueling_core/core.dart';

import '../../test_helpers/fake_plan_storage.dart';
import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets(
    'renders eyebrow + title + three section labels + AllClearCard on AsyncData',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            planStorageProvider.overrideWithValue(FakePlanStorage()),
            warningsProvider.overrideWith((ref) => const []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 360, child: DiagnosticsRail()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Eyebrow + title
      expect(find.text('03 / DIAGNOSTICS'), findsOneWidget);
      expect(find.text('Checks'), findsOneWidget);
      // Section labels
      expect(find.text('CARB SOURCES'), findsOneWidget);
      expect(find.textContaining('CAFFEINE — '), findsOneWidget);
      expect(find.textContaining(' MG'), findsOneWidget);
      expect(find.text('FLAGS (0)'), findsOneWidget);
      // Empty-state All-Clear card
      expect(
        find.text('All checks pass. Plan looks executable.'),
        findsOneWidget,
      );
      expect(find.text('✓'), findsOneWidget);
    },
  );

  testWidgets('renders FlagCards when warnings are present', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planStorageProvider.overrideWithValue(FakePlanStorage()),
          warningsProvider.overrideWith(
            (ref) => const [
              Warning(severity: Severity.advisory, message: 'Test advisory'),
              Warning(severity: Severity.critical, message: 'Test critical'),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 360, child: DiagnosticsRail())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FLAGS (2)'), findsOneWidget);
    expect(find.byType(FlagCard), findsNWidgets(2));
    // _AllClearCard NOT rendered
    expect(find.text('All checks pass. Plan looks executable.'), findsNothing);
  });

  testWidgets('shows loading indicator while planner is loading', (
    tester,
  ) async {
    final fake = FakePlanStorage()..loadGate = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 320, child: DiagnosticsRail())),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.loadGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows _ErrorFallback on AsyncError', (tester) async {
    final fake = FakePlanStorage()
      ..loadError = const PlanStorageException('corrupt blob');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 320, child: DiagnosticsRail())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Diagnostics unavailable'), findsOneWidget);
  });

  // E1+E2 defensive — textScaler 200% on bounded surface.
  // Surface width is panel-min (320px) plus the panel's 20+20 horizontal
  // padding so RatioBar (the narrowest leaf) renders at >= 320px, the bound
  // it independently survives at 200% scaler.
  testWidgets('survives 200% textScaler at 360px width', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SizedBox(width: 360, child: DiagnosticsRail()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
