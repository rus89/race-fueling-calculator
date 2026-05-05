// ABOUTME: Verifies design tokens match the prototype's CSS values.
// ABOUTME: Locked numbers prevent accidental drift from the source design.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';

void main() {
  test('bg surface matches design CSS #f5f3ee', () {
    expect(BonkTokens.bg.toARGB32(), 0xFFF5F3EE);
  });

  test('paper surface matches design CSS #fbfaf6', () {
    expect(BonkTokens.paper.toARGB32(), 0xFFFBFAF6);
  });

  test('ink matches design CSS #0e0e0c', () {
    expect(BonkTokens.ink.toARGB32(), 0xFF0E0E0C);
  });

  test('accent is committed as the source-resolved sRGB constant', () {
    // OKLCH(0.88 0.18 120) → sRGB hex pinned at design time.
    expect(BonkTokens.accent.toARGB32(), 0xFFC8E85B);
  });

  test('rule color matches design CSS #d8d5cb', () {
    expect(BonkTokens.rule.toARGB32(), 0xFFD8D5CB);
  });

  group('surface secondaries and rules', () {
    test('bg2 matches #ecebe4', () {
      expect(BonkTokens.bg2.toARGB32(), 0xFFECEBE4);
    });
    test('rule2 matches #e6e3d9', () {
      expect(BonkTokens.rule2.toARGB32(), 0xFFE6E3D9);
    });
  });

  group('semantic palette', () {
    // Locked against the design source. These hues are decorative fills
    // (chips, dots, left bars). Per the color-usage doctrine in tokens.dart,
    // none are used as text foreground.
    final expected = <String, ({int hex, Color token})>{
      'accentInk': (hex: 0xFF3F4D14, token: BonkTokens.accentInk),
      'warn': (hex: 0xFFC28A4A, token: BonkTokens.warn),
      'bad': (hex: 0xFFCD5340, token: BonkTokens.bad),
      'ok': (hex: 0xFF6FA169, token: BonkTokens.ok),
      'hydro': (hex: 0xFF7FA3C4, token: BonkTokens.hydro),
      'caf': (hex: 0xFF9D614A, token: BonkTokens.caf),
      'glu': (hex: 0xFFA8D24F, token: BonkTokens.glu),
      'fru': (hex: 0xFFD4A04A, token: BonkTokens.fru),
    };

    for (final entry in expected.entries) {
      test('${entry.key} matches design hex', () {
        expect(entry.value.token.toARGB32(), entry.value.hex);
      });
    }
  });
}
