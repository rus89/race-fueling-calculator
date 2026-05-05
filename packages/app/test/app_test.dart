// ABOUTME: Smoke test for BonkApp — verifies bootstrap renders the stub page.
// ABOUTME: Catches theme-construction crashes (focus color, color scheme, fonts).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/app.dart';
import 'package:race_fueling_app/presentation/pages/planner_page.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';

import 'test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('BonkApp renders the PlannerPage', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BonkApp()));
    await tester.pump();
    expect(find.byType(PlannerPage), findsOneWidget);
  });

  testWidgets('BonkApp theme pins Bonk doctrine values', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BonkApp()));
    await tester.pump();
    final ctx = tester.element(find.byType(Scaffold));
    final theme = Theme.of(ctx);

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, BonkTokens.bg);
    // PB-A11Y-3: focusColor for the M2 widget overlay path.
    expect(theme.focusColor.toARGB32(), BonkTokens.ink.toARGB32());
    // ColorScheme overrides — the copyWith chain that fixes M3 widgets.
    expect(theme.colorScheme.primary.toARGB32(), BonkTokens.ink.toARGB32());
    expect(theme.colorScheme.onPrimary.toARGB32(), BonkTokens.bg.toARGB32());
    expect(theme.colorScheme.outline.toARGB32(), BonkTokens.ink3.toARGB32());
    expect(
      theme.colorScheme.outlineVariant.toARGB32(),
      BonkTokens.rule.toARGB32(),
    );
    expect(theme.colorScheme.error.toARGB32(), BonkTokens.bad.toARGB32());
  });

  testWidgets('BonkApp textTheme uses Inter Tight across slots', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BonkApp()));
    await tester.pump();
    final ctx = tester.element(find.byType(Scaffold));
    final textTheme = Theme.of(ctx).textTheme;

    // GoogleFonts.interTightTextTheme tags every slot's fontFamily with the
    // 'InterTight' identifier. Locking this at bodyMedium and labelLarge
    // catches any regression that drops textTheme back to Roboto.
    expect(textTheme.bodyMedium, isNotNull);
    expect(textTheme.bodyMedium!.fontFamily, contains('InterTight'));
    expect(textTheme.labelLarge, isNotNull);
    expect(textTheme.labelLarge!.fontFamily, contains('InterTight'));
    // bodyColor cascade applied by .apply() — ink everywhere.
    expect(textTheme.bodyMedium!.color, BonkTokens.ink);
  });
}
