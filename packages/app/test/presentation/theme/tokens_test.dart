// ABOUTME: Verifies design tokens match the prototype's CSS values.
// ABOUTME: Locked numbers prevent accidental drift from the source design.
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';

void main() {
  test('paper background matches design CSS #f5f3ee', () {
    expect(BonkTokens.bg.toARGB32(), 0xFFF5F3EE);
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
}
