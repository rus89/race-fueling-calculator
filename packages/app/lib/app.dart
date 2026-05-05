// ABOUTME: Root widget — MaterialApp configuration, theme, and home page.
// ABOUTME: Single page in v1.1 (PlannerPage); routing comes when there's >1 page.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'presentation/pages/planner_page.dart';
import 'presentation/theme/tokens.dart';

class BonkApp extends StatelessWidget {
  const BonkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BonkTokens.accent,
          brightness: Brightness.light,
          surface: BonkTokens.bg,
        ).copyWith(
          // Override the seed-derived primary so M3 widgets (FilledButton, Slider,
          // Tab indicator, FAB, TextField focused border, etc.) paint with ink
          // instead of a derived dark olive. Accent stays available via
          // BonkTokens.accent for decorative fills (chips, dots, brand moments).
          primary: BonkTokens.ink,
          onPrimary: BonkTokens.bg,
          // Bonk doctrine: outlined-widget borders use ink3 (warm dark grey);
          // dividers and faint rules use rule (warm cream-grey).
          outline: BonkTokens.ink3,
          outlineVariant: BonkTokens.rule,
          // Bonk semantic for error/destructive surfaces.
          error: BonkTokens.bad,
          // onError limited by brand: paper (4.10:1), bg (3.86:1), and pure white
          // (4.28:1) all fall short of WCAG AA 4.5:1 against bad (#CD5340).
          // White is the highest-contrast option available without changing the
          // brand `bad` token, and it clears AA for large text (3:1) which is
          // what error labels typically are. If full-AA contrast is needed,
          // BonkTokens.bad should be darkened — out of scope for the theme pass.
          onError: const Color(0xFFFFFFFF),
        );
    final baseTextTheme = ThemeData.light().textTheme;
    return MaterialApp(
      title: 'Bonk · Race Fueling Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: BonkTokens.bg,
        colorScheme: scheme,
        // PB-A11Y-3: focusColor governs the focus overlay on the M2 widget
        // set (InkWell, Checkbox, Radio, Switch, ToggleButtons). M3 buttons
        // paint focus state from colorScheme.primary — addressed by the
        // copyWith above that pins primary to ink (instead of the seed-
        // derived dark olive that fails contrast on cream surfaces).
        focusColor: BonkTokens.ink,
        // Inter Tight across every Material text slot. Bonk-specific role
        // styles (BonkType.railTitle, statHero, etc.) keep using their own
        // tuned sizes/weights and override these defaults at the call site.
        textTheme: GoogleFonts.interTightTextTheme(
          baseTextTheme,
        ).apply(bodyColor: BonkTokens.ink, displayColor: BonkTokens.ink),
      ),
      home: const PlannerPage(),
    );
  }
}
