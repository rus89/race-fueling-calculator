// ABOUTME: Widget tests for DiagnosticsRail — sections + empty/non-empty flags
// ABOUTME: + AsyncError fallback + loading branch.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_fueling_app/data/plan_storage.dart';
import 'package:race_fueling_app/presentation/panels/diagnostics_rail.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';

import '../../test_helpers/fake_plan_storage.dart';
import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders all three sections on AsyncData', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 320, child: DiagnosticsRail())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CARB SOURCES'), findsOneWidget);
    expect(find.textContaining('CAFFEINE'), findsOneWidget);
    expect(find.textContaining('FLAGS'), findsOneWidget);
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
