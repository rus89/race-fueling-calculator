// ABOUTME: Smoke test for BonkApp — verifies bootstrap renders the stub page.
// ABOUTME: Catches theme-construction crashes (focus color, color scheme, fonts).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/app.dart';

import 'test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('BonkApp renders the stub PlannerPage', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BonkApp()));
    await tester.pump();
    expect(find.text('Bonk planner — coming online…'), findsOneWidget);
  });

  testWidgets('BonkApp focusColor overrides default to BonkTokens.ink', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BonkApp()));
    await tester.pump();
    final BuildContext ctx = tester.element(find.byType(Scaffold));
    expect(Theme.of(ctx).focusColor.toARGB32(), 0xFF0E0E0C); // BonkTokens.ink
  });
}
