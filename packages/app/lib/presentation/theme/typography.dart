// ABOUTME: Typography helpers — Inter Tight (UI) and JetBrains Mono (numbers).
// ABOUTME: Loaded via google_fonts; mono uses tabular figures for stable digits.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

// Sizes are unscaled inputs. Rely on Flutter's automatic propagation of
// MediaQuery.textScaler. Do NOT pass `textScaler: TextScaler.noScaling`
// to Text widgets — that breaks system-level large-text accessibility.
class BonkType {
  BonkType._();

  static TextStyle sans({double size = 14, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.interTight(
        fontSize: size,
        fontWeight: w,
        height: 1.45,
        color: BonkTokens.ink,
      );

  static TextStyle mono({double size = 12, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: w,
        height: 1.4,
        letterSpacing: -0.1,
        color: BonkTokens.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // Named text roles
  static TextStyle railEyebrow() =>
      mono(size: 11).copyWith(color: BonkTokens.ink3, letterSpacing: 0.4);
  static TextStyle railTitle() =>
      sans(size: 22, w: FontWeight.w600).copyWith(letterSpacing: -0.4);
  static TextStyle railSub() =>
      sans(size: 12.5).copyWith(color: BonkTokens.ink3);
  static TextStyle sectionLabel() =>
      mono(size: 10.5).copyWith(color: BonkTokens.ink3, letterSpacing: 0.6);
  static TextStyle fieldLabel() =>
      sans(size: 11.5).copyWith(color: BonkTokens.ink2);
  static TextStyle statHero() =>
      mono(size: 36, w: FontWeight.w600).copyWith(color: BonkTokens.accentInk);
  static TextStyle statValue() => mono(size: 20, w: FontWeight.w500);
}
