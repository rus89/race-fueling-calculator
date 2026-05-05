// ABOUTME: Root widget — MaterialApp configuration, theme, and home page.
// ABOUTME: Single page in v1.1 (PlannerPage); routing comes when there's >1 page.
import 'package:flutter/material.dart';

import 'presentation/pages/planner_page.dart';
import 'presentation/theme/tokens.dart';
import 'presentation/theme/typography.dart';

class BonkApp extends StatelessWidget {
  const BonkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: BonkTokens.accent,
      brightness: Brightness.light,
      surface: BonkTokens.bg,
    );
    return MaterialApp(
      title: 'Bonk · Race Fueling Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: BonkTokens.bg,
        colorScheme: scheme,
        // PB-A11Y-3: ColorScheme.fromSeed(accent) makes accent the primary,
        // which would push Material's default focus indicator to a 1.25:1
        // contrast yellow-green on bg — invisible to keyboard/voice-control
        // users. Override focusColor to ink so focus rings stay visible.
        focusColor: BonkTokens.ink,
        textTheme: TextTheme(
          bodyMedium: BonkType.sans(),
          bodySmall: BonkType.sans(size: 12),
          titleLarge: BonkType.sans(size: 22, w: FontWeight.w600),
        ),
      ),
      home: const PlannerPage(),
    );
  }
}
